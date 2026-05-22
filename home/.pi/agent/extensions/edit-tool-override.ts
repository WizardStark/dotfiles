import { realpathSync } from "node:fs";
import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";
import { createEditToolDefinition, getLanguageFromPath, highlightCode } from "@earendil-works/pi-coding-agent";

type EditBlock = {
  oldText: string;
  newText: string;
};

type RenderableEditArgs = {
  path?: string;
  file_path?: string;
  edits?: EditBlock[];
  oldText?: string;
  newText?: string;
};

type EditPreview =
  | {
      diff: string;
      firstChangedLine?: number;
    }
  | {
      error: string;
    };

type EditCallRenderComponent = any & {
  preview?: EditPreview;
  previewArgsKey?: string;
  previewPending?: boolean;
  settledError?: boolean;
};

type EditRenderState = {
  callComponent?: EditCallRenderComponent;
};

type DiffSide = {
  text: string;
  bgToken?: "toolErrorBg" | "toolSuccessBg";
};

type RuntimeModules = {
  createEditToolDefinition: (cwd: string) => any;
  getLanguageFromPath: (filePath: string) => string | undefined;
  highlightCode: (code: string, lang?: string) => string[];
  Box?: any;
  Container?: any;
  Spacer?: any;
  Text?: any;
  computeEditsDiff?: (
    path: string,
    edits: EditBlock[],
    cwd: string,
  ) => Promise<{ diff: string; firstChangedLine?: number } | { error: string }>;
};

let runtimePromise: Promise<RuntimeModules> | undefined;

function npmRoot(): string {
  return execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
}

function resolveCliAgentRoot(pathValue: string | undefined): string | undefined {
  if (typeof pathValue !== "string" || !pathValue) {
    return undefined;
  }

  try {
    const resolvedPath = realpathSync(pathValue);
    if (resolvedPath.endsWith("/dist/cli.js")) {
      return dirname(dirname(resolvedPath));
    }
  } catch {
    if (pathValue.endsWith("/dist/cli.js")) {
      return dirname(dirname(pathValue));
    }
  }

  return undefined;
}

function getAgentRoot(): string {
  try {
    const localRequire = createRequire(import.meta.url);
    const packageJsonPath = localRequire.resolve("@earendil-works/pi-coding-agent/package.json");
    return dirname(packageJsonPath);
  } catch {
    // fall through to runtime-specific heuristics
  }

  const argvAgentRoot = resolveCliAgentRoot(process.argv[1]);
  if (argvAgentRoot) {
    return argvAgentRoot;
  }

  const execArgvAgentRoot = process.execArgv
    .map((value) => resolveCliAgentRoot(value))
    .find((value): value is string => typeof value === "string");
  if (execArgvAgentRoot) {
    return execArgvAgentRoot;
  }

  const root = npmRoot();
  return join(root, "@earendil-works", "pi-coding-agent");
}

async function loadRuntime(): Promise<RuntimeModules> {
  if (runtimePromise) {
    return runtimePromise;
  }

  runtimePromise = (async () => {
    const agentRoot = getAgentRoot();
    const requireFromAgent = createRequire(join(agentRoot, "package.json"));

    let tui: any;
    try {
      const tuiEntry = requireFromAgent.resolve("@earendil-works/pi-tui");
      tui = await import(pathToFileURL(tuiEntry).href);
    } catch {
      tui = undefined;
    }

    let computeEditsDiff: RuntimeModules["computeEditsDiff"];
    try {
      const editDiffEntry = requireFromAgent.resolve("./dist/core/tools/edit-diff.js");
      const editDiff = await import(pathToFileURL(editDiffEntry).href);
      computeEditsDiff = editDiff.computeEditsDiff;
    } catch {
      computeEditsDiff = undefined;
    }

    return {
      createEditToolDefinition,
      getLanguageFromPath,
      highlightCode,
      Box: tui?.Box,
      Container: tui?.Container,
      Spacer: tui?.Spacer,
      Text: tui?.Text,
      computeEditsDiff,
    } satisfies RuntimeModules;
  })();

  return runtimePromise;
}

