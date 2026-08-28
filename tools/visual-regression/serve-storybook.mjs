import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const currentFile =
  fileURLToPath(
    import.meta.url
  );

const currentDir =
  path.dirname(
    currentFile
  );

const repoRoot =
  path.resolve(
    currentDir,
    "..",
    ".."
  );

const root =
  path.join(
    repoRoot,
    "apps",
    "ui-storybook",
    "storybook-static"
  );

const port =
  Number(
    process.env.STORYBOOK_TEST_PORT ??
    6106
  );

const mime =
  new Map([
    [".html", "text/html; charset=utf-8"],
    [".js", "text/javascript; charset=utf-8"],
    [".mjs", "text/javascript; charset=utf-8"],
    [".css", "text/css; charset=utf-8"],
    [".json", "application/json; charset=utf-8"],
    [".svg", "image/svg+xml"],
    [".png", "image/png"],
    [".jpg", "image/jpeg"],
    [".jpeg", "image/jpeg"],
    [".webp", "image/webp"],
    [".woff2", "font/woff2"]
  ]);

if (
  !fs.existsSync(
    root
  )
) {
  console.error(
    `Storybook static build is missing: ${root}`
  );

  process.exit(1);
}

function resolveSafe(
  requestPath
) {
  const raw =
    decodeURIComponent(
      requestPath.split("?")[0]
    );

  const requested =
    raw === "/"
      ? "/index.html"
      : raw;

  const resolved =
    path.resolve(
      root,
      "." + requested
    );

  const normalisedRoot =
    path.resolve(
      root
    );

  if (
    resolved !== normalisedRoot &&
    !resolved.startsWith(
      normalisedRoot +
      path.sep
    )
  ) {
    return null;
  }

  return resolved;
}

const server =
  http.createServer(
    (
      request,
      response
    ) => {
      const resolved =
        resolveSafe(
          request.url ??
          "/"
        );

      if (!resolved) {
        response.writeHead(403);
        response.end("Forbidden");
        return;
      }

      let file =
        resolved;

      if (
        fs.existsSync(file) &&
        fs.statSync(file).isDirectory()
      ) {
        file =
          path.join(
            file,
            "index.html"
          );
      }

      if (
        !fs.existsSync(
          file
        )
      ) {
        response.writeHead(404);
        response.end("Not found");
        return;
      }

      response.setHeader(
        "Cache-Control",
        "no-store"
      );

      response.setHeader(
        "Content-Type",
        mime.get(
          path.extname(
            file
          ).toLowerCase()
        ) ??
        "application/octet-stream"
      );

      fs.createReadStream(
        file
      ).pipe(
        response
      );
    }
  );

server.listen(
  port,
  "127.0.0.1",
  () => {
    console.log(
      `Storybook test server: http://127.0.0.1:${port}`
    );

    console.log(
      `Serving: ${root}`
    );
  }
);
