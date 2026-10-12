import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { importExtension, mockApi, piSdk, theme } from "./pi-test-helpers.mjs";

// Module-level workflow config is isolated from the real home preference.
const home = await mkdtemp(join(tmpdir(), "pi-branch-home-"));
const previousHome = process.env.HOME;
process.env.HOME = home;
const workflow = await importExtension("lib/workflow-mode.ts");
const supervisor = await importExtension("supervisor-worker.ts");
process.env.HOME = previousHome;
const { SessionManager } = await piSdk();

test("supervisor restores only active-branch overrides, review keys and handoffs, without weakening workflow gates", async () => {
  const directory = await mkdtemp(join(tmpdir(), "pi-branch-repo-"));
  const api = mockApi();
  try {
    execFileSync("git", ["init", "-q", directory]);
    await writeFile(join(directory, "change.ts"), "change\n");
    await workflow.writeWorkflowMode("three-tier");
    supervisor.default(api);
    const manager = SessionManager.inMemory(directory);
    api.appendEntry = (type, data) => manager.appendCustomEntry(type, data);
    const root = manager.appendCustomEntry("root", {});
    const a = { provider: "test", id: "worker-a" }, b = { provider: "test", id: "worker-b" }, main = { provider: "test", id: "main" };
    const notices = [];
    const context = {
      cwd: directory, mode: "print", hasUI: false, model: main, scopedModels: [], thinkingLevel: "high",
      modelRegistry: { getAvailable: () => [main, a, b] }, sessionManager: manager,
      ui: { theme: theme(), setStatus() {}, setWidget() {}, notify: (text) => notices.push(text) },
    };
    manager.appendCustomEntry("supervisor-worker-state", { override: a, thinkingLevel: "low", workflowMode: "guided" });
    manager.appendCustomEntry("subagent-handoff", { source: "a", toolName: "delegate_worker", title: "branch-a", summary: "branch-a", filesChanged: [] });
    await api.emit("session_start", {}, context);
    const reviewCall = { toolName: "review_changes", toolCallId: "review-a", input: { stage: "final" } };
    assert.equal(await api.emit("tool_call", reviewCall, context), undefined);
    await api.emit("tool_result", { ...reviewCall, isError: false, content: [], details: {} }, context);
    const leafA = manager.getLeafId();
    assert.equal((await api.emit("tool_call", { ...reviewCall, toolCallId: "repeat-a" }, context)).block, true);
    // Make an abandoned sibling the latest entry in the file, then return to A.
    manager.branch(root);
    manager.appendCustomEntry("supervisor-worker-state", { override: b, thinkingLevel: "medium", workflowMode: "plain" });
    const leafB = manager.appendCustomEntry("subagent-handoff", { source: "b", toolName: "delegate_worker", title: "branch-b", summary: "branch-b", filesChanged: [] });
    manager.branch(leafA);
    await api.emit("session_tree", {}, context);
    await api.commands.get("worker-model").handler("", context);
    assert.match(notices.at(-1), /worker-a:low/);
    const promptA = { prompt: "", systemPromptOptions: { sections: {} } };
    await api.emit("before_agent_start", promptA, context);
    assert.match(promptA.systemPromptOptions.sections.workflow_handoffs, /branch-a/);
    assert.doesNotMatch(promptA.systemPromptOptions.sections.workflow_handoffs, /branch-b/);
    assert.match(promptA.systemPromptOptions.sections.workflow_policy, /Delegation Policy/);
    assert.equal((await api.emit("tool_call", { ...reviewCall, toolCallId: "repeat-a2" }, context)).block, true);
    await workflow.writeWorkflowMode("guided");
    await api.emit("session_tree", {}, context);
    assert.equal((await api.emit("tool_call", { toolName: "delegate_worker", input: {} }, context)).block, true);
    assert.ok(!api.getActiveTools().includes("load_delegation_tools"));
    await workflow.writeWorkflowMode("three-tier");
    manager.branch(leafB);
    await api.emit("session_tree", {}, context);
    await api.commands.get("worker-model").handler("", context);
    assert.match(notices.at(-1), /worker-b:medium/);
    // A's completed review and pending calls cannot suppress this branch's review.
    assert.equal(await api.emit("tool_call", { ...reviewCall, toolCallId: "review-b" }, context), undefined);
    const promptB = { prompt: "", systemPromptOptions: { sections: {} } };
    await api.emit("before_agent_start", promptB, context);
    assert.match(promptB.systemPromptOptions.sections.workflow_handoffs, /branch-b/);
    assert.doesNotMatch(promptB.systemPromptOptions.sections.workflow_handoffs, /branch-a/);
    for (const mode of ["three-tier", "plain", "guided"]) {
      await workflow.writeWorkflowMode(mode);
      await api.emit("session_tree", {}, context);
      assert.equal(api.getActiveTools().includes("load_delegation_tools"), mode === "three-tier");
      const blocked = await api.emit("tool_call", { toolName: "delegate_worker", input: {} }, context);
      assert.equal(blocked?.block === true, mode !== "three-tier");
    }
  } finally {
    await api.emit("session_shutdown", {}, { ui: { setWidget() {}, setStatus() {} }, sessionManager: { getSessionFile() {} } });
    await rm(directory, { recursive: true, force: true });
    await rm(home, { recursive: true, force: true });
  }
});
