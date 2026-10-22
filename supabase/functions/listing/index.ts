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

// One advertisement or deal, for a link shared on WhatsApp or social media:
// readable by anyone, then an invitation to install (Business Plan 2). Read
// with the publishable key, so an ad from a hidden listing 404s here too.
async function adPage(adId: string, url: string, key: string): Promise<Response> {
  const headers = { apikey: key, authorization: `Bearer ${key}` };
  const res = await fetch(
    `${url}/rest/v1/business_ads?id=eq.${adId}` +
      "&select=title,body,image_url,starts_at,ends_at,offer_code,offer_terms," +
      "businesses(id,name,area,phone,whatsapp)",
    { headers },
  );
  const rows = res.ok ? await res.json() : [];
  const ad = rows[0];
  const now = Date.now();
  const live = ad &&
    Date.parse(ad.starts_at) <= now &&
    (!ad.ends_at || Date.parse(ad.ends_at) > now);
  if (!live || !ad.businesses) {
    return page("Not found", `<div class="card"><h1>This advertisement has ended</h1>
<p class="muted">Find what is on now in the Dadliplug app.</p></div>`);
  }
  const b = ad.businesses;
  const wa = String(b.whatsapp ?? "").replace(/[^0-9]/g, "");
  const waText = encodeURIComponent(`Hi, I saw "${ad.title}" on Dadliplug.`);
  const until = ad.ends_at
    ? new Date(ad.ends_at).toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: "America/Antigua" })
    : "";
  const install = Deno.env.get("INSTALL_URL") ?? "";
  const meta = `
<meta property="og:type" content="website">
<meta property="og:title" content="${esc((ad.offer_code ? "Deal: " : "") + ad.title)}">
<meta property="og:description" content="${esc(b.name + (ad.offer_terms ? " — " + ad.offer_terms : ad.body ? " — " + String(ad.body).slice(0, 200) : ""))}">
${ad.image_url ? `<meta property="og:image" content="${esc(ad.image_url)}">` : ""}`;
  const body = `
${ad.image_url ? `<img class="hero" src="${esc(ad.image_url)}" alt="">` : ""}
<div class="card">
  <div class="muted">${esc(b.name)}${b.area ? " · " + esc(b.area) : ""}</div>
  <h1>${esc(ad.title)}</h1>
  ${ad.body ? `<p>${esc(ad.body)}</p>` : ""}
  ${ad.offer_code ? `<p><b>Deal code: ${esc(ad.offer_code)}</b>${ad.offer_terms ? `<br><span class="muted">${esc(ad.offer_terms)}</span>` : ""}</p>` : ""}
  ${until ? `<p class="muted">Until ${esc(until)}</p>` : ""}
  ${b.phone ? `<a class="btn call" href="tel:${esc(b.phone)}">Call</a>` : ""}
  ${wa ? `<a class="btn wa" href="https://wa.me/${wa}?text=${waText}">WhatsApp</a>` : ""}
</div>
<div class="card">
  <b>Get Dadliplug</b>
  <p class="muted">Every deal and new ad in Antigua, on one map.${ad.offer_code ? " Claim this deal in the app to get your own code for the till." : ""}</p>
  ${install ? `<a class="btn call" href="${esc(install)}">Get the app</a>` : `<span class="muted">Coming soon to Google Play and the App Store.</span>`}
</div>`;
  return page(`${ad.title} — ${b.name} — Dadliplug`, body, meta);
}

Deno.serve(async (req) => {
  const params = new URL(req.url).searchParams;
  const id = params.get("id") ?? "";
  const adId = params.get("ad") ?? "";
  if (adId) {
    if (!/^[0-9a-f-]{36}$/i.test(adId)) {
      return page("Not found", `<div class="card"><h1>Not found</h1></div>`);
    }
    return adPage(adId, Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);
  }
  // A pre-built listing, shown to its owner before it is public (plan.md
  // Phase 10). Read through prospect_preview(), which returns only the
  // listing whose secret token matches.
  const preview = params.get("preview") ?? "";
  const isUuid = (s: string) => /^[0-9a-f-]{36}$/i.test(s);
  // Only a uuid reaches the database query string.
  if (!isUuid(preview ? preview : id)) {
    return page("Not found", `<div class="card"><h1>Listing not found</h1></div>`);
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_ANON_KEY")!;
  const headers = { apikey: key, authorization: `Bearer ${key}` };
  const res = preview
    ? await fetch(`${url}/rest/v1/rpc/prospect_preview`, {
      method: "POST",
      headers: { ...headers, "content-type": "application/json" },
      body: JSON.stringify({ p_token: preview }),
    })
    : await fetch(
      `${url}/rest/v1/businesses?id=eq.${id}` +
        "&select=name,category,area,description,phone,whatsapp,photos",
      { headers },
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

  const meta = (preview ? `<meta name="robots" content="noindex,nofollow">` : "") + `
<meta property="og:type" content="website">
<meta property="og:title" content="${esc(b.name)}">
<meta property="og:description" content="${esc(summary + (description ? " — " + description : ""))}">
${photo ? `<meta property="og:image" content="${esc(photo)}">` : ""}
<meta name="description" content="${esc(description || summary)}">`;

  const body = `
${preview ? `<div class="card" style="border-color:#f59e0b;background:#fffbeb"><b>Preview.</b> This is how your listing will look on Dadliplug. It is not public yet: only people with this link can see it.</div>` : ""}
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
