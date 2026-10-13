import assert from "node:assert/strict";
import { mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { piSdk } from "./pi-test-helpers.mjs";

const skillsDir = fileURLToPath(new URL("../home/.pi/agent/skills/", import.meta.url));

// These test native loading/routing, not LLM compliance with the interview prompt.
test("grill-me is discoverable without warnings and is explicit-only", async () => {
  const { loadSkillsFromDir, formatSkillsForPrompt } = await piSdk();
  const { skills, diagnostics } = loadSkillsFromDir({ dir: skillsDir, source: "user" });
  assert.deepEqual(diagnostics, []);
  const matches = skills.filter(skill => skill.name === "grill-me");
  assert.equal(matches.length, 1);
  const [skill] = matches;
  assert.equal(skill.filePath, join(skillsDir, "grill-me", "SKILL.md"));
  assert.equal(skill.baseDir, join(skillsDir, "grill-me"));
  assert.ok(skill.description.length > 0 && skill.description.length <= 1024);
  assert.equal(skill.disableModelInvocation, true);
  assert.equal(formatSkillsForPrompt([skill]), "");
  // Existing automatic skills remain visible; this is not a global policy change.
  assert.match(formatSkillsForPrompt(skills), /<name>log-investigation<\/name>/);
  assert.doesNotMatch(formatSkillsForPrompt(skills), /<name>grill-me<\/name>/);
});

test("native discovery follows the stow-style skills symlink and deduplicates explicit paths", async () => {
  const { loadSkills } = await piSdk();
  const agentDir = await mkdtemp(join(tmpdir(), "pi-grill-me-"));
  try {
    await symlink(skillsDir, join(agentDir, "skills"), "dir");
    const { skills, diagnostics } = loadSkills({
      cwd: agentDir,
      agentDir,
      skillPaths: [join(skillsDir, "grill-me")],
      includeDefaults: true,
    });
    assert.deepEqual(diagnostics, []);
    const matches = skills.filter(skill => skill.name === "grill-me");
    assert.equal(matches.length, 1);
    assert.equal(matches[0].disableModelInvocation, true);
  } finally {
    await rm(agentDir, { recursive: true, force: true });
  }
});
