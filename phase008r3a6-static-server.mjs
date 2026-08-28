import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const base = path.resolve(root, "apps/ui-storybook/storybook-static");
const host = "127.0.0.1";
const port = 6006;

const mime = new Map([
  [".html","text/html; charset=utf-8"], [".js","text/javascript; charset=utf-8"],
  [".mjs","text/javascript; charset=utf-8"], [".css","text/css; charset=utf-8"],
  [".json","application/json; charset=utf-8"], [".svg","image/svg+xml"],
  [".png","image/png"], [".webp","image/webp"], [".ico","image/x-icon"],
  [".woff","font/woff"], [".woff2","font/woff2"]
]);

const server = http.createServer((req, res) => {
  try {
    const url = new URL(req.url ?? "/", `http://${host}:${port}`);
    let pathname = decodeURIComponent(url.pathname);
    if (pathname === "/") pathname = "/index.html";

    const requested = path.resolve(base, "." + pathname);
    if (requested !== base && !requested.startsWith(base + path.sep)) {
      res.writeHead(403); res.end("Forbidden"); return;
    }

    let file = requested;
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, "index.html");
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
      res.writeHead(404); res.end("Not found"); return;
    }

    res.writeHead(200, {
      "Content-Type": mime.get(path.extname(file).toLowerCase()) ?? "application/octet-stream",
      "Cache-Control": "no-store"
    });
    fs.createReadStream(file).pipe(res);
  } catch (error) {
    res.writeHead(500);
    res.end(String(error));
  }
});

server.listen(port, host, () => {
  console.log(`Storybook static server ready: http://${host}:${port}`);
});

const stop = () => server.close(() => process.exit(0));
process.on("SIGINT", stop);
process.on("SIGTERM", stop);