function trim(text: string | undefined | null): string {
  return typeof text === "string" ? text.trim() : "";
}

function shortenPath(pathValue: string): string {
  const home = process.env.HOME;
  if (home && pathValue.startsWith(`${home}/`)) {
    return `~/${pathValue.slice(home.length + 1)}`;
  }
  return pathValue;
}

function getRenderablePreviewInput(args: RenderableEditArgs | undefined): { path: string; edits: EditBlock[] } | null {
  if (!args) return null;

  const path = typeof args.path === "string" ? args.path : typeof args.file_path === "string" ? args.file_path : null;
  if (!path) return null;

  if (
    Array.isArray(args.edits) &&
    args.edits.length > 0 &&
    args.edits.every((edit) => typeof edit?.oldText === "string" && typeof edit?.newText === "string")
  ) {
    return { path, edits: args.edits };
  }

  if (typeof args.oldText === "string" && typeof args.newText === "string") {
    return { path, edits: [{ oldText: args.oldText, newText: args.newText }] };
  }

  return null;
}

function formatEditCall(args: RenderableEditArgs | undefined, theme: any): string {
  const rawPath = args?.file_path ?? args?.path;
  if (typeof rawPath !== "string") {
    return `${theme.fg("toolTitle", theme.bold("edit"))} ${theme.fg("error", "<invalid path>")}`;
  }

  const pathDisplay = trim(rawPath) ? theme.fg("accent", shortenPath(rawPath)) : theme.fg("toolOutput", "...");
  return `${theme.fg("toolTitle", theme.bold("edit"))} ${pathDisplay}`;
}

function getEditHeaderBg(preview: EditPreview | undefined, settledError: boolean | undefined, theme: any) {
  if (preview && "error" in preview) {
    return (text: string) => theme.bg("toolErrorBg", text);
  }
  if (settledError) {
    return (text: string) => theme.bg("toolErrorBg", text);
  }
  return (text: string) => text;
}

function setEditPreview(component: EditCallRenderComponent, preview: EditPreview, argsKey: string | undefined): boolean {
  const current = component.preview;
  const changed =
    current === undefined ||
    ("error" in current && "error" in preview
      ? current.error !== preview.error
      : "error" in current !== "error" in preview) ||
    (!("error" in current) &&
      !("error" in preview) &&
      (current.diff !== preview.diff || current.firstChangedLine !== preview.firstChangedLine));

  component.preview = preview;
  component.previewArgsKey = argsKey;
  component.previewPending = false;
  return changed;
}

function parseDiffLine(line: string) {
  const match = line.match(/^([+-\s])(\s*\d*)\s(.*)$/);
  if (!match) return null;
  return { prefix: match[1], lineNum: match[2], content: match[3] };
}

function replaceTabs(text: string): string {
  return text.replace(/\t/g, "   ");
}

