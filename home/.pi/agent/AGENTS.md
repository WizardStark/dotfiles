## Default Response Style

- Be concise and direct by default.
- Start with the answer or outcome, not a recap of the request.
- Use short bullets instead of long prose unless detail is requested.
- For code changes, report only what changed, the affected file paths, and any required next step.
- Do not quote raw tool output unless the exact text matters.
- Offer more detail optionally instead of including it by default.

## Validation

- Match this project's `.pre-commit-config.yaml` when validating changes.
- Use `mise exec -- bun ...` for project checks; do not rely on `npm` for lint/format validation.
- Do not treat `bun run check` / `svelte-check` as sufficient by itself; run ESLint too.
- After code changes, run these repo checks unless the user explicitly asks otherwise:
  - `mise exec -- bun prettier --write --check`
  - `mise exec -- bun eslint --fix`
  - `mise exec -- bun run check`
- When reporting verification, state exactly which of the above commands were run.
