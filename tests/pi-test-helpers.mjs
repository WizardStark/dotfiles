import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export function installedPiPackage() {
  if (process.env.PI_TEST_PACKAGE_DIR) return resolve(process.env.PI_TEST_PACKAGE_DIR);
  const binary = realpathSync(execFileSync("which", ["pi"], { encoding: "utf8" }).trim());
  for (const root of [process.env.PI_MANAGED_INSTALL_ROOT, resolve(dirname(binary), "../install")].filter(Boolean)) {
    const versionFile = join(root, "current-version");
    if (existsSync(versionFile)) {
      const version = readFileSync(versionFile, "utf8").trim();
      if (!/^[A-Za-z0-9._+-]+$/.test(version)) throw new Error("Invalid managed Pi version");
      return join(root, "releases", version, "node_modules/@earendil-works/pi-coding-agent");
    }
  }
  for (let directory = dirname(binary); directory !== dirname(directory); directory = dirname(directory)) {
    const metadata = join(directory, "package.json");
    if (existsSync(metadata) && JSON.parse(readFileSync(metadata, "utf8")).name === "@earendil-works/pi-coding-agent") return directory;
  }
  throw new Error("Cannot resolve installed Pi package; set PI_TEST_PACKAGE_DIR");
}

export const packageDir = installedPiPackage();
const nodeModules = resolve(packageDir, "../..");
const { createJiti } = await import(pathToFileURL(join(nodeModules, "jiti/lib/jiti.mjs")));
const jiti = createJiti(import.meta.url, { alias: {
  "@earendil-works/pi-coding-agent": join(packageDir, "dist/index.js"),
  "@earendil-works/pi-tui": join(nodeModules, "@earendil-works/pi-tui/dist/index.js"),
  "@earendil-works/pi-agent-core": join(nodeModules, "@earendil-works/pi-agent-core/dist/index.js"),
  "@earendil-works/pi-ai": join(nodeModules, "@earendil-works/pi-ai/dist/compat.js"),
  typebox: join(nodeModules, "typebox/build/index.mjs"),
} });
export const importExtension = (file) => jiti.import(resolve("home/.pi/agent/extensions", file));
export const piSdk = () => import(pathToFileURL(join(packageDir, "dist/index.js")));
export const tuiSdk = () => import(pathToFileURL(join(nodeModules, "@earendil-works/pi-tui/dist/index.js")));

export function mockApi() {
  const handlers = new Map(), tools = new Map(), commands = new Map(), renderers = [], messages = [], entries = [];
  let active = ["read", "bash", "edit", "write"];
  return {
    handlers, tools, commands, renderers, messages, entries,
    on(name, handler) { const list = handlers.get(name) ?? []; list.push(handler); handlers.set(name, list); },
    async emit(name, event = {}, ctx = {}) { let result; for (const handler of handlers.get(name) ?? []) { const value = await handler({ type: name, ...event }, ctx); if (value !== undefined) result = value; if (value?.block) break; } return result; },
    registerTool(tool) { tools.set(tool.name, tool); active.push(tool.name); },
    registerToolRenderer(renderer) { renderers.push(renderer); },
    registerCommand(name, command) { commands.set(name, command); },
    registerShortcut() {}, registerMessageRenderer() {}, registerEntryRenderer() {},
    getThinkingLevel: () => "high",
    getAllTools: () => [...tools.values()], getActiveTools: () => active,
    setActiveTools: (names) => { active = names; },
    appendEntry: (type, data) => entries.push({ type, data }),
    sendMessage: (message) => messages.push(message), getSessionName: () => "Test session",
    events: { on() {}, emit() {} },
  };
}

export function theme(prefix = "") {
  return {
    fg: (_tone, text) => `${prefix}${text}`, bg: (_tone, text) => text,
    style: (text) => `${prefix}${text}`, bold: (text) => text,
  };
}
export function renderContext(overrides = {}) {
  return { args: {}, toolCallId: "call-1", invalidate() {}, lastComponent: undefined,
    state: {}, cwd: process.cwd(), executionStarted: true, argsComplete: true,
    isPartial: false, expanded: false, showImages: false, isError: false,
    durationMs: undefined, outputPad: 0, ...overrides };
}
