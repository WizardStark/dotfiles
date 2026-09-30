import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const extension = (name) => readFile(new URL(`../home/.pi/agent/extensions/${name}.ts`, import.meta.url), "utf8");

test("compact tool renderers retain native results and zsh remains the only bash owner", async () => {
  const badges = await extension("tool-badges");
  assert.doesNotMatch(badges, /createBashTool|normalizeResult|wrapErrorResult/);
  assert.match(badges, /renderShell: "self"/);
  assert.match(badges, /renderResult: compactResult/);
  assert.match(badges, /return base\.execute\(toolCallId, params, signal, onUpdate, ctx\)/);
  assert.match(badges, /parentToolCallId/);
  assert.match(badges, /tool_execution_start/);
  assert.match(badges, /tool_execution_end/);
  const zsh = await extension("zsh-env");
  assert.match(zsh, /\.\.\.base,/);
  assert.match(zsh, /renderShell: "self"/);
  assert.match(zsh, /renderResult: compactResult/);
  assert.match(zsh, /return base\.execute\(toolCallId, params, signal, onUpdate, toolCtx\)/);
  const renderer = await extension("lib/compact-tool-renderers");
  assert.match(renderer, /if \(!options\.expanded\)/);
  assert.doesNotMatch(renderer, /registerTool\s*\(|structuredContent\s*:/);
});

test("interactive and orchestration tools are model-only, while delegation retains its execution gate", async () => {
  for (const [file, names] of [
    ["ask-user-question", ["ask_user_question"]],
    ["three-tier-routing", ["advisor_design"]],
    ["reviewer-subagent", ["review_changes"]],
    ["supervisor-worker", ["load_delegation_tools", "delegate_scout", "delegate_scouts", "delegate_worker", "delegate_workers"]],
  ]) {
    const source = await extension(file);
    for (const name of names) {
      assert.match(source, new RegExp(`name: "${name}",\\s*exposure: "model-only"`), `${file}: ${name}`);
    }
  }
  const supervisor = await extension("supervisor-worker");
  assert.match(supervisor, /getWorkflowMode\(state\) !== "three-tier"\s*&&\s*isDelegationToolName\(event\.toolName\)/);
  assert.match(supervisor, /getWorkflowMode\(state\) === "plain" && event\.toolName === "advisor_design"/);
});
