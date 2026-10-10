import { readdir, readFile } from "node:fs/promises";
import { extname, join, relative } from "node:path";

const roots = ["apps/mobile/lib", "apps/worker/src"];
const allowedPolicyFiles = new Set([
  "apps/mobile/lib/core/role_policy.dart",
  "apps/worker/src/role_policy.js",
]);
const extensions = new Set([".dart", ".js", ".mjs", ".ts"]);
const forbidden = /(?:['"`]\s*(?:host|agency|bd)\s*['"`]|RoomRole\.host|\b(?:agency|bd)[_-](?:target|commission|invite|manage)\b)/i;

async function walk(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const out = [];
  for (const entry of entries) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) out.push(...await walk(path));
    else out.push(path);
  }
  return out;
}

const violations = [];

for (const root of roots) {
  for (const file of await walk(root)) {
    const normalized = file.replaceAll("\\", "/");
    if (allowedPolicyFiles.has(normalized)) continue;
    if (!extensions.has(extname(file))) continue;

    const content = await readFile(file, "utf8");
    if (forbidden.test(content)) {
      violations.push(relative(".", file));
    }
  }
}

if (violations.length) {
  console.error("Legacy hierarchy references found:");
  for (const file of violations) console.error(" -", file);
  process.exit(1);
}

console.log("DarkVibeX legacy hierarchy check passed.");
