# Pi 1.0 extension audit

Pi loads the 20 top-level `.ts` entries and `statusline/index.ts`; `lib/` contains shared modules, not independent extensions. The Pi 1.0.0 SDK smoke test (`tests/pi-100-extensions.test.mjs`) loads **all 21** in a clean, in-memory, offline print session, binds their `session_start` handlers, and exercises `before_agent_start` without a model request.

| Integration | Extensions | Pi 1.0 assessment |
| --- | --- | --- |
| Structured system prompt | `block-dotenv-read`, `supervisor-worker` | Migrated dynamic instructions from whole-prompt overrides to named `systemPromptOptions.sections`; supervisor removes stale handoff sections. |
| Headless UI lifecycle | `statusline`, `supervisor-worker`, `turn-timer` | Guard theme rendering when `ctx.hasUI` is false. |
| Custom tools and renderers | `ask-user-question`, `codemode-badge`, `reviewer-subagent`, `three-tier-routing`, `tool-badges`, `zsh-env` | Already use Pi's tool schemas, exposure, execution and renderer contracts. The built-in tool wrappers (`codemode-badge`, `tool-badges`, `zsh-env`) preserve native results, including structured content. |
| Commands, keyboard and UI | `brief`, `btw`, `continue-hotkey`, `copy-smart`, `pr-comment-address`, `safe-interrupt`, `undo-last-turn` | Existing command, shortcut, custom UI and session interfaces load under 1.0; no API migration necessary. |
| Metrics and notifications | `cache-health`, `copilot-cost`, `pi-notifications`, `token-throughput` | Existing session, provider and message events load under 1.0; no API migration necessary. |

This smoke test does not exercise interactive terminal rendering, external GitHub requests, provider calls or actual delegation. Those still require manual integration checks in their respective environments.
