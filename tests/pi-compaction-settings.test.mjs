import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { piSdk } from "./pi-test-helpers.mjs";

const settings = JSON.parse(readFileSync(new URL("../home/.pi/agent/settings.json", import.meta.url), "utf8"));
const checkpoint = 272_000;
const isGpt6 = key => /^github-copilot\/gpt-6(?:[.-])/.test(key);

// Resolve real catalog limits without credentials or network requests. Model metadata
// changes should fail this test rather than silently shift the configured checkpoint.
test("every enabled or overridden GPT-6 model has a native 272k compaction checkpoint", async t => {
  const { ModelRuntime, SettingsManager, shouldCompact } = await piSdk();
  const directory = await mkdtemp(join(tmpdir(), "pi-compaction-settings-"));
  try {
    const runtime = await ModelRuntime.create({
      authPath: join(directory, "auth.json"), modelsPath: null, allowModelNetwork: false,
    });
    const manager = SettingsManager.inMemory(settings);
    const overrides = settings.compaction.modelOverrides;
    const keys = new Set([
      `${settings.defaultProvider}/${settings.defaultModel}`,
      ...settings.enabledModels,
      ...Object.keys(overrides),
    ].filter(isGpt6));
    assert.ok(keys.has("github-copilot/gpt-6.1-sol"));
    for (const key of keys) {
      await t.test(key, () => {
        assert.ok(Object.hasOwn(overrides, key), `${key} must not fall back to the global reserve`);
        const slash = key.indexOf("/");
        const model = runtime.getModel(key.slice(0, slash), key.slice(slash + 1));
        assert.ok(model, `${key} must exist in the offline Pi catalog`);
        const effective = manager.getCompactionSettings(model);
        assert.equal(model.contextWindow - effective.reserveTokens, checkpoint,
          `${key}: reserve must be contextWindow (${model.contextWindow}) minus ${checkpoint}`);
        assert.equal(effective.enabled, true);
        assert.equal(effective.keepRecentTokens, 20_000);
        assert.equal(shouldCompact(271_999, model.contextWindow, effective), false);
        assert.equal(shouldCompact(272_000, model.contextWindow, effective), false);
        assert.equal(shouldCompact(272_001, model.contextWindow, effective), true);
      });
    }
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("unrelated models retain the ordinary compaction fallback and disabled compaction stays disabled", async () => {
  const { SettingsManager, shouldCompact } = await piSdk();
  const model = { provider: "fixture", id: "unrelated-model" };
  const manager = SettingsManager.inMemory(settings);
  assert.deepEqual(manager.getCompactionSettings(model), {
    enabled: true, reserveTokens: 27_200, keepRecentTokens: 20_000,
  });
  const disabled = SettingsManager.inMemory({
    ...settings, compaction: { ...settings.compaction, enabled: false },
  });
  const effective = disabled.getCompactionSettings({ provider: "github-copilot", id: "gpt-6.1-sol" });
  assert.equal(shouldCompact(272_001, 1_050_000, effective), false);
});
