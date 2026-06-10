import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

const DEFAULT_CTX_EXECUTE_TIMEOUT_MS = 30_000;

const BASH_ALLOWLIST: RegExp[] = [
  /^\s*(mkdir|mv|cp|rm|touch|chmod)\b/i,
  /^\s*git\s+(add|commit|push|checkout|branch|merge)\b/i,
  /^\s*(cd|pwd|which)\b/i,
  /^\s*(kill|pkill)\b/i,
  /^\s*(npm|pnpm|yarn|bun)\s+(install|add|publish)\b/i,
  /^\s*(pip|pip3)\s+install\b/i,
  /^\s*uv\s+pip\s+install\b/i,
  /^\s*(echo|printf)\b/i,
];

const BASH_INSPECTION_PATTERNS: RegExp[] = [
  /(^|\s)(ls|find|rg|grep|cat|head|tail|wc|du|df|stat)\b/i,
  /\bgit\s+(status|log|diff|show|grep|blame)\b/i,
  /\b(pytest|go\s+test|cargo\s+test|npm\s+test|pnpm\s+test|yarn\s+test|vitest|jest)\b/i,
  /\b(docker\s+(ps|images|logs|inspect|stats)|kubectl\s+(get|describe|logs))\b/i,
  /\b(curl|gh|aws|gcloud|oci|terraform|flyctl|heroku|wrangler)\b/i,
  /\bfirebase\s+deploy\b/i,
];

function isAllowedBash(command: string): boolean {
  return BASH_ALLOWLIST.some((pattern) => pattern.test(command));
}

function isInspectionBash(command: string): boolean {
  return BASH_INSPECTION_PATTERNS.some((pattern) => pattern.test(command));
}

export default function contextModeDefaults(pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    const extra = `

## Local Tooling Policy

- Default \`ctx_execute\` calls to a 30000ms timeout unless a longer or shorter timeout is clearly justified.
- Use \`ctx_execute\`, \`ctx_batch_execute\`, or \`ctx_execute_file\` for inspection, searches, git history/diffs, logs, tests, deploy output, and other analysis work.
- Use \`ctx_batch_execute\` when 3 or more related inspection commands are likely.
- Use \`ctx_execute_file\` for logs, JSON, CSV, test output, generated files, and other file-analysis tasks.
- Use \`read\` only when exact file text is needed for editing or for a small targeted excerpt.
- If the goal is understanding, summarizing, counting, searching, comparing, or extracting patterns from a file, prefer \`ctx_execute_file\` over \`read\`.
- Use \`bash\` only for safe mutations/navigation such as file moves, git writes, package installs, process control, \`pwd\`, \`which\`, \`echo\`, and \`printf\`.
- If a bash command is mainly reading, listing, searching, diffing, or inspecting, do not use \`bash\`; use the context-mode tools instead.
- When using \`ctx_search\`, batch all likely follow-up questions into a single \`queries\` array and pass \`source\` unless cross-source search is explicitly desired.
- Prefer \`ctx_index(path: ...)\` over \`ctx_index(content: ...)\` for non-trivial content.
- Prefer derived summaries over raw dumps; return the conclusion, key evidence, and file paths instead of large quoted output.
`;

    return {
      systemPrompt: `${event.systemPrompt}${extra}`,
    };
  });

  pi.on("tool_call", async (event) => {
    if (
      event.toolName === "ctx_execute" &&
      event.input &&
      typeof event.input === "object"
    ) {
      const input = event.input as { timeout?: unknown };
      if (input.timeout === undefined || input.timeout === null) {
        input.timeout = DEFAULT_CTX_EXECUTE_TIMEOUT_MS;
      }
      return;
    }

    if (!isToolCallEventType("bash", event)) return;

    const command = event.input.command;
    if (typeof command !== "string" || command.trim() === "") return;
    if (isAllowedBash(command)) return;
    if (!isInspectionBash(command)) return;

    return {
      block: true,
      reason:
        "Use context-mode tools instead of bash for inspection/analysis commands. Prefer ctx_execute, ctx_batch_execute, or ctx_execute_file; keep bash for safe mutations and small navigation commands.",
    };
  });
}
