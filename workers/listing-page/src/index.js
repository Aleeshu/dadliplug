// Public listing pages: https://<worker>/l/<listing-id>
//
// The page itself is rendered by the Supabase Edge Function `listing`. Supabase
// serves function responses on its own domain as text/plain with nosniff, so a
// browser shows the HTML source instead of a page. This Worker fetches it and
// serves it as HTML, nothing more: no data of its own, no keys.

import privacy from "../../../app/assets/legal/privacy.md";
import terms from "../../../app/assets/legal/terms.md";
import deleteAccount from "../../../app/assets/legal/delete-account.md";

// /privacy, /terms and /delete-account: the public URLs the Play Store and
// App Store listings require. Same text as the app's in-app pages.
const LEGAL = {
  "/privacy": privacy,
  "/terms": terms,
  "/delete-account": deleteAccount,
};

const escape = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const inline = (s) => escape(s).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");

// The small Markdown subset the legal files use: headings, "-" and "1."
// lists, paragraphs. Mirrors parseLegal() in the app.
function renderLegal(source, contact) {
  const out = [];
  let para = [];
  let list = null;
  const flush = () => {
    if (para.length) out.push(`<p>${inline(para.join(" "))}</p>`);
    para = [];
    if (list) out.push(`</${list}>`);
    list = null;
  };
  for (const raw of source.replaceAll("{{CONTACT}}", contact).split("\n")) {
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
    "<title>Dadliplug</title><style>body{font-family:system-ui,sans-serif;" +
    "max-width:720px;margin:0 auto;padding:24px;line-height:1.5;color:#1a1a1a}" +
    "h1{font-size:28px}h2{margin-top:28px}</style><body>" +
    out.join("\n") +
    "</body></html>"
  );
}

const ORIGIN =
  "https://ftenxsusyuiqatnvasny.supabase.co/functions/v1/listing";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const legal = LEGAL[url.pathname.replace(/\/$/, "")];
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
    // /a/<ad-id>: one advertisement or deal, shared on WhatsApp or social.
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

    // /p/<token>: a pre-built listing's private preview for its owner.
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
          // Private: never cached by Cloudflare or shared caches.
          "cache-control": "private, no-store",
          "x-robots-tag": "noindex, nofollow",
          "x-content-type-options": "nosniff",
        },
      });
    }

    const match = url.pathname.match(/^\/l\/([^/]+)\/?$/);
    const id = match ? match[1] : url.searchParams.get("id");

    if (!id) {
      return new Response(
        "<!doctype html><meta charset=utf-8><title>Dadliplug</title>" +
          "<body style='font-family:system-ui;padding:24px'>" +
          "<h1>Dadli<span style='color:#3cb043'>plug</span></h1>" +
          "<p>Plug Into Local.</p></body>",
        { headers: { "content-type": "text/html; charset=utf-8" } },
      );
    }
    if (!UUID.test(id)) {
      return new Response("Listing not found", { status: 404 });
    }

    const upstream = await fetch(`${ORIGIN}?id=${id}`, {
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
  },
};
