// ocr — photo-to-text for the translator. Sends a base64 image to a vision chat
// model (OpenAI-compatible image_url) and returns the extracted text.
// Defaults to OpenCode Zen; override OCR_* secrets to use any provider/model.
// Key stays server-side; requires a Supabase user JWT (verify_jwt = true).
//
// NOTE: OpenCode Zen vision models (gemini/gpt/claude) require a paid plan; the
// free models are text-only. So OCR needs either OpenCode Zen credits or an
// OCR_API_KEY for another vision provider.
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const apiKey = Deno.env.get("OCR_API_KEY") ?? Deno.env.get("OPENCODE_ZEN_API_KEY");
  const baseRaw = Deno.env.get("OCR_BASE_URL") ?? Deno.env.get("OPENCODE_ZEN_BASE_URL");
  const model = Deno.env.get("OCR_MODEL") ?? "gemini-3-flash";
  if (!apiKey || !baseRaw) {
    return json({
      error: "not_configured",
      detail:
        "Set OCR_API_KEY + OCR_BASE_URL (+ optional OCR_MODEL) as secrets, or rely on OPENCODE_ZEN_* with a vision-capable model. OpenCode Zen vision needs a paid plan.",
    }, 503);
  }
  const trimmed = baseRaw.trim().replace(/\/+$/, "");
  const endpoint = trimmed.endsWith("/chat/completions")
    ? trimmed
    : `${trimmed}/chat/completions`;

  let payload: { image?: string; mime?: string };
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: "bad_json" }, 400);
  }
  if (typeof payload.image !== "string" || payload.image === "") {
    return json({ error: "no_image" }, 400);
  }
  const mime = typeof payload.mime === "string" ? payload.mime : "image/jpeg";
  const dataUrl = `data:${mime};base64,${payload.image}`;

  const messages = [
    {
      role: "user",
      content: [
        {
          type: "text",
          text:
            "Ekstrak SEMUA teks dalam gambar ini. Pertahankan karakter Mandarin apa adanya. Keluarkan HANYA teksnya, tanpa komentar.",
        },
        { type: "image_url", image_url: { url: dataUrl } },
      ],
    },
  ];

  try {
    const resp = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ model, messages, max_tokens: 700, temperature: 0 }),
    });
    const text = await resp.text();
    if (!resp.ok) {
      return json({ error: "upstream", status: resp.status, detail: text.slice(0, 500) }, 502);
    }
    let data: any;
    try {
      data = JSON.parse(text);
    } catch (_) {
      return json({ error: "upstream_parse", detail: text.slice(0, 300) }, 502);
    }
    const out = data?.choices?.[0]?.message?.content;
    return json({ text: typeof out === "string" ? out.trim() : "" });
  } catch (e) {
    return json({ error: "fetch_failed", detail: String(e).slice(0, 500) }, 502);
  }
});
