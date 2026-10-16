// Sends queued push notifications through Firebase Cloud Messaging (HTTP v1).
//
// Pinged by a database trigger after an announcement or review request is
// inserted (migration 20261015160000). Sends every unsent push_outbox row, so
// a direct call can only deliver alerts that were already due.
//
// Secrets: FIREBASE_SERVICE_ACCOUNT (the Firebase admin service-account JSON).
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by the platform.

import { createClient } from "@supabase/supabase-js";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const account: ServiceAccount | null = (() => {
  try {
    return JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "");
  } catch {
    return null;
  }
})();

function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

let cachedToken: { value: string; expires: number } | null = null;

/** An OAuth access token for FCM, from the service account (RS256 JWT). */
async function accessToken(sa: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expires > Date.now() + 60_000) {
    return cachedToken.value;
  }
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(`${header}.${claims}`),
    ),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(signature)}`,
    }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`token: ${JSON.stringify(json)}`);
  cachedToken = { value: json.access_token, expires: Date.now() + json.expires_in * 1000 };
  return cachedToken.value;
}

type Alert = { userIds: string[]; title: string; body: string; route: string };

/** Who to tell, and what, for one outbox row. */
async function resolve(kind: string, refId: string): Promise<Alert | null> {
  if (kind === "announcement") {
    const { data: a } = await db
      .from("business_announcements")
      .select("title, body, business_id, businesses (name)")
      .eq("id", refId)
      .maybeSingle();
    if (!a) return null;
    const { data: follows } = await db
      .from("business_follows")
      .select("user_id")
      .eq("business_id", a.business_id)
      .eq("notify", true);
    // deno-lint-ignore no-explicit-any
    const name = (a as any).businesses?.name ?? "A business";
    return {
      userIds: (follows ?? []).map((f) => f.user_id),
      title: `${name}: ${a.title}`,
      body: String(a.body ?? "").slice(0, 180),
      route: "/announcements",
    };
  }
  if (kind === "review_request") {
    const { data: r } = await db
      .from("review_requests")
      .select("business_id, businesses (name)")
      .eq("id", refId)
      .maybeSingle();
    if (!r) return null;
    const { data: owners } = await db
      .from("profiles")
      .select("id")
      .contains("business_ids", [r.business_id]);
    // deno-lint-ignore no-explicit-any
    const name = (r as any).businesses?.name ?? "your business";
    return {
      userIds: (owners ?? []).map((o) => o.id),
      title: "New review request",
      body: `A customer asked to review ${name}. Approve or decline it.`,
      route: `/business/reviews?business=${r.business_id}`,
    };
  }
  return null;
}

async function send(sa: ServiceAccount, token: string, alert: Alert) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${await accessToken(sa)}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: alert.title, body: alert.body },
          data: { route: alert.route },
          android: { priority: "high" },
        },
      }),
    },
  );
  if (res.ok) return "ok";
  const text = await res.text();
  // The phone uninstalled or the token rotated: forget it.
  if (res.status === 404 || text.includes("UNREGISTERED")) {
    await db.from("push_tokens").delete().eq("token", token);
    return "gone";
  }
  throw new Error(`fcm ${res.status}: ${text.slice(0, 300)}`);
}

Deno.serve(async () => {
  if (!account) {
    return new Response("FIREBASE_SERVICE_ACCOUNT is not set", { status: 500 });
  }

  const { data: rows } = await db
    .from("push_outbox")
    .select("id, kind, ref_id")
    .is("sent_at", null)
    .order("created_at")
    .limit(50);

  let delivered = 0;
  for (const row of rows ?? []) {
    try {
      const alert = await resolve(row.kind, row.ref_id);
      let count = 0;
      if (alert && alert.userIds.length > 0) {
        const { data: tokens } = await db
          .from("push_tokens")
          .select("token")
          .in("user_id", alert.userIds);
        for (const t of tokens ?? []) {
          if ((await send(account, t.token, alert)) === "ok") count++;
        }
      }
      await db.from("push_outbox")
        .update({ sent_at: new Date().toISOString(), sent_count: count, error: null })
        .eq("id", row.id);
      delivered += count;
    } catch (e) {
      console.error(`push ${row.id} failed`, e);
      await db.from("push_outbox").update({ error: String(e).slice(0, 500) }).eq("id", row.id);
    }
  }

  return Response.json({ processed: rows?.length ?? 0, delivered });
});
