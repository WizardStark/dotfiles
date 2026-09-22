import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export type WorkflowMode = "guided" | "three-tier";

const CONFIG_DIR = join(homedir(), ".pi", "agent");
const CONFIG_FILE = join(CONFIG_DIR, "workflow-mode.json");
const DEFAULT_WORKFLOW_MODE: WorkflowMode = "guided";

function isWorkflowMode(value: unknown): value is WorkflowMode {
  return value === "guided" || value === "three-tier";
}

export async function readWorkflowMode(): Promise<WorkflowMode> {
  try {
    const raw = await readFile(CONFIG_FILE, "utf8");
    const parsed: unknown = JSON.parse(raw);
    if (
      parsed &&
      typeof parsed === "object" &&
      isWorkflowMode((parsed as { mode?: unknown }).mode)
    ) {
      return (parsed as { mode: WorkflowMode }).mode;
    }
  } catch {
    // A missing or malformed optional preference must not block Pi startup.
  }
  return DEFAULT_WORKFLOW_MODE;
}

export async function writeWorkflowMode(mode: WorkflowMode): Promise<void> {
  await mkdir(CONFIG_DIR, { recursive: true });
  await writeFile(CONFIG_FILE, `${JSON.stringify({ mode }, null, 2)}\n`, "utf8");
}
