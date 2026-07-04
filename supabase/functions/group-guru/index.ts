// group-guru — the AI tutor (Guru) replying inside a study room, on @Guru.
// Flow: verify the caller is a member of the room (with their JWT), load recent
// room messages, ask the LLM for a concise reply (Mandarin + short Indonesian
// gloss), then insert the reply as a Guru message using the SERVICE ROLE so it
// streams to every member via Realtime. The LLM key never leaves the server.
//
// Reuses OPENCODE_ZEN_* (DeepSeek via OpenCode Zen, OpenAI-compatible) — same
// engine as llm-proxy/translate. Reads ONLY `content` (the model is a reasoning
// model; reasoning_content is its scratch-pad, not the answer).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function endpoint(
  baseRaw: string,
  path: "/v1/chat/completions" | "/v1/messages",
): string {
  const trimmed = baseRaw.trim().replace(/\/+$/, "");
  if (trimmed.endsWith(path)) return trimmed;
  const root = trimmed.replace(/\/v1$/, "");
  return `${root}${path}`;
}

function textFromContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .map((part) => {
      if (typeof part === "string") return part;
      if (
        part && typeof part === "object"
      ) {
        const obj = part as {
          text?: unknown;
          content?: unknown;
          output_text?: unknown;
          message?: unknown;
        };
        return textFromContent(
          obj.text ?? obj.content ?? obj.output_text ?? obj.message,
        );
      }
      return "";
    })
    .join("")
    .trim();
}

function textFromOpenModelMessages(data: unknown): string {
  if (!data || typeof data !== "object") return "";
  const obj = data as {
    output_text?: unknown;
    output?: unknown;
    content?: unknown;
  };
  const outputText = typeof obj.output_text === "string"
    ? obj.output_text.trim()
    : "";
  if (outputText) return outputText;
  const output = textFromContent(obj.output);
  if (output) return output;
  return textFromContent(obj.content);
}

function buildSystem(track: string): string {
  const variant = track === "traditional"
    ? "TRADITIONAL_ONLY: pakai hanzi tradisional. Jangan tulis simplified kecuali user minta bandingkan."
    : "SIMPLIFIED_ONLY: pakai hanzi sederhana. Jangan tulis traditional kecuali user minta bandingkan.";
  return [
    "Kamu 'Guru', tutor Mandarin yang ramah di dalam ruang obrolan grup.",
    "Beberapa murid mengobrol; kamu hanya menjawab saat dipanggil.",
    `Ikuti track hanzi secara ketat: ${variant}`,
    "Jawab rapi dan singkat, maksimal 4 blok pendek. Gunakan label persis ini bila bloknya ada:",
    "Ringkas: jawaban inti.",
    "Contoh: hanzi (pinyin) = arti Indonesia.",
    "Catatan: koreksi/pola penting bila perlu.",
    "Latihan: satu pertanyaan kecil bila cocok.",
    "Sebut nama penanya bila jelas. Jangan pakai bullet acak, emoji, tabel, code fence, atau menulis ulang seluruh percakapan.",
  ].join(" ");
}

function appendBlock(existing: string | undefined, next: string): string {
  const cleaned = next.trim();
  if (!cleaned) return existing ?? "";
  return existing ? `${existing} ${cleaned}` : cleaned;
}

function looksLikeExample(line: string): boolean {
  return /[\u3400-\u9fff]/.test(line) &&
    (line.includes("=") || line.includes("artinya") ||
      /\([A-Za-z0-9üÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ ]+\)/.test(line));
}

function formatGuruReply(raw: string): string {
  const cleaned = raw
    .replace(/\r\n/g, "\n")
    .replace(/```[a-zA-Z]*/g, "")
    .replace(/```/g, "")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/__([^_]+)__/g, "$1")
    .replace(/^\s{0,3}#{1,6}\s*/gm, "")
    .replace(/^\s*[-*•]\s+/gm, "")
    .trim();
  if (!cleaned) return raw.trim();

  const labels = ["Ringkas:", "Contoh:", "Catatan:", "Latihan:"];
  const blocks = new Map<string, string>();
  const loose: string[] = [];
  const lines = cleaned
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("|"))
    .flatMap((line) =>
      line.split(/\s+(?=(Ringkas|Contoh|Catatan|Latihan)\s*:)/i)
        .map((part) => part.trim())
        .filter(Boolean)
    );

  for (let line of lines) {
    line = line.replace(/^\d+[.)]\s*/, "").trim();
    if (/^(jawaban|guru|respons?)$/i.test(line)) continue;
    let matched = false;
    for (const label of labels) {
      const re = new RegExp(`^${label.replace(":", "\\:")}\\s*`, "i");
      if (re.test(line)) {
        const body = line.replace(re, "").trim();
        if (body) blocks.set(label, appendBlock(blocks.get(label), body));
        matched = true;
        break;
      }
    }
    if (!matched && line) loose.push(line);
  }

  for (const line of loose.slice(0, blocks.size ? 3 : 6)) {
    const label = line.endsWith("?")
      ? "Latihan:"
      : looksLikeExample(line)
      ? "Contoh:"
      : blocks.has("Ringkas:")
      ? "Catatan:"
      : "Ringkas:";
    blocks.set(label, appendBlock(blocks.get(label), line));
  }

  const out = labels
    .filter((label) => blocks.get(label)?.trim())
    .map((label) => `${label} ${blocks.get(label)!.trim()}`)
    .slice(0, 4)
    .join("\n");
  return out || cleaned;
}

