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

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function wavSampleRate(b: Uint8Array): number {
  if (b.length < 28) return 16000;
  const r = b[24] | (b[25] << 8) | (b[26] << 16) | (b[27] << 24);
  return r > 0 ? r : 16000;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const key = Deno.env.get("AZURE_SPEECH_KEY");
  const region = Deno.env.get("AZURE_SPEECH_REGION") ?? "southeastasia";
  if (!key) {
    return json({ error: "not_configured", detail: "Set AZURE_SPEECH_KEY as Edge Function secret." }, 503);
  }

  let payload: { audio?: string; reference_text?: string; lang?: string };
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: "bad_json" }, 400);
  }
  if (typeof payload.audio !== "string" || payload.audio === "") {
    return json({ error: "no_audio" }, 400);
  }
  const refText = typeof payload.reference_text === "string" ? payload.reference_text : "";
  if (refText === "") return json({ error: "no_reference_text" }, 400);
  const locale = payload.lang === "id" ? "id-ID" : "zh-CN";

  let bytes: Uint8Array;
  try {
    bytes = b64ToBytes(payload.audio);
  } catch (_) {
    return json({ error: "bad_audio" }, 400);
  }
  const rate = wavSampleRate(bytes);

  const endpoint =
    `https://${region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=${locale}&format=detailed`;

  try {
    const resp = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": key,
        "Content-Type": `audio/wav; codecs=audio/pcm; samplerate=${rate}`,
        "Accept": "application/json",
      },
      body: bytes,
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

    const transcript = data?.DisplayText ??
      (Array.isArray(data?.NBest) && data.NBest[0]?.Display) ?? "";
    const confidence = Array.isArray(data?.NBest) && data.NBest[0]?.Confidence != null
      ? Math.round(data.NBest[0].Confidence * 100)
      : null;
    const words = Array.isArray(data?.NBest?.[0]?.Words)
      ? data.NBest[0].Words.map((w: { Word: string; Confidence?: number }) => ({
          word: w.Word,
          confidence: w.Confidence != null ? Math.round(w.Confidence * 100) : null,
        }))
      : [];

    const score = confidence != null ? confidence : 0;

    return json({
      transcript: typeof transcript === "string" ? transcript.trim() : "",
      score,
      words,
    });
  } catch (e) {
    return json({ error: "fetch_failed", detail: String(e).slice(0, 500) }, 502);
  }
});