function stripAnsi(text: string): string {
  return text.replace(/\x1b\[[0-9;]*m/g, "");
}

function padRight(text: string, width: number): string {
  const visible = stripAnsi(text).length;
  return text + " ".repeat(Math.max(0, width - visible));
}

function truncate(text: string, width: number): string {
  if (text.length <= width) return text;
  if (width <= 1) return "…";
  return `${text.slice(0, width - 1)}…`;
}

function formatLinePrefix(lineNum: string): string {
  return lineNum ? `${lineNum} │ ` : "    │ ";
}

function highlightDiffContent(
  theme: any,
  highlightCode: RuntimeModules["highlightCode"],
  content: string,
  lang: string | undefined,
  colorToken: "toolDiffRemoved" | "toolDiffAdded" | "toolDiffContext",
): string {
  if (!content) {
    return "";
  }
  if (!lang) {
    return theme.fg(colorToken, content);
  }
  try {
    return highlightCode(content, lang)[0] ?? content;
  } catch {
    return theme.fg(colorToken, content);
  }
}

function formatCell(
  theme: any,
  highlightCode: RuntimeModules["highlightCode"],
  lineNum: string,
  content: string,
  width: number,
  colorToken: "toolDiffRemoved" | "toolDiffAdded" | "toolDiffContext",
  lang?: string,
): string {
  const prefix = formatLinePrefix(lineNum);
  const contentWidth = Math.max(0, width - prefix.length);
  const visibleContent = truncate(replaceTabs(content), contentWidth);
  return theme.fg(colorToken, prefix) + highlightDiffContent(theme, highlightCode, visibleContent, lang, colorToken);
}

function paintCell(theme: any, text: string, width: number, bgToken?: DiffSide["bgToken"]): string {
  const visible = stripAnsi(text).length;
  const padding = " ".repeat(Math.max(0, width - visible));
  if (!bgToken) {
    return text + padding;
  }
  return theme.bg(bgToken, text) + padding;
}

function paintContent(theme: any, text: string, bgToken?: DiffSide["bgToken"]): string {
  if (!bgToken) {
    return text;
  }
  return theme.bg(bgToken, text);
}

function renderRow(theme: any, left: DiffSide, right: DiffSide, width: number): string {
  const separator = theme.fg("toolDiffContext", " │ ");
  return `${paintCell(theme, left.text, width, left.bgToken)}${separator}${paintContent(theme, right.text, right.bgToken)}`;
}

function emptySide(theme: any, highlightCode: RuntimeModules["highlightCode"], width: number): DiffSide {
  return { text: theme.fg("toolDiffContext", formatCell(theme, highlightCode, "", "", width, "toolDiffContext")) };
}

function side(
  theme: any,
  highlightCode: RuntimeModules["highlightCode"],
  prefix: string,
  lineNum: string,
  content: string,
  width: number,
  lang?: string,
): DiffSide {
  const colorToken = prefix === "-" ? "toolDiffRemoved" : prefix === "+" ? "toolDiffAdded" : "toolDiffContext";
  const bgToken = prefix === "-" ? "toolErrorBg" : prefix === "+" ? "toolSuccessBg" : undefined;
  return { text: formatCell(theme, highlightCode, lineNum, content, width, colorToken, lang), bgToken };
}

function getTmuxPaneWidth(): number | undefined {
  const tmuxPane = process.env.TMUX_PANE;
  if (!tmuxPane) return undefined;

  try {
    const output = execFileSync("tmux", ["display-message", "-p", "-t", tmuxPane, "#{pane_width}"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    const width = Number.parseInt(output, 10);
    return Number.isFinite(width) && width > 0 ? width : undefined;
  } catch {
    return undefined;
  }
}

function resolveRenderWidth(): number {
  const explicitColumns = Number.parseInt(process.env.COLUMNS ?? "", 10);
  const stdoutColumns = process.stdout.columns;
  const tmuxPaneWidth = getTmuxPaneWidth();

  if (Number.isFinite(tmuxPaneWidth) && tmuxPaneWidth > 0) {
    if (Number.isFinite(stdoutColumns) && stdoutColumns > 0) {
      return Math.min(stdoutColumns, tmuxPaneWidth);
    }
    return tmuxPaneWidth;
  }
  if (Number.isFinite(stdoutColumns) && stdoutColumns > 0) {
    return stdoutColumns;
  }
  if (Number.isFinite(explicitColumns) && explicitColumns > 0) {
    return explicitColumns;
  }
  return 160;
}

export function renderDeltaLikeDiff(
  diffText: string,
  theme: any,
  runtime: Pick<RuntimeModules, "getLanguageFromPath" | "highlightCode">,
  options: { filePath?: string; columnWidth?: number } = {},
): string {
  const { getLanguageFromPath, highlightCode } = runtime;
  const lang = options.filePath ? getLanguageFromPath(options.filePath) : undefined;
  const terminalWidth = resolveRenderWidth();
  const columnWidth = Math.max(32, options.columnWidth ?? Math.floor((terminalWidth - 4) / 2));
  const lines = diffText.split("\n");
  const result: string[] = [];

  result.push(
    renderRow(
      theme,
      { text: theme.fg("toolDiffRemoved", padRight("old", columnWidth)) },
      { text: theme.fg("toolDiffAdded", "new") },
      columnWidth,
    ),
  );
  result.push(theme.fg("toolDiffContext", `${"─".repeat(columnWidth)}─┼─${"─".repeat(columnWidth)}`));

  let i = 0;
  while (i < lines.length) {
    const parsed = parseDiffLine(lines[i]);
    if (!parsed) {
      result.push(theme.fg("toolDiffContext", lines[i]));
      i++;
      continue;
    }

    if (parsed.prefix === "-") {
      const removed: Array<ReturnType<typeof parseDiffLine>> = [];
      while (i < lines.length) {
        const entry = parseDiffLine(lines[i]);
        if (!entry || entry.prefix !== "-") break;
        removed.push(entry);
        i++;
      }

      const added: Array<ReturnType<typeof parseDiffLine>> = [];
      while (i < lines.length) {
        const entry = parseDiffLine(lines[i]);
        if (!entry || entry.prefix !== "+") break;
        added.push(entry);
        i++;
      }

      const count = Math.max(removed.length, added.length);
      for (let j = 0; j < count; j++) {
        const left = removed[j]
          ? side(theme, highlightCode, "-", removed[j]!.lineNum, removed[j]!.content, columnWidth, lang)
          : emptySide(theme, highlightCode, columnWidth);
        const right = added[j]
          ? side(theme, highlightCode, "+", added[j]!.lineNum, added[j]!.content, columnWidth, lang)
          : emptySide(theme, highlightCode, columnWidth);
        result.push(renderRow(theme, left, right, columnWidth));
      }
      continue;
    }

    if (parsed.prefix === "+") {
      result.push(
        renderRow(
          theme,
          emptySide(theme, highlightCode, columnWidth),
          side(theme, highlightCode, "+", parsed.lineNum, parsed.content, columnWidth, lang),
          columnWidth,
        ),
      );
      i++;
      continue;
    }

    const context = side(theme, highlightCode, " ", parsed.lineNum, parsed.content, columnWidth, lang);
    result.push(renderRow(theme, context, context, columnWidth));
    i++;
  }

  return result.join("\n");
}

function buildEditCallComponent(
  component: EditCallRenderComponent,
  args: RenderableEditArgs | undefined,
  theme: any,
  Text: any,
  Spacer: any,
  runtime: Pick<RuntimeModules, "getLanguageFromPath" | "highlightCode">,
): EditCallRenderComponent {
  const rawPath = typeof args?.file_path === "string" ? args.file_path : args?.path;
  component.setBgFn(getEditHeaderBg(component.preview, component.settledError, theme));
  component.clear();
  component.addChild(new Text(formatEditCall(args, theme), 0, 0));

  if (!component.preview) {
    return component;
  }

  const body =
    "error" in component.preview
      ? theme.fg("error", component.preview.error)
      : renderDeltaLikeDiff(component.preview.diff, theme, runtime, { filePath: rawPath ?? undefined });

  component.addChild(new Spacer(1));
  component.addChild(new Text(body, 0, 0));
  return component;
}

function formatEditResult(
  args: RenderableEditArgs | undefined,
  preview: EditPreview | undefined,
  result: any,
  theme: any,
  isError: boolean,
  runtime: Pick<RuntimeModules, "getLanguageFromPath" | "highlightCode">,
): string | undefined {
  const rawPath = typeof args?.file_path === "string" ? args.file_path : args?.path;
  const previewDiff = preview && !("error" in preview) ? preview.diff : undefined;
  const previewError = preview && "error" in preview ? preview.error : undefined;

  if (isError) {
    const errorText = result.content
      .filter((item: any) => item.type === "text")
      .map((item: any) => item.text || "")
      .join("\n");
    if (!errorText || errorText === previewError) {
      return undefined;
    }
    return theme.fg("error", errorText);
  }

  const resultDiff = result.details?.diff;
  if (resultDiff && resultDiff !== previewDiff) {
    return renderDeltaLikeDiff(resultDiff, theme, runtime, { filePath: rawPath ?? undefined });
  }

  return undefined;
}

export default async function (pi: any) {
  const { createEditToolDefinition, getLanguageFromPath, highlightCode, Box, Container, Spacer, Text, computeEditsDiff } = await loadRuntime();
  const diffRuntime = { getLanguageFromPath, highlightCode };
  const base = createEditToolDefinition(process.cwd());

  if (!Box || !Container || !Spacer || !Text) {
    pi.registerTool(base);
    return;
  }

  function getEditCallRenderComponent(state: EditRenderState, lastComponent: unknown): EditCallRenderComponent {
    if (lastComponent instanceof Box) {
      const component = lastComponent as EditCallRenderComponent;
      state.callComponent = component;
      return component;
    }
    if (state.callComponent) {
      return state.callComponent;
    }
    const component = Object.assign(new Box(1, 1, (text: string) => text), {
      preview: undefined as EditPreview | undefined,
      previewArgsKey: undefined as string | undefined,
      previewPending: false,
      settledError: false,
    });
    state.callComponent = component;
    return component;
  }

  pi.registerTool({
    ...base,
    name: "edit",
    label: "edit",
    renderShell: "self",
    async execute(toolCallId: string, params: any, signal: AbortSignal | undefined, onUpdate: any, ctx: any) {
      return base.execute(toolCallId, params, signal, onUpdate, ctx);
    },
    renderCall(args: any, theme: any, context: any) {
      const component = getEditCallRenderComponent(context.state, context.lastComponent);
      const previewInput = getRenderablePreviewInput(args as RenderableEditArgs | undefined);
      const argsKey = previewInput ? JSON.stringify({ path: previewInput.path, edits: previewInput.edits }) : undefined;

      if (component.previewArgsKey !== argsKey) {
        component.preview = undefined;
        component.previewArgsKey = argsKey;
        component.previewPending = false;
        component.settledError = false;
      }

      if (context.argsComplete && previewInput && computeEditsDiff && !component.preview && !component.previewPending) {
        component.previewPending = true;
        const requestKey = argsKey;
        void computeEditsDiff(previewInput.path, previewInput.edits, context.cwd)
          .then((preview: EditPreview) => {
            if (component.previewArgsKey === requestKey) {
              setEditPreview(component, preview, requestKey);
              context.invalidate();
            }
          })
          .catch((error: unknown) => {
            if (component.previewArgsKey === requestKey) {
              const message = error instanceof Error ? error.message : String(error);
              setEditPreview(component, { error: message }, requestKey);
              context.invalidate();
            }
          });
      }

      return buildEditCallComponent(component, args as RenderableEditArgs | undefined, theme, Text, Spacer, diffRuntime);
    },
    renderResult(result: any, _options: any, theme: any, context: any) {
      const callComponent = context.state.callComponent as EditCallRenderComponent | undefined;
      const previewInput = getRenderablePreviewInput(context.args as RenderableEditArgs | undefined);
      const argsKey = previewInput ? JSON.stringify({ path: previewInput.path, edits: previewInput.edits }) : undefined;
      const resultDiff = !context.isError ? result.details?.diff : undefined;
      let changed = false;

      if (callComponent) {
        if (typeof resultDiff === "string") {
          changed =
            setEditPreview(
              callComponent,
              { diff: resultDiff, firstChangedLine: result.details?.firstChangedLine },
              argsKey,
            ) || changed;
        }
        if (callComponent.settledError !== context.isError) {
          callComponent.settledError = context.isError;
          changed = true;
        }
        if (changed) {
          buildEditCallComponent(callComponent, context.args as RenderableEditArgs | undefined, theme, Text, Spacer, diffRuntime);
        }
      }

      const output = formatEditResult(
        context.args as RenderableEditArgs | undefined,
        callComponent?.preview,
        result,
        theme,
        context.isError,
        diffRuntime,
      );
      const component = (context.lastComponent as any) ?? new Container();
      component.clear();
      if (!output) {
        return component;
      }
      component.addChild(new Spacer(1));
      component.addChild(new Text(output, 1, 0));
      return component;
    },
  });
}
