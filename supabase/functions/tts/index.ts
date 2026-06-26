// tts — Mandarin card/text audio with proper tones.
//
// The on-device engine (flutter_tts → Windows SAPI) has weak, often wrong
// Mandarin tones. This proxies Google Translate's TTS (free, no key, clear and
// tonally correct) and returns base64 MP3. Text is chunked (the upstream caps
// each request at ~200 chars) and the MP3 parts are concatenated (MP3 frames
// join cleanly). The client caches results and falls back to flutter_tts when
// offline or on any failure.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { encodeBase64 } from "jsr:@std/encoding/base64";

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

/// Splits [text] into <=160-char chunks, preferring to break on punctuation so
/// each chunk is a natural phrase.
function chunk(text: string): string[] {
  const max = 160;
  const out: string[] = [];
  let buf = "";
  for (const ch of text) {
    buf += ch;
    const isBreak = "。！？，、；：.!?,;\n ".includes(ch);
    if (buf.length >= max && (isBreak || buf.length >= max + 40)) {
      out.push(buf);
      buf = "";
    }
  }
  if (buf.trim() !== "") out.push(buf);
  return out.length === 0 ? [text] : out;
}

async function fetchPart(text: string, tl: string): Promise<Uint8Array | null> {
  const url = "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob" +
    `&tl=${encodeURIComponent(tl)}&ttsspeed=0.24&q=${encodeURIComponent(text)}`;
  try {
    const resp = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
          "(KHTML, like Gecko) Chrome/120.0 Safari/537.36",
        "Referer": "https://translate.google.com/",
      },
    });
    if (!resp.ok) return null;
    const buf = new Uint8Array(await resp.arrayBuffer());
    return buf.byteLength > 0 ? buf : null;
  } catch (_) {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let payload: { text?: string; track?: string; lang?: string };
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: "bad_json" }, 400);
  }
  const text = typeof payload.text === "string" ? payload.text.trim() : "";
  if (text === "") return json({ error: "empty_text" }, 400);
  const tl = payload.lang ??
    (payload.track === "traditional" ? "zh-TW" : "zh-CN");

  const parts: Uint8Array[] = [];
  for (const c of chunk(text.slice(0, 600))) {
    const part = await fetchPart(c, tl);
    if (part) parts.push(part);
  }
  if (parts.length === 0) return json({ error: "tts_failed" }, 502);

  let total = 0;
  for (const p of parts) total += p.byteLength;
  const merged = new Uint8Array(total);
  let off = 0;
  for (const p of parts) {
    merged.set(p, off);
    off += p.byteLength;
  }

  return json({ audio: encodeBase64(merged), mime: "audio/mpeg" });
});
