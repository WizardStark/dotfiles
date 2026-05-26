import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { basename, resolve } from "node:path";

const DOTENV_NAME = /^\.env(?:\..+)?$/;
const ALLOWED_DOTENV_NAMES = new Set([".env.example"]);
const DOTENV_REFERENCE = /(^|[\s'"`=:/\\])(\.env(?:\.[A-Za-z0-9._-]+)?)(?=$|[\s'"`:/\\])/g;
const BLOCK_REASON =
  'Reading .env files is blocked by the block-dotenv-read extension. Ask the user for the needed value instead of opening the file.';

function stripPathPrefix(value: string): string {
  return value.replace(/^@+/, "").trim();
}

function isBlockedDotenvName(name: string): boolean {
  return DOTENV_NAME.test(name) && !ALLOWED_DOTENV_NAMES.has(name);
}

function isBlockedDotenvPath(pathValue: unknown, cwd: string): boolean {
  if (typeof pathValue !== "string") return false;

  const candidate = stripPathPrefix(pathValue);
  if (!candidate) return false;

  const resolved = resolve(cwd, candidate);
  return isBlockedDotenvName(basename(resolved));
}

function mentionsBlockedDotenv(command: unknown): boolean {
  if (typeof command !== "string") return false;

  for (const match of command.matchAll(DOTENV_REFERENCE)) {
    const name = match[2];
    if (name && isBlockedDotenvName(name)) {
      return true;
    }
  }

  return false;
}

function blockResult(reason: string) {
  return { block: true as const, reason };
}

export default function blockDotenvRead(pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    const extra = `

## Secret file guard

- Never read \`.env\` or secret-bearing \`.env.*\` files. \`.env.example\` is allowed as a template.
- If a task appears to require a secret from a dotenv file, ask the user for the specific value or a redacted substitute.
- Do not use shell, read, or context-mode tools to inspect blocked dotenv files.
`;

    return {
      systemPrompt: `${event.systemPrompt}${extra}`,
    };
  });

  pi.on("tool_call", async (event, ctx) => {
    if (isToolCallEventType("read", event) && isBlockedDotenvPath(event.input.path, ctx.cwd)) {
      return blockResult(BLOCK_REASON);
    }

    if (event.toolName === "ctx_execute_file") {
      const input = event.input as { path?: unknown };
      if (isBlockedDotenvPath(input.path, ctx.cwd)) {
        return blockResult(BLOCK_REASON);
      }
      return;
    }

    if (isToolCallEventType("bash", event) && mentionsBlockedDotenv(event.input.command)) {
      return blockResult(BLOCK_REASON);
    }

    if (event.toolName === "ctx_execute") {
      const input = event.input as { code?: unknown };
      if (mentionsBlockedDotenv(input.code)) {
        return blockResult(BLOCK_REASON);
      }
      return;
    }

    if (event.toolName === "ctx_batch_execute") {
      const input = event.input as { commands?: Array<{ command?: unknown }> };
      if (Array.isArray(input.commands) && input.commands.some((command) => mentionsBlockedDotenv(command.command))) {
        return blockResult(BLOCK_REASON);
      }
    }
  });

  pi.on("user_bash", (event) => {
    if (!mentionsBlockedDotenv(event.command)) return;

    return {
      result: {
        output: BLOCK_REASON,
        exitCode: 1,
        cancelled: false,
        truncated: false,
      },
    };
  });
}
