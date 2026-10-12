import { realpath } from "node:fs/promises";
import { basename, resolve } from "node:path";

export function isDotenvPath(path: string): boolean {
  const name = basename(path);
  return /^\.env(?:\..+)?$/.test(name) && name !== ".env.example";
}

/** Check names and symlink targets without opening file contents. */
export async function isSecretPath(path: string, cwd = process.cwd()): Promise<boolean> {
  const absolute = resolve(cwd, path);
  if (isDotenvPath(absolute)) return true;
  try {
    return isDotenvPath(await realpath(absolute));
  } catch {
    return false;
  }
}

export async function safePaths(paths: string[], cwd: string): Promise<string[]> {
  const blocked = await Promise.all(paths.map((path) => isSecretPath(path, cwd)));
  return paths.filter((_path, index) => !blocked[index]);
}
