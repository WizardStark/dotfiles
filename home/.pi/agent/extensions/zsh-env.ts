import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createLocalBashOperations, isToolCallEventType } from "@earendil-works/pi-coding-agent";

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
  pi.on("tool_call", (event) => {
    if (!isToolCallEventType("bash", event)) return;

    const command = event.input.command;
    if (typeof command !== "string" || command.trim() === "") return;

    // Avoid double-wrapping if a command has already been routed through zsh.
    if (/^\s*zsh\s+(-[^\s]*\b)?i?l?c\s+/.test(command)) return;

    event.input.command = runViaZsh(command);
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
