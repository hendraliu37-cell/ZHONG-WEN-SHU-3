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

function textFromContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .map((part) => {
      if (typeof part === "string") return part;
      if (part && typeof part === "object") {
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

function parseTranslationReply(reply: string): Record<string, unknown> | null {
  let cleaned = reply.trim();
  cleaned = cleaned.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  const jsonMatch = cleaned.match(/\{[\s\S]*\}/);

  if (jsonMatch) {
    try {
      const parsed = JSON.parse(jsonMatch[0]);
      if (parsed.translation) return parsed;
    } catch (_) {
      // fall through to raw
    }
  }

  const raw = cleaned.replace(/["\n]/g, " ").trim();
  if (raw.length > 0 && raw.length < 500) {
    return { translation: raw, pinyin: "", tokens: [], _raw: true };
  }
  return null;
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
    text?: string;
    from?: string;
    to?: string;
    track?: string;
    level?: string;
  };
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: "bad_json" }, 400);
  }

  const text = (payload.text ?? "").trim();
  const from = payload.from === "id" ? "id" : "zh";
  const to = payload.to === "zh" ? "zh" : "id";
  const track = payload.track === "traditional" ? "traditional" : "simplified";

  if (!text) return json({ error: "no_text" }, 400);
  if (from === to) return json({ error: "same_lang" }, 400);

  const usingOpenModel = Boolean(Deno.env.get("OPENMODEL_API_KEY"));
  const baseRaw = Deno.env.get("OPENMODEL_BASE_URL") ??
    Deno.env.get("OPENCODE_GO_BASE_URL") ??
    Deno.env.get("OPENCODE_ZEN_BASE_URL") ??
    (usingOpenModel ? "https://api.openmodel.ai" : "https://api.deepseek.com");
  const isMessages = usingOpenModel || baseRaw.includes("openmodel.ai");
  const llmEndpoint = endpoint(
    baseRaw,
    isMessages ? "/v1/messages" : "/v1/chat/completions",
  );

  const direction = from === "zh"
    ? "Mandarin ke Indonesia"
    : "Indonesia ke Mandarin";
  const hanziStyle = track === "traditional"
    ? "hanzi tradisional (繁體)"
    : "hanzi sederhana (简体)";

  const systemPrompt =
    `Kamu penerjemah profesional ${direction}. Tugas: terjemahkan teks input dengan natural dan akurat.

ATURAN:
1. Terjemahan harus natural, bukan kata-per-kata. Ikuti konteks kalimat.
2. Jangan tambahkan penjelasan, catatan, atau teks lain di luar JSON.
3. Untuk zh→id: terjemahkan ke bahasa Indonesia natural.
4. Untuk id→zh: gunakan ${hanziStyle}. Pilih kata yang paling umum dipakai sehari-hari (bukan sastra/formal).
5. Pinyin: tulis dengan tanda nada (contoh: nǐ hǎo ma). Hanya untuk zh→id atau jika output mengandung hanzi.
6. Tokens: pecahan kata-per-kata dari teks SUMBER (bukan hasil). Setiap token: hanzi/kata sumber + arti singkat.
7. Tokens altMeanings: untuk setiap token, berikan arti alternatif lain (sinonim, arti lain kata tersebut). Contoh "想" meaning="ingin" altMeanings=["berpikir","kangen"]. Maks 3 alt.

Output HARUS JSON valid persis format ini, tanpa markdown, tanpa \`\`\`json:
{"translation":"hasil terjemahan","pinyin":"pinyin jika ada hanzi","tokens":[{"h":"kata sumber","m":"arti utama","alts":["arti2","arti3"]}]}

Contoh zh→id input "我喜欢吃饭":
{"translation":"saya suka makan","pinyin":"wǒ xǐhuān chīfàn","tokens":[{"h":"我","m":"saya","alts":[]},{"h":"喜欢","m":"suka","alts":["gemar"]},{"h":"吃","m":"makan","alts":[]},{"h":"饭","m":"nasi","alts":["makanan"]}]}

Contoh id→zh input "saya suka makan nasi":
{"translation":"我喜欢吃米饭","pinyin":"wǒ xǐhuān chī mǐfàn","tokens":[{"h":"saya","m":"我","alts":[]},{"h":"suka","m":"喜欢","alts":["爱"]},{"h":"makan","m":"吃","alts":[]},{"h":"nasi","m":"米饭","alts":["饭"]}]}`;

  const envModel = Deno.env.get("OPENMODEL_MODEL") ??
    Deno.env.get("OPENCODE_GO_MODEL") ??
    Deno.env.get("OPENCODE_ZEN_MODEL");
  const modelList = [
    "deepseek-v4-flash",
    "deepseek-v4-flash-free",
    "deepseek-chat",
    "deepseek-v3",
  ];
  if (envModel && !modelList.includes(envModel)) modelList.unshift(envModel);
  const seen = new Set<string>();
  const models = modelList.filter((m) => !seen.has(m) && seen.add(m));
  const errors: string[] = [];

  for (const model of models) {
    let gotEmpty = false;
    try {
      const resp = await fetch(llmEndpoint, {
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
            system: systemPrompt,
            messages: [{ role: "user", content: text }],
            temperature: 0.3,
            max_tokens: 1024,
            stream: false,
          })
          : JSON.stringify({
            model,
            messages: [
              { role: "system", content: systemPrompt },
              { role: "user", content: text },
            ],
            temperature: 0.3,
            max_tokens: 1024,
            stream: false,
          }),
      });

      if (resp.ok) {
        const data = await resp.json();
        const reply = isMessages
          ? textFromOpenModelMessages(data)
          : data?.choices?.[0]?.message?.content;
        if (typeof reply === "string" && reply.trim() !== "") {
          const parsed = parseTranslationReply(reply);
          if (parsed) return json({ ...parsed, model });
          errors.push(`${model}: unparseable, raw=${reply.slice(0, 100)}`);
          continue;
        }
        // Empty reply — mark for retry, then try next model if retry also fails.
        gotEmpty = true;
        errors.push(`${model}: empty_reply`);
      } else {
        const errText = await resp.text();
        if (resp.status === 401 || resp.status === 403) {
          if (errText.includes("ModelError") || errText.includes("model")) {
            errors.push(`${model}: ${errText.slice(0, 100)}`);
            continue;
          }
          return json({
            error: "auth_failed",
            status: resp.status,
            detail: errText.slice(0, 300),
          }, 502);
        }
        errors.push(`${model}: HTTP ${resp.status} ${errText.slice(0, 100)}`);
      }
    } catch (e) {
      errors.push(`${model}: ${String(e).slice(0, 100)}`);
    }

    // Retry once after a short delay if we got an empty reply (transient rate limit).
    if (gotEmpty) {
      try {
        await new Promise((r) => setTimeout(r, 1200));
      } catch (_) {}
      try {
        const resp2 = await fetch(llmEndpoint, {
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
              system: systemPrompt,
              messages: [{ role: "user", content: text }],
              temperature: 0.3,
              max_tokens: 1024,
              stream: false,
            })
            : JSON.stringify({
              model,
              messages: [
                { role: "system", content: systemPrompt },
                { role: "user", content: text },
              ],
              temperature: 0.3,
              max_tokens: 1024,
              stream: false,
            }),
        });
        if (resp2.ok) {
          const data2 = await resp2.json();
          const reply2 = isMessages
            ? textFromOpenModelMessages(data2)
            : data2?.choices?.[0]?.message?.content;
          if (typeof reply2 === "string" && reply2.trim() !== "") {
            const parsed = parseTranslationReply(reply2);
            if (parsed) return json({ ...parsed, model, _retry: true });
          }
        }
      } catch (e) {
        errors.push(`${model}: retry_fail ${String(e).slice(0, 80)}`);
      }
    }
  }

  return json({ error: "all_models_failed", errors }, 502);
});
