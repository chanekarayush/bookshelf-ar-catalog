const http = require("http");

const page = `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Bookshelf AR Catalog</title><style>body{margin:0;background:#fff;color:#0a0a0a;font:16px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;display:grid;place-items:center;min-height:100vh}.card{max-width:460px;margin:24px;padding:30px;border:1px solid #e5e5e5;border-radius:22px;background:#f9f9f9}.badge{color:#2f95dc;font-size:12px;font-weight:700;letter-spacing:1.4px}h1{font-size:30px;line-height:1.12;margin:10px 0}p{color:#737373;line-height:1.55}code{display:block;margin-top:16px;padding:12px;border-radius:10px;background:#fff;font-size:13px;overflow:auto}</style><main class="card"><div class="badge">NATIVE IOS PROJECT</div><h1>Bookshelf AR Catalog</h1><p>This app is now a standalone SwiftUI project. Build it with Xcode on a physical iPhone 12 or newer; ARKit shelf mapping is not available in a browser preview.</p><code>ios/BookshelfARCatalog.xcodeproj</code></main></html>`;

const server = http.createServer((req, res) => {
  if (req.url === "/status") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ status: "ok", client: "native-swiftui" }));
    return;
  }
  res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
  res.end(page);
});

const port = Number(process.env.PORT || 3000);
server.listen(port, "0.0.0.0", () => {
  console.log(`Serving native iOS project status on port ${port}`);
});
