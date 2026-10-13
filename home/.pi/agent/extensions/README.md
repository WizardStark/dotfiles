# Pi 1.1 extensions

These extensions require **Pi 1.1 or newer**. Pi loads the 21 top-level `.ts` entries and `statusline/index.ts`; `lib/` contains shared modules, not independent extensions.

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

In TUI mode, tool badges appear only in the transcript, with nested codemode calls grouped by tool in its collapsed tree (for example, `read x6`, `bash x2`, `edit`). Arguments, paths and command previews stay in the expanded native view; failed groups remain marked. The legacy above-editor activity strip is cleared and not populated, avoiding duplicate badges beside the input field. RPC clients retain the activity-summary widget because terminal transcript renderers are unavailable there.

Structured prompt policies (`secret_file_guard`, `workflow_policy`, `workflow_handoffs`), model-only orchestration exposure, workflow execution gates and native structured tool results are retained.

## Transcript navigation

Run `/transcript` or press **Alt+T** to open a read-only transcript overlay. It uses only supported extension UI/session APIs: it does not patch Pi, change the main transcript's folds, edit the composer draft, run tools or add model context.

| Keys | Action |
| --- | --- |
| `j` / `k` (or arrows) | Select next/previous node, keeping it visible |
| `Ctrl+U` / `Ctrl+D` | Scroll half a page, including within expanded output |
| `gg` / `G` | Select first/last node |
| `Enter` / `za` | Toggle the selected node's local fold |
| `h` / `l` (or left/right) | Collapse/expand selected node |
| `/`, then Enter | Search node titles and bodies; open the matching node |
| `n` / `N` | Next/previous matching node, wrapping at the ends |
| `r` | Refresh the snapshot, retaining surviving selection/folds |
| `Esc` / `i` | Close and return to the composer |

Search accepts normal text editing; Escape cancels search before closing the overlay. Each opening starts at the last recorded node with folds collapsed. The view snapshots the **active branch**, including history before compaction; streaming/unrecorded output appears only after it is saved and you refresh. Session/branch replacement and shutdown close the overlay.

Tool calls and their results share one node. Expansion shows arguments, text output and recorded edit diffs; thinking has separate nodes. Images are represented by labels, not decoded or rendered. Hidden custom entries and system prompts are excluded. Previews are plain text, terminal-control sequences are stripped, and each body is bounded at 100,000 characters with an explicit truncation marker. This is a transcript inspector, not a byte-for-byte reproduction of native rich renderers.

## Audit fixes and removed legacy paths

- Expanded native render slots retain their components across toggles and receive final cleanup updates while collapsed.
- Reviewer patches/snippets, undo snapshots, and supervisor-owned reads exclude dotenv paths and canonical symlink targets. Git patches disable external diff/textconv.
- Session-owned controllers cancel reviewer/advisor/subprocess work, side questions and PR fetches. Old branch completions cannot publish reports, logs, metrics, composer edits or clipboard selections.
- Orchestration batches execute sequentially relative to other tool calls; bounded parallel work inside a batch remains supported.
- Every outer retry contributes usage, including failures. Failed, aborted or incomplete terminal responses cannot be promoted by recovered historical text.
- Custom metrics reconcile by request/batch ID rather than timestamps, and persist failed command/advisor usage as non-context custom metadata. Ephemeral sessions have distinct registry keys.
- Narrow metrics/selection layouts obey render width, themes are read at render time, and `max` thinking is supported.
- Removed unused text chunking, transient widgets, the unused exact-model wrapper, obsolete JSON partial snapshots, dead handoff formatting, and the broken `/noop-subagent` diagnostic command.
- Subprocesses preserve null headers, endpoint and provider environment overrides; OAuth is still resolved inside the child. `PI_SUBAGENT_CLI` can explicitly select a CLI entry script for SDK hosts. Unrelated SDK host scripts are not launched as Pi.
- `PI_CACHE_HEALTH_LEDGER` optionally redirects the prompt-free ledger (also used for isolated tests).

Filename checks and shell guards are not an OS sandbox. Arbitrary shell indirection/hard links and external extensions still require an actual isolation boundary when security depends on it. Native `editor()` has no public cancellation option: brief waits stop on invalidation and late replies are ignored, but dialog dismissal remains Pi/the RPC client's responsibility.

## Validation

Run:

```sh
PI_OFFLINE=1 JITI_FS_CACHE=0 node --test --test-timeout=10000 tests/*.test.mjs
PI_TEST_TYPESCRIPT_PATH=/path/to/typescript/lib/typescript.js node scripts/check-pi-extensions.mjs
git diff --check
```

The SDK smoke test (`tests/pi-100-extensions.test.mjs`, historical filename) resolves managed or npm installations, loads **all 22 custom extensions plus builtin codemode** in an offline, in-memory print session, exercises startup, prompt construction and settlement through public APIs with a faux provider, and verifies native usage totals. Authentication/configuration paths are explicitly disposable. Set `PI_TEST_PACKAGE_DIR` to test a specific installed package. The target version is asserted rather than silently skipped.

Regression tests cover native partial-to-final cleanup/expansion toggles, narrow Unicode layouts, prompt waiting/abort handling, branch/workflow isolation, themes, same-timestamp and repeated usage envelopes, outer retries, stale command replies, mock reviewer streams, and scripted JSON fixture subprocesses. The public-SDK contract test executes parallel nested tools and validates permission/schema hooks, structured output, streaming updates, model-only exposure and exactly-once native usage.

Live provider calls, real worker/advisor delegation and terminal interaction still require manual integration checks. The strict no-emit check includes all extension/helper TypeScript files, installed public declarations, and unused-local/parameter checks. With Pi 1.2 declarations, existing notification/routing/workflow handlers need narrowing for the new `BeforeAgentStartEvent` union; the transcript navigator has no diagnostics. Loading alone remains insufficient evidence of compatibility.

## Accounting boundary

Native usage is returned by model-callable tools. `/review`, `/advisor` and automatic advisor packets retain their existing custom metrics accounting: the extension API exposes a read-only session manager and no public command-side usage writer. They must not cast around that contract or double-charge usage through multiple channels. Failed command/automatic-advisor metrics persist as `subagent-usage` custom entries without entering model context or fabricating native charges. Missing/unknown catalog prices remain visibly unknown in custom cost metrics; estimates are not substituted for provider-reported native costs.
