import { createRequire } from "node:module";
import { readdirSync } from "node:fs";
import { resolve, join } from "node:path";
import { pathToFileURL } from "node:url";
import { packageDir } from "../tests/pi-test-helpers.mjs";

const require = createRequire(import.meta.url);
let compiler = process.env.PI_TEST_TYPESCRIPT_PATH;
if (!compiler) {
  try { compiler = require.resolve("typescript"); }
  catch { throw new Error("Set PI_TEST_TYPESCRIPT_PATH to a locally installed typescript.js; no compiler is installed in this repository."); }
}
const { default: ts } = await import(pathToFileURL(resolve(compiler)));
const nodeModules = resolve(packageDir, "../..");
const root = resolve("home/.pi/agent/extensions");
const files = ["", "lib", "statusline"].flatMap((dir) => readdirSync(join(root, dir))
  .filter((name) => name.endsWith(".ts")).map((name) => join(root, dir, name)));
const paths = Object.fromEntries(["pi-coding-agent", "pi-ai", "pi-agent-core", "pi-tui"].map((pkg) => [
  `@earendil-works/${pkg}`, [join(nodeModules, "@earendil-works", pkg, "dist/index.d.ts")],
]));
paths.typebox = [join(nodeModules, "typebox/build/index.d.mts")];
const program = ts.createProgram(files, {
  noEmit: true, strict: true, noUnusedLocals: true, noUnusedParameters: true,
  skipLibCheck: true, target: ts.ScriptTarget.ES2023,
  module: ts.ModuleKind.NodeNext, moduleResolution: ts.ModuleResolutionKind.NodeNext,
  allowImportingTsExtensions: true, baseUrl: nodeModules, paths,
  types: ["node"], typeRoots: [join(nodeModules, "@types")],
});
const diagnostics = ts.getPreEmitDiagnostics(program);
console.log(`TypeScript ${ts.version}: ${files.length} extension/helper files, ${diagnostics.length} diagnostics`);
for (const diagnostic of diagnostics) {
  const location = diagnostic.file?.getLineAndCharacterOfPosition(diagnostic.start ?? 0);
  const prefix = diagnostic.file ? `${diagnostic.file.fileName}:${location.line + 1}:${location.character + 1}` : "options";
  console.log(`${prefix} TS${diagnostic.code} ${ts.flattenDiagnosticMessageText(diagnostic.messageText, " ")}`);
}
process.exitCode = diagnostics.length ? 1 : 0;
