import { createBashTool, createLocalBashOperations, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { compactCall, compactResult } from "./lib/compact-tool-renderers.ts";

function shellQuote(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

function runViaZsh(command: string): string {
  // Use a non-interactive login zsh. `-i` breaks in Pi's non-TTY command runner
  // for interactive-only plugins such as powerlevel10k/gitstatus/zle widgets.
  // OVERRIDE_ZSH_CUSTOMIZATION tells this dotfiles zsh setup to skip interactive
  // prompt/plugin setup from ~/.zshenv while still loading PATH/env setup such as
  // Homebrew, mise, ~/.lcl.zshenv, ~/.zprofile, etc.
  //
  // Because that guard also skips ~/.zshrc's zoxide setup, explicitly install the
  // zoxide `cd` wrapper before running the command so `cd dot`, `cd cent`, etc.
  // behave like they do in an interactive shell.
  const prelude = `if (( $+commands[zoxide] )); then eval "$(zoxide init --cmd cd zsh)"; fi`;
  return `OVERRIDE_ZSH_CUSTOMIZATION=1 zsh -lc ${shellQuote(`${prelude}; ${command}`)}`;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const base = createBashTool(ctx.cwd, {
      spawnHook: ({ command, cwd, env }) => ({
        command: runViaZsh(command),
        cwd,
        env,
      }),
    });

    pi.registerTool({
      ...base,
      name: "bash",
      renderShell: "self",
      // Preserve outputSchema, structuredContent, isError, and truncated output.
      async execute(toolCallId, params, signal, onUpdate, toolCtx) {
        return base.execute(toolCallId, params, signal, onUpdate, toolCtx);
      },
      renderCall(_args, theme, context) {
        return compactCall("bash", theme, context);
      },
      renderResult: compactResult,
    });
  });

  pi.on("user_bash", () => {
    const local = createLocalBashOperations();

    return {
      operations: {
        exec(command, cwd, options) {
          return local.exec(runViaZsh(command), cwd, options);
        },
      },
    };
  });
}
