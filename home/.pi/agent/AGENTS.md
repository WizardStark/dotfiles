## Default Response Style

- Be concise and direct by default.
- Start with the answer or outcome, not a recap of the request.
- Use short bullets instead of long prose unless detail is requested.
- For code changes, report only what changed, the affected file paths, and any required next step.
- Do not quote raw tool output unless the exact text matters.
- Offer more detail optionally instead of including it by default.

## Clarification Policy

- Use `ask_user_question` proactively when a request is underspecified and the missing decision could materially change implementation, behavior, UX, API shape, file structure, or validation strategy.
- Prefer clarification over guessing when there are multiple plausible paths with meaningful trade-offs.
- Batch all needed clarifications into one `ask_user_question` call before proceeding.
- Do not ask about low-impact details that can be reasonably defaulted and easily changed later; in those cases, proceed and state the assumption.
- Ask before proceeding on destructive, expensive, or user-visible decisions when the preference is not already clear.

## Validation

- Use validation commands appropriate to the changed files and available local tooling.
- When reporting verification, state exactly which commands were run and any blockers.
