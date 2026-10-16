// Public listing pages: https://<worker>/l/<listing-id>
//
// The page itself is rendered by the Supabase Edge Function `listing`. Supabase
// serves function responses on its own domain as text/plain with nosniff, so a
// browser shows the HTML source instead of a page. This Worker fetches it and
// serves it as HTML, nothing more: no data of its own, no keys.

const ORIGIN =
  "https://ftenxsusyuiqatnvasny.supabase.co/functions/v1/listing";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default {
  async fetch(request) {
    const url = new URL(request.url);
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
