import type { Usage } from "@earendil-works/pi-ai";

export function sumUsages(usages: Array<Usage | undefined>): Usage | undefined {
  const present = usages.filter((usage): usage is Usage => usage !== undefined);
  if (!present.length) return undefined;
  const total: Usage = {
    input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
  };
  for (const usage of present) {
    for (const key of ["input", "output", "cacheRead", "cacheWrite", "totalTokens"] as const) total[key] += usage[key] ?? 0;
    for (const key of ["cacheWrite1h", "reasoning"] as const) {
      if (usage[key] !== undefined) total[key] = (total[key] ?? 0) + usage[key]!;
    }
    for (const key of ["input", "output", "cacheRead", "cacheWrite", "total"] as const) total.cost[key] += usage.cost?.[key] ?? 0;
  }
  return total;
}
