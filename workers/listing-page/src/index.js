// Public website and listing pages: https://dadliplug.com
//
// 1. Static website: served via env.ASSETS (homepage, styling, brand images).
// 2. /api/lead: inserts "Get listed" applications into Supabase business_leads
//    and emails them to the support inbox (SUPPORT_EMAIL).
// 3. /privacy, /terms, /delete-account: app store required legal pages.
// 4. /l/<id>, /a/<id>, /p/<token>: dynamic business, ad, and preview pages.

import { EmailMessage } from "cloudflare:email";
import privacy from "../../../app/assets/legal/privacy.md";
import terms from "../../../app/assets/legal/terms.md";
import deleteAccount from "../../../app/assets/legal/delete-account.md";

const LEGAL = {
  "/privacy": { title: "Privacy Policy", md: privacy },
  "/terms": { title: "Terms of Service", md: terms },
  "/delete-account": { title: "Delete Your Account", md: deleteAccount },
};

const escape = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const inline = (s) => escape(s).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");

function renderLegal(entry, contact) {
  const out = [];
  let para = [];
  let list = null;
  const flush = () => {
    if (para.length) out.push(`<p>${inline(para.join(" "))}</p>`);
    para = [];
    if (list) out.push(`</${list}>`);
    list = null;
  };
  for (const raw of entry.md.replaceAll("{{CONTACT}}", contact).split("\n")) {
    const line = raw.trimEnd();
    let m;
    if (!line.trim()) flush();
    else if ((m = line.match(/^(#{1,3}) (.*)$/))) {
      flush();
      out.push(`<h${m[1].length}>${inline(m[2])}</h${m[1].length}>`);
    } else if ((m = line.match(/^(- |\d+\. )(.*)$/))) {
      const kind = m[1] === "- " ? "ul" : "ol";
      if (para.length) { out.push(`<p>${inline(para.join(" "))}</p>`); para = []; }
      if (list !== kind) { if (list) out.push(`</${list}>`); out.push(`<${kind}>`); list = kind; }
      out.push(`<li>${inline(m[2])}</li>`);
    } else para.push(line.trim());
  }
  flush();
  return (
    "<!doctype html><html lang=en><meta charset=utf-8>" +
    "<meta name=viewport content='width=device-width,initial-scale=1'>" +
    `<title>${escape(entry.title)} | Dadliplug</title>` +
    "<link rel='icon' type='image/png' href='/assets/logo.png'>" +
    "<link rel='stylesheet' href='https://fonts.googleapis.com/css2?family=Gabarito:wght@700;800&family=Hanken+Grotesk:wght@400;500;600;700&display=swap'>" +
    "<style>" +
    ":root{--navy:#0A1F44;--gold:#FFC72C;--ink:#0A1F44;--muted:#5B6B85;--line:#DDE4EF;--app:#F5F7FB}" +
    "*{box-sizing:border-box}body{font:400 16px/1.6 'Hanken Grotesk',system-ui,sans-serif;color:var(--ink);background:var(--app);margin:0;padding:0}" +
    "header{background:var(--navy);color:#fff;padding:16px 24px;border-bottom:1px solid rgba(255,255,255,.1)}" +
    ".nav-inner{max-width:760px;margin:0 auto;display:flex;align-items:center;justify-content:space-between}" +
    ".brand{display:inline-flex;align-items:center;gap:10px;color:#fff;text-decoration:none;font:800 20px 'Gabarito',sans-serif}" +
    ".brand img{border-radius:8px}.brand b{color:var(--gold)}" +
    ".back{color:rgba(255,255,255,.8);text-decoration:none;font-size:14px;font-weight:600}" +
    ".back:hover{color:#fff}" +
    "main{max-width:760px;margin:40px auto;background:#fff;padding:40px;border-radius:16px;border:1px solid var(--line);box-shadow:0 1px 3px rgba(10,31,68,.05)}" +
    "h1{font:800 32px 'Gabarito',sans-serif;margin:0 0 24px;color:var(--navy)}" +
    "h2{font:700 22px 'Gabarito',sans-serif;margin:28px 0 12px;color:var(--navy)}" +
    "h3{font:700 18px 'Gabarito',sans-serif;margin:20px 0 8px;color:var(--navy)}" +
    "p{margin:0 0 14px;color:#223348}ul,ol{margin:0 0 16px;padding-left:24px;color:#223348}li{margin-bottom:6px}" +
    "footer{text-align:center;color:var(--muted);font-size:13px;padding:24px;margin-bottom:32px}" +
    "@media(max-width:640px){main{margin:16px;padding:24px}}" +
    "</style><body>" +
    "<header><div class='nav-inner'><a class='brand' href='/'><img src='/assets/logo.png' width=28 height=28 alt=''><span>Dadli<b>plug</b></span></a><a class='back' href='/'>← Back to home</a></div></header>" +
    "<main>" +
    out.join("\n") +
    "</main><footer>© " + new Date().getFullYear() + " Dadliplug · Antigua &amp; Barbuda</footer></body></html>"
  );
}

const PLAN_LABELS = {
  growing: "Starter (EC$25/mo)",
  basic: "Growth (EC$50/mo)",
  featured: "Premium (EC$100/mo)",
  unsure: "Not sure yet",
};

const CATEGORY_LABELS = {
  food: "Food & Drink",
  shopping: "Shopping & Retail",
  services: "Trades & Services",
  health_beauty: "Health & Beauty",
  entertainment: "Entertainment & Tours",
  automotive: "Automotive",
  real_estate: "Real Estate",
  education: "Education",
  other: "Other / Online",
};

// UTF-8 text to base64, wrapped at 76 columns for MIME.
const b64 = (s) => {
  const bytes = new TextEncoder().encode(s);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
};
const wrap76 = (s) => s.match(/.{1,76}/g)?.join("\r\n") ?? "";
// Strip anything that could break out of a header line.
const oneLine = (s) => String(s).replace(/[\r\n]+/g, " ").trim();

// Emails a new "Get listed" application to the support inbox. Uses the
// Cloudflare Email Routing binding LEAD_EMAIL (wrangler.toml), which only
// delivers to the verified destination address.
async function emailLead(env, lead) {
  if (!env.LEAD_EMAIL || !env.SUPPORT_EMAIL) return;
  const from = env.LEAD_FROM_EMAIL || "leads@dadliplug.com";
  const to = env.SUPPORT_EMAIL;
  const plan = PLAN_LABELS[lead.plan_interest] || lead.plan_interest;
  const category = CATEGORY_LABELS[lead.category] || lead.category;

  const subject = `New listing request: ${oneLine(lead.business_name)} - ${plan}`;
  const text = [
    "A business has asked to be listed on Dadliplug.",
    "",
    `Tier requested: ${plan}`,
    "",
    `Business:  ${lead.business_name}`,
    `Category:  ${category}`,
    `Area:      ${lead.area || "-"}`,
    `Contact:   ${lead.contact_name}`,
    `Phone:     ${lead.phone}`,
    `WhatsApp:  https://wa.me/${lead.phone.replace(/\D/g, "")}`,
    "",
    "Notes:",
    lead.note || "-",
    "",
    "Saved to Supabase business_leads with status 'new'.",
  ].join("\n");

  const domain = from.split("@")[1] || "dadliplug.com";
  const raw = [
    `From: Dadliplug Website <${from}>`,
    `To: ${to}`,
    `Subject: =?UTF-8?B?${b64(subject)}?=`,
    `Date: ${new Date().toUTCString()}`,
    `Message-ID: <${crypto.randomUUID()}@${domain}>`,
    "MIME-Version: 1.0",
    "Content-Type: text/plain; charset=utf-8",
    "Content-Transfer-Encoding: base64",
    "",
    wrap76(b64(text)),
    "",
  ].join("\r\n");

  await env.LEAD_EMAIL.send(new EmailMessage(from, to, raw));
}

const ORIGIN =
  "https://ftenxsusyuiqatnvasny.supabase.co/functions/v1/listing";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname.replace(/\/$/, "");

    // 1. Legal pages
    const legal = LEGAL[pathname];
    if (legal) {
      const email = (env && env.SUPPORT_EMAIL) || "";
      const contact = email
        ? `Email ${email}.`
        : 'Use "Report wrong info" on any listing, or message the Dadliplug team on WhatsApp.';
      return new Response(renderLegal(legal, contact), {
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "public, max-age=3600",
        },
      });
    }

    // 2. Lead submission API
    if (pathname === "/api/lead" && request.method === "POST") {
      try {
        const body = await request.json();
        // Honeypot check for spam bots
        if (body.website) {
          return new Response(JSON.stringify({ ok: true }), {
            headers: { "content-type": "application/json" },
          });
        }

        const businessName = (body.business_name || "").trim();
        const contactName = (body.contact_name || "").trim();
        const phone = (body.phone || "").trim();
        const category = (body.category || "").trim();

        if (!businessName || !contactName || !phone || !category) {
          return new Response(
            JSON.stringify({ error: "Missing required fields" }),
            { status: 400, headers: { "content-type": "application/json" } },
          );
        }

        const supabaseUrl = env.SUPABASE_URL || "https://ftenxsusyuiqatnvasny.supabase.co";
        const supabaseKey = env.SUPABASE_ANON_KEY;

        const payload = {
          business_name: businessName.slice(0, 80),
          contact_name: contactName.slice(0, 80),
          phone: phone.slice(0, 30),
          category: category,
          area: (body.area || "").trim().slice(0, 60),
          plan_interest: ["growing", "basic", "featured", "unsure"].includes(body.plan_interest)
            ? body.plan_interest
            : "unsure",
          maintenance: "unsure",
          note: (body.note || "").trim().slice(0, 500) || null,
          source: "app",
          status: "new",
        };

        const sbRes = await fetch(`${supabaseUrl}/rest/v1/business_leads`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "apikey": supabaseKey,
            "Authorization": `Bearer ${supabaseKey}`,
            "Prefer": "return=minimal",
          },
          body: JSON.stringify(payload),
        });

        if (!sbRes.ok) {
          const errText = await sbRes.text();
          return new Response(JSON.stringify({ error: errText }), {
            status: 502,
            headers: { "content-type": "application/json" },
          });
        }

        // The lead is saved; the email is a notification on top. Send it in
        // the background so a mail hiccup never fails the applicant's submit.
        const mail = emailLead(env, payload).catch((e) =>
          console.error("Lead email failed:", e && e.message),
        );
        if (ctx && ctx.waitUntil) ctx.waitUntil(mail);

        return new Response(JSON.stringify({ ok: true }), {
          status: 201,
          headers: { "content-type": "application/json" },
        });
      } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 500,
          headers: { "content-type": "application/json" },
        });
      }
    }

    // 3. /a/<ad-id>: one advertisement or deal
    const adMatch = url.pathname.match(/^\/a\/([^/]+)\/?$/);
    if (adMatch) {
      if (!UUID.test(adMatch[1])) {
        return new Response("Not found", { status: 404 });
      }
      const upstream = await fetch(`${ORIGIN}?ad=${adMatch[1]}`, {
        cf: { cacheTtl: 300, cacheEverything: true },
      });
      const body = await upstream.text();
      return new Response(body, {
        status: body.includes("<h1>Not found</h1>") ? 404 : upstream.ok ? 200 : 502,
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "public, max-age=300",
          "x-content-type-options": "nosniff",
        },
      });
    }

    // 4. /p/<token>: a pre-built listing's private preview for its owner
    const previewMatch = url.pathname.match(/^\/p\/([^/]+)\/?$/);
    if (previewMatch) {
      if (!UUID.test(previewMatch[1])) {
        return new Response("Listing not found", { status: 404 });
      }
      const upstream = await fetch(`${ORIGIN}?preview=${previewMatch[1]}`);
      const body = await upstream.text();
      return new Response(body, {
        status: body.includes("Listing not found") ? 404 : upstream.ok ? 200 : 502,
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "private, no-store",
          "x-robots-tag": "noindex, nofollow",
          "x-content-type-options": "nosniff",
        },
      });
    }

    // 5. /l/<id>: public listing page
    const match = url.pathname.match(/^\/l\/([^/]+)\/?$/);
    const listingId = match ? match[1] : (url.pathname === "/l" ? url.searchParams.get("id") : null);

    if (listingId) {
      if (!UUID.test(listingId)) {
        return new Response("Listing not found", { status: 404 });
      }

      const upstream = await fetch(`${ORIGIN}?id=${listingId}`, {
        cf: { cacheTtl: 300, cacheEverything: true },
      });
      const body = await upstream.text();
      const notFound = body.includes("Listing not found");

      return new Response(body, {
        status: notFound ? 404 : upstream.ok ? 200 : 502,
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "public, max-age=300",
          "x-content-type-options": "nosniff",
        },
      });
    }

    // 6. Static assets (website homepage, styles, scripts, images)
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    return new Response("Not found", { status: 404 });
  },
};
