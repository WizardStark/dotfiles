---
name: log-investigation
description: Investigate application, service, infrastructure, audit, and JSON/text logs with a bounded programmatic triage phase before targeted deep analysis. Use for incidents, failures, regressions, anomalous behavior, correlation-ID tracing, and root-cause investigations involving log files.
---

# Log Investigation

Use this workflow to preserve detailed causal analysis while minimizing uncontrolled raw-log ingestion.

## Safety and scope

- Never read `.env` or `.env.*` files. Treat credentials, tokens, cookies, authorization headers, and personally identifying data as sensitive; redact them from commands and findings.
- Establish the investigation boundary before searching: time window, environment, affected service or host, symptom, and known request/correlation/trace IDs.
- If a boundary is missing, infer it only from explicit user context. Otherwise ask one concise clarifying question when the missing detail would make the search unbounded.
- State assumptions briefly, including timezone assumptions.

## Phase 1 — programmatic triage

Do **not** begin by reading complete logs or broadly printing raw matches. First build an evidence map with bounded queries and aggregations.

### 1. Inventory sources

Identify relevant candidate files and formats without reading their full contents:

```bash
find <log-root> -type f -printf '%s %TY-%Tm-%TdT%TH:%TM %p\n' | sort -n
file <candidate-files>
```

Use repository-aware sources too when applicable:

```bash
git log --oneline --decorate --since='<start>' --until='<end>'
git diff <known-good>..<known-bad> -- <affected-path>
```

### 2. Derive narrow signatures

Search for known error names, status codes, endpoint names, component names, and supplied IDs. Keep output bounded with file names, counts, or selected line references:

```bash
rg -l -i 'error|exception|timeout|<signature>' <log-root>
rg -n -i -m 30 '<signature>' <candidate-file>
rg -o '<id-pattern>' <candidate-file> | sort | uniq -c | sort -nr | head -30
```

For structured logs, aggregate fields instead of printing objects:

```bash
jq -r 'select(.level == "error") | [.timestamp, .service, .message] | @tsv' <log-file> \
  | cut -f2- | sort | uniq -c | sort -nr | head -30
```

Use a small local `awk`, `jq`, or Python parser when repeated grep output would otherwise be needed. Prefer answers such as counts by minute, service, error class, status, and correlation ID.

### 3. Correlate and rank

Connect sources using timestamps, correlation/request/trace IDs, host or pod identifiers, deployment/version changes, and dependency names. Rank candidates by:

1. temporal proximity to the symptom;
2. recurrence and concentration of the signature;
3. presence across independently relevant sources; and
4. explanatory power for the reported behavior.

### 4. Return an evidence map

After roughly **5–8 bounded discovery commands**, stop and summarize before expanding the search. Include:

| Candidate | Why it matters | Evidence | Highest-value next range/query |
|---|---|---|---|
| file/source | signature, ID, or time overlap | count plus timestamp/line reference | exact time range, line range, or ID |

Do not include large raw-log excerpts. If no lead is discriminating, state that clearly and propose the single most informative next query rather than searching indiscriminately.

## Phase 2 — targeted deep analysis

Only inspect content selected by the evidence map.

- Read narrow line ranges or time windows around the strongest events.
- Follow a small set of selected correlation IDs across relevant sources.
- Expand a window only when the preceding window creates a concrete reason to do so.
- Compare with a baseline: successful request, prior deployment, unaffected host, or pre-incident interval where available.
- Stop broad searching once a likely causal path exists; use remaining work to validate or falsify it.

Maintain an evidence ledger during analysis:

| Claim | Supporting location | Confidence | Alternative explanation / validation |
|---|---|---|---|
| observed fact or inference | file, line/time range, query | high/medium/low | competing cause or confirming test |

Label conclusions as **observed**, **inferred**, or **unresolved**. Do not present correlation alone as causation.

## Delegation

Load delegation tools only when the sources can be partitioned independently, such as:

- application logs versus infrastructure/proxy logs;
- deployment history versus runtime traces; or
- distinct services with a shared trace ID.

Give each scout a bounded source/time scope and require a concise structured return: candidate signatures, counts, timestamps/IDs, and the highest-value locations. Do not have multiple scouts broadly inspect the same logs or return raw log dumps. The primary agent owns cross-source correlation, causal reasoning, and the final conclusion.

## Final report

Return, in this order:

1. **Conclusion** — root cause or leading hypothesis, with confidence.
2. **Causal timeline** — only the events necessary to explain the outcome.
3. **Evidence** — concise references to files, timestamps, line ranges, IDs, and aggregation results.
4. **Alternatives and gaps** — rejected or unresolved explanations and why.
5. **Recommended next action** — remediation, validation query, or instrumentation change.

Keep raw excerpts short and only include them when their exact text is material to the conclusion.
