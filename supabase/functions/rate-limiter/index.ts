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

interface Bucket {
  tokens: number;
  last: number;
}

const buckets = new Map<string, Bucket>();

function check(key: string, limit: number, windowMs: number): { allowed: boolean; remaining: number; reset: number } {
  const now = Date.now();
  let b = buckets.get(key);
  if (!b || now - b.last >= windowMs) {
    b = { tokens: limit, last: now };
    buckets.set(key, b);
  }
  const elapsed = now - b.last;
  const refill = Math.floor(elapsed * (limit / windowMs));
  if (refill > 0) {
    b.tokens = Math.min(limit, b.tokens + refill);
    b.last = now;
  }
  const reset = b.last + windowMs;
  if (b.tokens > 0) {
    b.tokens--;
    return { allowed: true, remaining: b.tokens, reset };
  }
  return { allowed: false, remaining: 0, reset };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";

  let payload: { key?: string; limit?: number; window_ms?: number };
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: "bad_json" }, 400);
  }

  const limit = typeof payload.limit === "number" && payload.limit > 0 ? payload.limit : 30;
  const windowMs = typeof payload.window_ms === "number" && payload.window_ms > 0 ? payload.window_ms : 60000;
  const key = typeof payload.key === "string" && payload.key !== ""
    ? payload.key
    : authHeader.startsWith("Bearer ")
      ? authHeader.slice(7).slice(0, 16)
      : "anonymous";

  const result = check(key, limit, windowMs);

  return json(result);
});
