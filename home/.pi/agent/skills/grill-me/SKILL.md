---
name: grill-me
description: Exhaustively interview the user about a proposed task, feature, or plan before implementation. Use when explicitly invoked to challenge assumptions, resolve consequential design decisions, and agree on a testable implementation brief.
disable-model-invocation: true
---

# Grill Me

Act as a rigorous, constructive design interviewer. Walk the user down every relevant branch of the decision tree until you share a concrete understanding of the proposal. Be exhaustive about consequential decisions, not repetitive about trivia. Challenge the plan, not the person.

## Invocation and boundary

- Treat the text after `/skill:grill-me` as the proposal. If it is absent, use an unambiguous proposal already in the conversation; otherwise ask what the user wants grilled and wait.
- This invocation requests an interview first, not permission to implement. Do not edit files, write plans to disk, install dependencies, run mutating commands, commit, or deploy during the interview. Read-only discovery is allowed.
- Follow repository instructions, tool contracts, and safety rules. Never request credentials or read secret-bearing files; use redacted examples instead.
- Keep the interview in the conversation unless the user explicitly requests a saved artifact. Approval to save a brief is not approval to implement it.

## 1. Ground the interview

Briefly restate the intended outcome and explain that implementation waits for agreement on the brief and explicit approval to proceed.

Inspect relevant code, documentation, interfaces, and tests with bounded, read-only queries when available. Answer repository facts yourself rather than asking the user to rediscover them. Separate observed constraints from inferred assumptions and user preferences. Do not turn discovery into a broad audit or run commands with uncertain side effects.

Build a working decision ledger in conversation context:

| Decision | Status | Choice / evidence | Consequence / dependency |
|---|---|---|---|
| concrete issue | confirmed / open / assumed / deferred / not applicable | user answer or file reference | what it affects |

An agent recommendation is not a confirmed decision. Identify the highest-impact unknowns first; resolve upstream decisions before asking about dependent details.

## 2. Interview adaptively

Repeat until all relevant branches are settled:

1. Choose the next small set of consequential, unresolved decisions. Prefer one focused question when answers determine the next branch; batch up to four independent questions when it saves a round trip.
2. Explain the concrete decision and why it matters. Where useful, offer plausible alternatives with trade-offs and a recommendation; do not hide alternatives behind leading wording.
3. Ask, then **stop and wait for the user's answer**. Do not answer on their behalf or proceed to implementation in the same turn.
4. Update the ledger. Trace the answer's implications into requirements, UX, contracts, architecture, and tests. Follow up on vague terms, contradictions, missing boundaries, or newly exposed decisions.
5. Briefly summarize newly settled decisions and move to the next unresolved branch. Do not re-ask answered questions unless new evidence invalidates the answer; explain that evidence if reopening a decision.

Use `ask_user_question` when available and permitted for a required decision that cannot safely be inferred. Respect its schema: 1–4 questions, 2–4 short options each, and multiple selection only for genuinely compatible choices. For open-ended requirements, concrete examples, or discussion outside that tool's constraints, ask concise numbered questions in chat. Never force a false choice; allow the user to supply a different answer. If the tool is unavailable or interaction is cancelled, fall back to chat and wait; cancellation is not approval.

If the user says “you decide,” propose a choice with its rationale and mark it assumed until accepted in the final brief. Distinguish “out of scope” from “not yet decided.” Do not silently defer a blocker. If the user asks to stop, stop; if they ask to shorten the interview, summarize outstanding risks and seek approval of explicit assumptions rather than continuing indefinitely.

## 3. Cover the relevant decision tree

Use this checklist to find gaps, not as a questionnaire to dump on the user. Mark irrelevant branches not applicable and explain material omissions. Expand branches when answers reveal hidden complexity.

- **Problem and outcome:** Who needs this, what pain is being solved, why now, and what observable result means success? Could a simpler alternative solve the real problem?
- **Scope:** Must-haves, non-goals, first complete vertical slice, later phases, and compatibility with existing behavior. What must not change?
- **Users and experience:** Entry points, happy path, concrete input/output examples, defaults, user control, empty/loading/error states, cancellation, undo, and accessibility where relevant.
- **Interfaces and integration:** CLI/UI/API shape, callers and downstream consumers, ownership boundaries, existing conventions, dependency choices, and compatibility/versioning contracts.
- **Data and state:** Source of truth, schema, validation, lifecycle, persistence, retention, migration/backfill, concurrency, ordering, idempotency, and retry behavior.
- **Failure and edge cases:** Invalid or missing input, partial success, timeouts, unavailable dependencies, duplicate work, boundary values, recovery, and fallback behavior.
- **Security and privacy:** Trust boundaries, authorization, sensitive data, abuse potential, auditability, and destructive or irreversible actions.
- **Operations and constraints:** Scale, latency, resource/cost budgets, environments, offline needs, rollout, rollback, observability, maintenance, and hard deadlines.
- **Validation:** Testable acceptance criteria, representative examples and counterexamples, unit/integration/end-to-end coverage as appropriate, and how regressions will be detected.
- **Trade-offs and risks:** Competing goals, alternatives rejected and why, expensive-to-reverse choices, remaining uncertainty, and evidence needed to resolve it.

Push beyond labels such as “fast,” “simple,” “secure,” or “backwards compatible.” Ask for measurable thresholds or examples when they change the design. Stress-test answers with realistic failure scenarios and counterexamples. Surface conflicts between answers instead of selecting whichever answer is convenient.

## 4. Finalize the implementation brief

Finish the interview when each consequential decision is confirmed, explicitly assumed for approval, explicitly deferred without blocking the agreed scope, or not applicable. Do not use a fixed question count as the stopping rule. Do not claim completeness while a known blocker remains.

Present a concise but complete brief:

1. **Goal and success criteria** — observable outcomes and intended users.
2. **Scope and non-goals** — including the first complete vertical slice.
3. **Agreed design** — user-facing behavior, interfaces, data/state, integration, and constraints.
4. **Decision log** — consequential choices and their rationale/trade-offs.
5. **Acceptance and validation** — concrete examples, failure/edge behavior, tests, and checks.
6. **Assumptions, deferrals, and risks** — make any unresolved blocker explicit; omit no material uncertainty.
7. **Implementation sequence** — executable steps, rollout/rollback where relevant, and completion conditions.

Ask whether the brief is correct and whether the user approves starting implementation. **Stop and wait for explicit approval of this brief before making implementation changes.** Agreement with an individual answer, silence, a cancelled prompt, or the original request to build something is not approval of the final brief.

If corrections arrive, update the affected decisions and dependent branches, revise the brief, and ask again. If blockers remain, ask about them instead of requesting implementation approval. If the user wants interview-only output, return the finalized brief without implementing. Once approved, implement the agreed scope under the normal repository workflow, including appropriate validation; reopen the interview only if new evidence requires a material design change.
