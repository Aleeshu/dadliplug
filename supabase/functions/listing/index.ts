// Public web page for one listing: GET /functions/v1/listing?id=<uuid>
//
// The link a business puts in its Instagram or Facebook bio, and what a
// WhatsApp share previews (plan.md section 12). Plain server-rendered HTML
// with Open Graph tags, so link previews work without JavaScript.
//
// Reads with the publishable key, so Row Level Security decides what is
// public exactly as it does in the app: a delisted business 404s here too.
// Deployed with --no-verify-jwt, because a link in a bio has no token.

const CATEGORY: Record<string, string> = {
  food: "Food & Drink",
  shopping: "Shopping",
  services: "Services",
  health_beauty: "Health & Beauty",
  entertainment: "Entertainment",
  automotive: "Automotive",
  real_estate: "Real Estate",
  education: "Education",
  other: "Other",
};

function esc(s: unknown): string {
  return String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function page(title: string, body: string, meta = ""): Response {
  const html = `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title>
${meta}
<style>
  body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#f8f9fb;color:#111827}
  .wrap{max-width:560px;margin:0 auto;padding:24px}
  .brand{display:flex;align-items:center;gap:8px;font-weight:800;font-size:20px}
  .brand b{color:#3cb043}
  .card{background:#fff;border:1px solid #e5e7eb;border-radius:16px;padding:20px;margin-top:20px}
  h1{margin:0 0 4px;font-size:26px}
  .muted{color:#6b7280}
  .btn{display:inline-block;margin:12px 8px 0 0;padding:12px 18px;border-radius:14px;text-decoration:none;font-weight:600}
  .call{background:#e8253f;color:#fff}
  .wa{border:1px solid #25d366;color:#128c4a}
  img.hero{width:100%;border-radius:16px;margin-top:20px;object-fit:cover;max-height:280px}
</style>
</head><body><div class="wrap">
<div class="brand">Dadli<b>plug</b></div>
${body}
<p class="muted" style="margin-top:28px">Found on Dadliplug — Plug Into Local.</p>
</div></body></html>`;
  return new Response(html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
    },
  });
}

Deno.serve(async (req) => {
  const id = new URL(req.url).searchParams.get("id") ?? "";
  // Only a uuid reaches the database query string.
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    return page("Not found", `<div class="card"><h1>Listing not found</h1></div>`);
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_ANON_KEY")!;
  const res = await fetch(
    `${url}/rest/v1/businesses?id=eq.${id}` +
      "&select=name,category,area,description,phone,whatsapp,photos",
    { headers: { apikey: key, authorization: `Bearer ${key}` } },
  );
  const rows = res.ok ? await res.json() : [];
  const b = rows[0];
  if (!b) {
    return page("Not found", `<div class="card"><h1>Listing not found</h1>
<p class="muted">It may have been removed.</p></div>`);
  }

  const category = CATEGORY[b.category] ?? "";
  const summary = [category, b.area].filter(Boolean).join(" · ");
  const description = String(b.description ?? "").slice(0, 300);
  const photo = Array.isArray(b.photos)
    ? b.photos.map((p: { url?: string }) => p?.url).find(Boolean)
    : undefined;
  const wa = String(b.whatsapp ?? "").replace(/[^0-9]/g, "");
  const waText = encodeURIComponent(
    `Hi, I found you on Dadliplug (${b.name}). Are you open today?`,
  );

  const meta = `
<meta property="og:type" content="website">
<meta property="og:title" content="${esc(b.name)}">
<meta property="og:description" content="${esc(summary + (description ? " — " + description : ""))}">
${photo ? `<meta property="og:image" content="${esc(photo)}">` : ""}
<meta name="description" content="${esc(description || summary)}">`;

  const body = `
${photo ? `<img class="hero" src="${esc(photo)}" alt="">` : ""}
<div class="card">
  <h1>${esc(b.name)}</h1>
  <div class="muted">${esc(summary)}</div>
  ${description ? `<p>${esc(description)}</p>` : ""}
  ${b.phone ? `<a class="btn call" href="tel:${esc(b.phone)}">Call</a>` : ""}
  ${wa ? `<a class="btn wa" href="https://wa.me/${wa}?text=${waText}">WhatsApp</a>` : ""}
</div>`;

  return page(`${b.name} — Dadliplug`, body, meta);
});
