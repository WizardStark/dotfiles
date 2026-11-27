import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { ThinkingLevel } from "@earendil-works/pi-agent-core";
import type { ModelRef } from "./model-ref.ts";
import { isSecretPath } from "./secret-paths.ts";

export type DelegationModelPreference = {
  model: ModelRef | null;
  thinkingLevel?: ThinkingLevel;
};

type Role = "worker" | "scout";
type Config = Partial<Record<Role, DelegationModelPreference>>;
export const DELEGATION_THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parsePreference(entry: unknown): DelegationModelPreference | undefined {
  if (!isObject(entry)) return undefined;
  const model = entry.model;
  const thinkingLevel = DELEGATION_THINKING_LEVELS.find((level) => level === entry.thinkingLevel);
  if (model === null) return { model, thinkingLevel };
  if (!isObject(model) || typeof model.provider !== "string" || !model.provider.trim()
      || typeof model.id !== "string" || !model.id.trim()) return undefined;
  return { model: { provider: model.provider.trim(), id: model.id.trim() }, thinkingLevel };
}

async function configPath(): Promise<string> {
  const path = join(getAgentDir(), "delegation-models.json");
  if (await isSecretPath(path)) throw new Error("Refusing to access secret delegation model config path");
  return path;
}

async function readConfig(path: string): Promise<Record<string, unknown>> {
  try {
    const parsed: unknown = JSON.parse(await readFile(path, "utf8"));
    if (!isObject(parsed)) throw new Error("Delegation model config must be a JSON object");
    return parsed;
  } catch (error) {
    if (isObject(error) && error.code === "ENOENT") return {};
    throw error;
  }
}

export async function readDelegationModels(): Promise<Config> {
  try {
    const config = await readConfig(await configPath());
    return { worker: parsePreference(config.worker), scout: parsePreference(config.scout) };
  } catch {
    // An unreadable or malformed optional preference must not block startup.
    return {};
  }
}

export async function writeDelegationModel(role: Role, preference: DelegationModelPreference): Promise<void> {
  const path = await configPath();
  const config = await readConfig(path);
  config[role] = preference;
  const directory = dirname(path);
  await mkdir(directory, { recursive: true });
  const tempPath = join(directory, `.delegation-models.${randomUUID()}.tmp`);
  try {
    await writeFile(tempPath, `${JSON.stringify(config, null, 2)}\n`, { flag: "wx", mode: 0o600 });
    await rename(tempPath, path);
  } catch (error) {
    await rm(tempPath, { force: true }).catch(() => undefined);
    throw error;
  }
}