async function callLLM(
  endpoint: string,
  apiKey: string,
  model: string,
  messages: unknown,
  useMessagesProtocol: boolean,
  system: string,
): Promise<string | null> {
  try {
    const resp = await fetch(endpoint, {
      method: "POST",
      headers: useMessagesProtocol
        ? {
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
          "Content-Type": "application/json",
        }
        : {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
      body: useMessagesProtocol
        ? JSON.stringify({
          model,
          system,
          messages,
          temperature: 0.4,
          max_tokens: 2048,
          stream: false,
        })
        : JSON.stringify({
          model,
          messages: [
            { role: "system", content: system },
            ...(messages as unknown[]),
          ],
          temperature: 0.4,
          max_tokens: 2048,
          stream: false,
        }),
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    const reply = useMessagesProtocol
      ? textFromOpenModelMessages(data)
      : data?.choices?.[0]?.message?.content;
    return typeof reply === "string" && reply.trim() !== ""
      ? reply.trim()
      : null;
  } catch (_) {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const apiKey = Deno.env.get("OPENMODEL_API_KEY") ??
    Deno.env.get("OPENCODE_GO_API_KEY") ??
    Deno.env.get("OPENCODE_ZEN_API_KEY");
  const usingOpenModel = Boolean(Deno.env.get("OPENMODEL_API_KEY"));
  const baseRaw = Deno.env.get("OPENMODEL_BASE_URL") ??
    Deno.env.get("OPENCODE_GO_BASE_URL") ??
    Deno.env.get("OPENCODE_ZEN_BASE_URL") ??
    (usingOpenModel ? "https://api.openmodel.ai" : "https://api.deepseek.com");
  const model = Deno.env.get("OPENMODEL_MODEL") ??
    Deno.env.get("OPENCODE_GO_MODEL") ??
    Deno.env.get("OPENCODE_ZEN_MODEL") ??
    "deepseek-v4-flash";
  if (!supabaseUrl || !serviceKey || !anonKey) {
    return json({ error: "not_configured" }, 503);
  }
  if (!apiKey) return json({ error: "llm_not_configured" }, 503);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "no_auth" }, 401);

  let payload: { room_id?: string; track?: string };
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: "bad_json" }, 400);
  }
  const roomId = typeof payload.room_id === "string" ? payload.room_id : "";
  const track = payload.track === "traditional" ? "traditional" : "simplified";
  if (roomId === "") return json({ error: "no_room" }, 400);
  const system = buildSystem(track);

  // Caller-scoped client: verifies identity AND membership under RLS.
  const asUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData } = await asUser.auth.getUser();
  if (!userData?.user) return json({ error: "unauthorized" }, 401);
  const { data: isMember } = await asUser.rpc("is_room_member", {
    p_room: roomId,
  });
  if (isMember !== true) return json({ error: "not_member" }, 403);

  // Service-role client: read history + insert the Guru reply.
  const admin = createClient(supabaseUrl, serviceKey);
  const { data: rows } = await admin
    .from("room_messages")
    .select("author_name, is_guru, body")
    .eq("room_id", roomId)
    .order("created_at", { ascending: false })
    .limit(12);
  const history = ((rows ?? []) as Array<
    { author_name: string; is_guru: boolean; body: string }
  >).reverse();

  const convo = history
    .map((m) => `${m.is_guru ? "Guru" : m.author_name}: ${m.body}`)
    .join("\n");

  const useMessagesProtocol = usingOpenModel ||
    baseRaw.includes("openmodel.ai");
  const llmEndpoint = endpoint(
    baseRaw,
    useMessagesProtocol ? "/v1/messages" : "/v1/chat/completions",
  );

  // Try known models in order
  const models = [
    model,
    "deepseek-v4-flash",
    "deepseek-v4-flash-free",
    "deepseek-chat",
    "deepseek-v3",
  ];
  const seen = new Set<string>();
  const tryModels = models.filter((m) => !seen.has(m) && seen.add(m));

  let reply: string | null = null;
  for (const m of tryModels) {
    reply = await callLLM(
      llmEndpoint,
      apiKey,
      m,
      [
        {
          role: "user",
          content:
            `Percakapan ruang sejauh ini:\n${convo}\n\nSeseorang memanggil @Guru. ` +
            `Beri satu balasan singkat sebagai Guru.`,
        },
      ],
      useMessagesProtocol,
      system,
    );
    if (reply) break;
  }
  if (!reply) return json({ error: "llm_failed" }, 502);
  reply = formatGuruReply(reply);

  const { error: insErr } = await admin.from("room_messages").insert({
    room_id: roomId,
    sender_id: null,
    author_name: "Guru",
    author_handle: "",
    is_guru: true,
    body: reply,
  });
  if (insErr) {
    return json({ error: "insert_failed", detail: insErr.message }, 500);
  }

  return json({ ok: true });
});
