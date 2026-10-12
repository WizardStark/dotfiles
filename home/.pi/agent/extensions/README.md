# Pi 1.1 extensions

These extensions require **Pi 1.1 or newer**. Pi loads the 20 top-level `.ts` entries and `statusline/index.ts`; `lib/` contains shared modules, not independent extensions.

## API improvements

| Improvement | Extensions / helpers | Behavior |
| --- | --- | --- |
| Renderer-only registration | `tool-badges`, `codemode-badge`, `lib/compact-tool-renderers` | `registerToolRenderer()` customizes collapsed views without replacing execution. `next()` preserves native expanded output, diffs, images and errors. Separate native component slots keep expansion toggles safe. |
| Duration and padding | Compact renderers, tool-badge widget | Recorded `durationMs` appears on completed calls; self-shell views respect `outputPad`. Old results without recorded duration omit it. |
| Cancellation and prompt waiting | `pi-notifications`, `turn-timer` | Aborted runs are not reported as completed. Overlapping UI prompts suspend the inactivity watchdog and show “Awaiting input.” The turn duration remains total wall time, including input waits. |
| Native subagent usage | `lib/subagent-runtime`, `lib/usage`, reviewer/advisor/delegation tools | Sum all finalized child responses and top-level child tool usage. Reconcile duplicate final envelopes without collapsing distinct same-timestamp requests. Native tool-result `usage` contributes to Pi's session totals; custom metrics retain estimates and throughput. |
| Registry-backed reviewer | `reviewer-subagent`, `lib/reviewer-request` | One no-tools `modelRegistry.streamSimple()` request replaces the reviewer subprocess, temporary timing extension and credential forwarding. Existing review stages/scoped models remain supported; failures retain usage, and shutdown cancels active requests. Worker, scout and advisor subprocess isolation remains unchanged. |
| Domain-specific rendering | Questionnaire, reviewer, advisor, delegation tools | Compact answers, cancellation, progress, models and completed/total counts; expansion reveals full reports/errors. Render slots reuse components and rebuild themed text on updates. |
| Branch-aware restoration | `supervisor-worker`, `three-tier-routing` | Restore overrides, review keys and handoff pointers from `getBranch()` on startup/navigation; invalidate transient work. The current global workflow preference remains authoritative, so historical state cannot re-enable delegation. |
| Theme-reactive statusline | `statusline/registry` and all registry producers | Store semantic values/render callbacks, not permanently colored strings. The footer applies the active theme during rendering, including after invalidation. Plain-string items remain supported. |

`builtin:codemode` is enabled again and owns codemode execution, state, schemas and usage. `codemode-badge` is presentation-only. `zsh-env` intentionally still replaces bash execution using its native tool definition; `tool-badges` supplies presentation separately.

In TUI mode, tool badges appear only in the transcript, with nested codemode calls in its tree. The legacy above-editor activity strip is cleared and not populated, avoiding duplicate badges beside the input field. RPC clients retain the activity-summary widget because terminal transcript renderers are unavailable there.

Structured prompt policies (`secret_file_guard`, `workflow_policy`, `workflow_handoffs`), model-only orchestration exposure, workflow execution gates and native structured tool results are retained.

## Validation

Run:

```sh
node --test tests/*.test.mjs
git diff --check
```

The SDK smoke test (`tests/pi-100-extensions.test.mjs`, historical filename) resolves managed or npm installations, loads **all 21 custom extensions plus builtin codemode** in an offline, in-memory print session, exercises startup/prompt hooks and verifies native usage totals. Set `PI_TEST_PACKAGE_DIR` to test a specific installed package. The target version is asserted rather than silently skipped.

Regression tests cover real native expanded renderers, duration/padding/component reuse, narrow Unicode layouts, fake-clock cancellation/prompt waiting, branch isolation/workflow gates, theme changes, multi-request usage and mock reviewer streams/model selection/shutdown.

Live provider calls, real worker/advisor delegation and terminal interaction still require manual integration checks. A strict full-extension typecheck also has pre-existing errors outside these improvements; loading is not a substitute for typechecking those legacy paths.

## Accounting boundary

Native usage is returned by model-callable tools. `/review`, `/advisor` and automatic advisor packets retain their existing custom metrics accounting: the extension API exposes a read-only session manager and no public command-side usage writer. They must not cast around that contract or double-charge usage through multiple channels. Missing/unknown catalog prices remain visibly unknown in custom cost metrics; estimates are not substituted for provider-reported native costs.
