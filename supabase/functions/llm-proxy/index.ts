import "jsr:@supabase/functions-js/edge-runtime.d.ts";

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

function textFromOpenModelMessages(data: unknown): string {
  const content = (data as { content?: unknown })?.content;
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .map((part) => {
      if (typeof part === "string") return part;
      if (
        part && typeof part === "object" &&
        typeof (part as { text?: unknown }).text === "string"
      ) {
        return (part as { text: string }).text;
      }
      return "";
    })
    .join("")
    .trim();
}

function buildSystemPrompt(track: string, level: string): string {
  const variant = track === "traditional"
    ? "TRADITIONAL_ONLY: pakai hanzi tradisional. Jangan tulis simplified kecuali user minta bandingkan."
    : "SIMPLIFIED_ONLY: pakai hanzi sederhana. Jangan tulis traditional kecuali user minta bandingkan.";
  const sample = track === "traditional"
    ? "我想吃飯 (wo3 xiang3 chi1 fan4) = aku mau makan. 我覺得很好吃 (wo3 jue2de hen3 hao3chi1) = menurutku enak."
    : "我想吃饭 (wo3 xiang3 chi1 fan4) = aku mau makan. 我觉得很好吃 (wo3 jue2de hen3 hao3chi1) = menurutku enak.";
  return `Kamu adalah Guru, tutor bahasa Mandarin yang sabar, cerdas, dan humoris untuk penutur Bahasa Indonesia.

KEPRIBADIAN:
- Sabar dan mendukung — koreksi dengan lembut, jangan judge
- Natural dan kasual — ngobrol kayak temen (pakai "kamu/aku"), jangan kayak buku teks
- Antusias — semangat pas murid bener, support pas murid struggle
- Adaptif — ikutin level dan minat murid

ATURAN:
1. SELALU baca dan pahami pesan user. Jawab sesuai konteks, BUKAN template.
2. Ikuti track hanzi secara ketat: ${variant}
3. Format jawaban rapi, pendek, maksimal 4 blok. Gunakan label persis ini bila bloknya ada:
   Ringkas: jawaban inti dalam 1-2 kalimat.
   Contoh: hanzi (pinyin angka nada atau tanda nada) = arti Indonesia.
   Catatan: koreksi/pola penting bila perlu.
   Latihan: satu pertanyaan kecil untuk user.
4. Format kata baru: hanzi (pinyin) = "arti".
5. Beri 1-2 contoh kalimat natural, jangan daftar panjang.
6. JANGAN: markdown table, code fence, placeholder, "PR-mu kucatat ke rapor", emoji.

KONTEKS:
- Track: ${variant}
- Level: ${level}
- Kalau ada [Bank idiom] di pesan user, jelaskan dari data itu, jangan mengarang

Contoh respons bagus:
User: "apa bedanya xiang dan juede?"
Guru:
Ringkas: xiang = ingin/mau, juede = merasa/berpendapat.
Contoh: ${sample}
Catatan: Pakai xiang untuk keinginan, juede untuk opini/perasaan.
Latihan: Coba bikin 1 kalimat pakai juede.

Ingat: kamu guru bahasa sungguhan. Tugasmu mengajar, memotivasi, dan menemani murid belajar Mandarin.`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const apiKey = Deno.env.get("OPENMODEL_API_KEY") ??
    Deno.env.get("OPENCODE_GO_API_KEY") ??
    Deno.env.get("OPENCODE_ZEN_API_KEY");
  if (!apiKey) return json({ error: "OPENMODEL_API_KEY not set" }, 503);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "no_auth" }, 401);

  let payload: {
    messages?: unknown;
    track?: string;
    level?: string;
    model?: string;
  };
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: "bad_json" }, 400);
  }
  const messages = payload.messages;
  const track = payload.track === "traditional" ? "traditional" : "simplified";
  const level = typeof payload.level === "string"
    ? payload.level
    : "HSK 1-2 / TOCFL Band A";

  if (!Array.isArray(messages) || messages.length === 0) {
    return json({ error: "no_messages" }, 400);
  }

  const usingOpenModel = Boolean(Deno.env.get("OPENMODEL_API_KEY"));
  const baseRaw = Deno.env.get("OPENMODEL_BASE_URL") ??
    Deno.env.get("OPENCODE_GO_BASE_URL") ??
    Deno.env.get("OPENCODE_ZEN_BASE_URL") ??
    (usingOpenModel ? "https://api.openmodel.ai" : "https://api.deepseek.com");
  const chatEndpoint = endpoint(baseRaw, "/v1/chat/completions");
  const messagesEndpoint = endpoint(baseRaw, "/v1/messages");

  const llmMessages = [
    { role: "system", content: buildSystemPrompt(track, level) },
    ...(messages as Array<{ role: string; content: string }>),
  ];

  // Try models in order — the first that works wins.
  // Always try the known-good models first; env override is lowest priority.
  const envModel = Deno.env.get("OPENMODEL_MODEL") ??
    Deno.env.get("OPENCODE_GO_MODEL") ??
    Deno.env.get("OPENCODE_ZEN_MODEL");
  const modelList: string[] = [
    "deepseek-v4-flash",
    "deepseek-v4-flash-free",
    "deepseek-chat",
    "deepseek-v3",
  ];
  if (payload.model) modelList.unshift(payload.model);
  if (envModel && !modelList.includes(envModel)) modelList.push(envModel);

  // Dedupe while preserving order
  const seen = new Set<string>();
  const models = modelList.filter((m) => !seen.has(m) && seen.add(m));

  let lastError = "";
  for (const model of models) {
    try {
      const isMessages = usingOpenModel || baseRaw.includes("openmodel.ai") ||
        messagesEndpoint === chatEndpoint;
      const resp = await fetch(isMessages ? messagesEndpoint : chatEndpoint, {
        method: "POST",
        headers: isMessages
          ? {
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
          }
          : {
            "Authorization": `Bearer ${apiKey}`,
            "Content-Type": "application/json",
          },
        body: isMessages
          ? JSON.stringify({
            model,
            system: buildSystemPrompt(track, level),
            messages: messages as Array<{ role: string; content: string }>,
            temperature: 0.5,
            max_tokens: 2048,
            stream: false,
          })
          : JSON.stringify({
            model,
            messages: llmMessages,
            temperature: 0.5,
            max_tokens: 2048,
            stream: false,
          }),
      });

      if (resp.ok) {
        const data = await resp.json();
        const reply = isMessages
          ? textFromOpenModelMessages(data)
          : data?.choices?.[0]?.message?.content;
        if (typeof reply === "string" && reply.trim() !== "") {
          return json({ reply: reply.trim(), model });
        }
        lastError = `empty_reply (model=${model})`;
        continue;
      }

      const text = await resp.text();
      // 401/403 with ModelError → wrong model name, try next.
      // 401/403 with AuthError → bad key, no point trying other models.
      if (resp.status === 401 || resp.status === 403) {
        if (text.includes("ModelError") || text.includes("model")) {
          lastError = `model=${model} → HTTP ${resp.status}: ${
            text.slice(0, 200)
          }`;
          continue;
        }
        return json({
          error: "auth_failed",
          status: resp.status,
          detail: text.slice(0, 300),
        }, 502);
      }
      // Other error → try next model
      lastError = `model=${model} → HTTP ${resp.status}: ${text.slice(0, 200)}`;
    } catch (e) {
      lastError = `model=${model} → ${String(e).slice(0, 200)}`;
    }
  }

  return json({
    error: "all_models_failed",
    detail: lastError.slice(0, 500),
    tried: models,
  }, 502);
});
