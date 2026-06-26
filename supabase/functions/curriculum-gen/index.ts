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

interface Material {
  topic: string;
  vocab: Array<{
    hanzi: string;
    pinyin: string;
    meaning: string;
  }>;
  sentences: string[];
  exercise: string;
}

function buildPrompt(track: string, level: string, count: number): string {
  const variant = track === "traditional" ? "hanzi tradisional + 注音" : "hanzi sederhana + pinyin";
  return [
    "Kamu kurikulum bahasa Mandarin. Buatkan materi belajar.",
    "Gunakan " + variant + ". Level siswa: " + level + ".",
    "Output HANYA satu JSON valid tanpa markdown:",
    '{ "materials": [{ "topic": string, "vocab": [{ "hanzi": string, "pinyin": string, "meaning": string }], "sentences": string[], "exercise": string }] }',
    "Buat " + count + " topik materi. Vocab 4-6 kata per topik. Exercise = instruksi singkat dalam Bahasa Indonesia.",
    "Jangan pakai emoji. Jangan pakai kode atau penjelasan tambahan.",
  ].join(" ");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const apiKey = Deno.env.get("OPENCODE_ZEN_API_KEY");
  const baseRaw = Deno.env.get("OPENCODE_ZEN_BASE_URL");
  const model = Deno.env.get("OPENCODE_ZEN_MODEL");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!apiKey || !baseRaw || !model || !supabaseUrl || !serviceKey) {
    return json({ error: "not_configured" }, 503);
  }

  let payload: { level?: string; track?: string; force?: boolean };
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: "bad_json" }, 400);
  }

  const level = typeof payload.level === "string" ? payload.level : "HSK 1-2";
  const track = payload.track === "traditional" ? "traditional" : "simplified";
  const force = payload.force === true;
  const cacheKey = `curriculum:${track}:${level}`;
  const admin = createClient(supabaseUrl, serviceKey);

  if (!force) {
    const { data: existing } = await admin
      .from("materials")
      .select("content, updated_at")
      .eq("cache_key", cacheKey)
      .single();
    if (existing?.content) {
      return json({ cached: true, materials: existing.content, updated_at: existing.updated_at });
    }
  }

  const trimmed = baseRaw.trim().replace(/\/+$/, "");
  const endpoint = trimmed.endsWith("/chat/completions")
    ? trimmed
    : `${trimmed}/chat/completions`;

  const count = level.includes("1") || level.includes("A") ? 3 : 5;

  try {
    const resp = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: buildPrompt(track, level, count) },
        ],
        temperature: 0.3,
        max_tokens: 4096,
        stream: false,
      }),
    });
    if (!resp.ok) {
      const text = await resp.text();
      return json({ error: "upstream", status: resp.status, detail: text.slice(0, 500) }, 502);
    }
    const data = await resp.json();
    const raw = data?.choices?.[0]?.message?.content;
    if (typeof raw !== "string" || raw.trim() === "") {
      return json({ error: "empty_reply" }, 502);
    }

    let s = raw.trim();
    s = s.replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
    const a = s.indexOf("{");
    const b = s.lastIndexOf("}");
    let materials: unknown = null;
    if (a >= 0 && b > a) {
      try {
        const parsed = JSON.parse(s.slice(a, b + 1));
        materials = (parsed as Record<string, unknown>).materials ?? parsed;
      } catch (_) {}
    }

    if (!materials) {
      return json({ error: "parse_failed", raw: raw.slice(0, 300) }, 502);
    }

    const { error: upsertErr } = await admin.from("materials").upsert(
      { cache_key: cacheKey, content: materials, track, level, updated_at: new Date().toISOString() },
      { onConflict: "cache_key" },
    );
    if (upsertErr) {
      console.error("materials upsert error:", upsertErr.message);
    }

    return json({ cached: false, materials });
  } catch (e) {
    return json({ error: "fetch_failed", detail: String(e).slice(0, 500) }, 502);
  }
});
