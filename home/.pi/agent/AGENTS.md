## Default Response Style

- Be concise and direct by default.
- Start with the answer or outcome, not a recap of the request.
- Use short bullets instead of long prose unless detail is requested.
- For code changes, report only what changed, the affected file paths, and any required next step.
- Do not quote raw tool output unless the exact text matters.
- Offer more detail optionally instead of including it by default.
- Prefer programmatic extraction of relevant content over whole-file reading.

## Clarification Policy

- Use `ask_user_question` only when a required decision cannot be inferred safely and would materially change implementation, behavior, UX, API shape, file structure, or validation.
- Batch related decisions into one call; it accepts 1–4 questions with 2–4 concise options each.
- Prefer clarification over guessing when there are multiple plausible paths with meaningful trade-offs.
- Do not ask about low-impact details that can be reasonably defaulted and easily changed later; in those cases, proceed and state the assumption.
- Ask before proceeding on destructive, expensive, or user-visible decisions when the preference is not already clear.

## Validation

- Use validation commands appropriate to the changed files and available local tooling.
- When reporting verification, state exactly which commands were run and any blockers.

## Codemode Outcome Structure

- Keep Pi's native codemode execution; implement this convention inside scripts, not through execution overrides.
- Use `Promise.allSettled()` for independent operations. Run dependent operations sequentially and do not concurrently mutate the same file.
- Normalize each operation into a compact record:

```js
{
  operation: "typecheck",
  status: "failed",       // passed | failed | aborted | skipped
  kind: "exit",           // null on success; exit | tool | exception | model | dependency
  summary: "8 diagnostics",
  diagnosticPath: "/tmp/typecheck.log" // optional full-output reference
}
```

- Determine success from the operation's contract, not promise fulfillment or "Script completed": bash requires `exit_code === 0`; MCP requires no `isError` plus any tool-specific postconditions; classifier/image calls require a successful `stopReason` and the expected result. Read/edit/write must not reject and must satisfy any required postconditions.
- Serialize rejected errors explicitly as `name` and `message`; preserve cancellation as `aborted`. Missing or malformed expected result fields are failures, not assumed successes.
- Treat expected nonzero probes explicitly as optional and distinguish them from failed required checks.
- Emit one bounded batch summary with passed/failed/aborted/skipped counts and operation records. Preserve useful successful values, include concise failure diagnostics, and reference full output when needed; do not dump every intermediate result or expose secrets.
- Print the summary before throwing for a failed or aborted required operation, so the parent codemode result signals failure without losing completed results.
- Block dependent work, commits, and deployments when required prerequisites fail or are aborted; mark unrun dependent operations `skipped` with kind `dependency`.
- Failures and cancellation do not roll back completed operations. Inspect affected files/state before retrying; never blindly replay a mutating batch. Retry only known transient failures with bounded attempts and confirmed idempotency; correct argument/schema errors instead of retrying unchanged.
