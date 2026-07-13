import { CONFIG_DIR_NAME, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { mkdir, writeFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { join } from "node:path";

const COMMAND = "pr-comment-address";
const DEFAULT_HOSTNAME = "github.com";
const GH_TIMEOUT_MS = 120_000;
const REVIEW_THREADS_QUERY = `query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          comments(first: 100) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              databaseId
              url
              createdAt
              author {
                login
              }
              pullRequestReview {
                databaseId
                state
              }
              replyTo {
                databaseId
              }
            }
          }
        }
      }
    }
  }
}`;

const REVIEW_THREAD_COMMENTS_QUERY = `query($threadId: ID!, $cursor: String) {
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      comments(first: 100, after: $cursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          databaseId
          url
          createdAt
          author {
            login
          }
          pullRequestReview {
            databaseId
            state
          }
          replyTo {
            databaseId
          }
        }
      }
    }
  }
}`;

type GhResult = {
	code: number;
	stdout: string;
	stderr: string;
};

type CurrentRepoInfo = {
	owner: { login?: string };
	name: string;
	nameWithOwner?: string;
	url?: string;
};

type PullInfo = {
	number: number;
	url?: string;
	title?: string;
	body?: string;
	state?: string;
	isDraft?: boolean;
	headRefName?: string;
	baseRefName?: string;
	author?: { login?: string };
	mergedAt?: string | null;
	reviewDecision?: string;
};

type RepoRef = {
	name: string;
	owner: string;
	nameWithOwner: string;
	hostname: string;
	url?: string;
	cwd: string;
};

type ParsedPullSelector = {
	prSelector: string;
	repo: RepoRef;
	repoOverride: string;
};

type IssueComment = {
	id: number;
	body?: string;
	html_url?: string;
	created_at?: string;
	updated_at?: string;
	user?: { login?: string };
	author_association?: string;
};

type ReviewComment = {
	id: number;
	body?: string;
	html_url?: string;
	path?: string;
	line?: number | null;
	original_line?: number | null;
	start_line?: number | null;
	original_start_line?: number | null;
	side?: string;
	subject_type?: string;
	commit_id?: string;
	pull_request_review_id?: number;
	in_reply_to_id?: number | null;
	created_at?: string;
	updated_at?: string;
	user?: { login?: string };
	author_association?: string;
	diff_hunk?: string;
};

type Review = {
	id: number;
	body?: string;
	state?: string;
	html_url?: string;
	commit_id?: string;
	submitted_at?: string;
	user?: { login?: string };
	author_association?: string;
};

type ReviewThreadCommentRef = {
	databaseId?: number | null;
	url?: string;
	createdAt?: string;
	author?: { login?: string };
	pullRequestReview?: { databaseId?: number | null; state?: string };
	replyTo?: { databaseId?: number | null };
};

type ReviewThread = {
	id: string;
	isResolved: boolean;
	isOutdated: boolean;
	path?: string;
	line?: number | null;
	originalLine?: number | null;
	comments: ReviewThreadCommentRef[];
};

type RawReviewThreadCommentConnection = {
	pageInfo?: {
		hasNextPage?: boolean;
		endCursor?: string | null;
	};
	nodes?: ReviewThreadCommentRef[];
};

type RawReviewThread = {
	id: string;
	isResolved: boolean;
	isOutdated: boolean;
	path?: string;
	line?: number | null;
	originalLine?: number | null;
	comments?: RawReviewThreadCommentConnection;
};

type ReviewThreadsConnection = {
	pageInfo?: {
		hasNextPage?: boolean;
		endCursor?: string | null;
	};
	nodes?: RawReviewThread[];
};

type ReviewThreadsPayload = {
	repository?: {
		pullRequest?: {
			reviewThreads?: ReviewThreadsConnection;
		};
	};
};

type ReviewThreadCommentsPayload = {
	node?: {
		comments?: RawReviewThreadCommentConnection;
	};
};

type GraphqlEnvelope<T> = {
	data?: T;
	errors?: Array<{ message?: string }>;
};

type Bundle = {
	generatedAt: string;
	selector: string | null;
	repo: RepoRef;
	pr: PullInfo;
	counts: {
		issueComments: number;
		reviewComments: number;
		reviews: number;
		reviewThreads: number;
		openReviewThreads: number;
	};
	issueComments: IssueComment[];
	reviewComments: ReviewComment[];
	reviews: Review[];
	reviewThreads: ReviewThread[];
	reviewThreadsWarnings: string[];
};

type CommentThreadState = {
	threadId: string;
	isResolved: boolean;
	isOutdated: boolean;
};

async function runGh(pi: ExtensionAPI, args: string[], signal?: AbortSignal): Promise<GhResult> {
	return await pi.exec("gh", args, { signal, timeout: GH_TIMEOUT_MS });
}

function ghFailure(args: string[], result: GhResult): Error {
	const detail = result.stderr.trim() || result.stdout.trim() || `gh ${args.join(" ")} failed`;
	return new Error(detail);
}

async function runGhJson<T>(pi: ExtensionAPI, args: string[], signal?: AbortSignal): Promise<T> {
	const result = await runGh(pi, args, signal);
	if (result.code !== 0) {
		throw ghFailure(args, result);
	}

	try {
		return JSON.parse(result.stdout) as T;
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		throw new Error(`Failed to parse gh JSON for ${args.join(" ")}: ${message}`);
	}
}

function hostnameFromUrl(url: string | undefined): string {
	if (!url) return DEFAULT_HOSTNAME;
	try {
		return new URL(url).hostname || DEFAULT_HOSTNAME;
	} catch {
		return DEFAULT_HOSTNAME;
	}
}

async function resolveCurrentRepo(pi: ExtensionAPI, signal?: AbortSignal): Promise<RepoRef> {
	const repo = await runGhJson<CurrentRepoInfo>(pi, ["repo", "view", "--json", "owner,name,nameWithOwner,url"], signal);
	const owner = repo.owner?.login?.trim();
	if (!owner || !repo.name?.trim()) {
		throw new Error("Could not resolve the current GitHub repository via gh repo view.");
	}

	return {
		owner,
		name: repo.name,
		nameWithOwner: repo.nameWithOwner?.trim() || `${owner}/${repo.name}`,
		hostname: hostnameFromUrl(repo.url),
		url: repo.url,
		cwd: process.cwd(),
	};
}

async function resolvePull(
	pi: ExtensionAPI,
	selector: string | undefined,
	repoOverride: string | undefined,
	signal?: AbortSignal,
): Promise<PullInfo> {
	const args = ["pr", "view"];
	if (selector) {
		args.push(selector);
	}
	if (repoOverride) {
		args.push("-R", repoOverride);
	}
	args.push("--json", "number,url,title,body,state,isDraft,headRefName,baseRefName,author,mergedAt,reviewDecision");
	return await runGhJson<PullInfo>(pi, args, signal);
}

function flattenPages<T>(value: unknown): T[] {
	if (!Array.isArray(value)) return [];
	if (value.length === 0) return [];
	if (value.every((item) => Array.isArray(item))) {
		return value.flat() as T[];
	}
	return value as T[];
}

async function fetchPaginatedArray<T>(pi: ExtensionAPI, repo: RepoRef, endpoint: string, signal?: AbortSignal): Promise<T[]> {
	const paginatedEndpoint = endpoint.includes("?") ? `${endpoint}&per_page=100` : `${endpoint}?per_page=100`;
	const payload = await runGhJson<unknown>(
		pi,
		["api", "--hostname", repo.hostname, "--paginate", "--slurp", paginatedEndpoint],
		signal,
	);
	return flattenPages<T>(payload);
}

function repoFromPrUrl(prUrl: string | undefined, fallback: RepoRef): RepoRef {
	if (!prUrl) return fallback;

	try {
		const parsed = new URL(prUrl);
		const [owner, name] = parsed.pathname.split("/").filter(Boolean);
		if (!owner || !name) return fallback;

		return {
			owner,
			name,
			nameWithOwner: `${owner}/${name}`,
			hostname: parsed.hostname || fallback.hostname,
			url: `${parsed.protocol}//${parsed.host}/${owner}/${name}`,
			cwd: fallback.cwd,
		};
	} catch {
		return fallback;
	}
}

function parsePullSelector(selector: string | undefined, cwd: string): ParsedPullSelector | undefined {
	if (!selector) return undefined;

	try {
		const parsed = new URL(selector);
		const [owner, name, kind, number] = parsed.pathname.split("/").filter(Boolean);
		if (!owner || !name || kind !== "pull" || !number) {
			return undefined;
		}

		const repo: RepoRef = {
			owner,
			name,
			nameWithOwner: `${owner}/${name}`,
			hostname: parsed.hostname || DEFAULT_HOSTNAME,
			url: `${parsed.protocol}//${parsed.host}/${owner}/${name}`,
			cwd,
		};

		return {
			prSelector: number,
			repo,
			repoOverride: `${repo.hostname}/${repo.nameWithOwner}`,
		};
	} catch {
		return undefined;
	}
}

function graphqlData<T>(payload: GraphqlEnvelope<T> | T): T {
	if (payload && typeof payload === "object" && "data" in payload && payload.data) {
		return payload.data;
	}
	return payload as T;
}

function normalizeReviewThread(thread: RawReviewThread, comments: ReviewThreadCommentRef[]): ReviewThread {
	return {
		id: thread.id,
		isResolved: Boolean(thread.isResolved),
		isOutdated: Boolean(thread.isOutdated),
		path: thread.path,
		line: thread.line,
		originalLine: thread.originalLine,
		comments,
	};
}

async function fetchReviewThreadComments(
	pi: ExtensionAPI,
	repo: RepoRef,
	threadId: string,
	initialComments: ReviewThreadCommentRef[],
	initialCursor: string | null | undefined,
	signal?: AbortSignal,
): Promise<ReviewThreadCommentRef[]> {
	const comments = [...initialComments];
	let cursor = initialCursor;

	while (cursor) {
		const payload = await runGhJson<GraphqlEnvelope<ReviewThreadCommentsPayload> | ReviewThreadCommentsPayload>(
			pi,
			[
				"api",
				"--hostname",
				repo.hostname,
				"graphql",
				"-f",
				`query=${REVIEW_THREAD_COMMENTS_QUERY}`,
				"-F",
				`threadId=${threadId}`,
				"-F",
				`cursor=${cursor}`,
			],
			signal,
		);
		const connection = graphqlData(payload).node?.comments;
		if (!connection) break;
		comments.push(...(connection.nodes ?? []));
		if (!connection.pageInfo?.hasNextPage || !connection.pageInfo.endCursor) break;
		cursor = connection.pageInfo.endCursor;
	}

	return comments;
}

async function fetchReviewThreads(
	pi: ExtensionAPI,
	repo: RepoRef,
	prNumber: number,
	signal?: AbortSignal,
): Promise<{ threads: ReviewThread[]; warnings: string[] }> {
	const threads: ReviewThread[] = [];
	const warnings: string[] = [];
	let cursor: string | undefined;

	try {
		while (true) {
			const args = [
				"api",
				"--hostname",
				repo.hostname,
				"graphql",
				"-f",
				`query=${REVIEW_THREADS_QUERY}`,
				"-F",
				`owner=${repo.owner}`,
				"-F",
				`name=${repo.name}`,
				"-F",
				`number=${prNumber}`,
			];
			if (cursor) {
				args.push("-F", `cursor=${cursor}`);
			}

			const payload = await runGhJson<GraphqlEnvelope<ReviewThreadsPayload> | ReviewThreadsPayload>(pi, args, signal);
			const connection = graphqlData(payload).repository?.pullRequest?.reviewThreads;
			if (!connection) break;

			for (const rawThread of connection.nodes ?? []) {
				const initialComments = rawThread.comments?.nodes ?? [];
				const comments = rawThread.comments?.pageInfo?.hasNextPage
					? await fetchReviewThreadComments(
						pi,
						repo,
						rawThread.id,
						initialComments,
						rawThread.comments.pageInfo.endCursor,
						signal,
					)
					: initialComments;
				threads.push(normalizeReviewThread(rawThread, comments));
			}

			if (!connection.pageInfo?.hasNextPage || !connection.pageInfo.endCursor) break;
			cursor = connection.pageInfo.endCursor;
		}
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		warnings.push(`Review-thread metadata unavailable: ${message}`);
	}

	return { threads, warnings: [...new Set(warnings)] };
}

function buildThreadStateIndex(reviewThreads: ReviewThread[]): Map<number, CommentThreadState> {
	const index = new Map<number, CommentThreadState>();
	for (const thread of reviewThreads) {
		for (const comment of thread.comments ?? []) {
			if (typeof comment.databaseId !== "number") continue;
			index.set(comment.databaseId, {
				threadId: thread.id,
				isResolved: Boolean(thread.isResolved),
				isOutdated: Boolean(thread.isOutdated),
			});
		}
	}
	return index;
}

function bullet(value: string): string {
	return `- ${value}`;
}

function cleanBody(value: string | undefined): string {
	return (value ?? "").replace(/\r\n/g, "\n").trim();
}

function quoteBlock(value: string | undefined): string[] {
	const body = cleanBody(value);
	if (!body) return ["> (none)"];
	return body.split("\n").map((line) => `> ${line}`);
}

function formatWhen(value: string | null | undefined): string {
	if (!value) return "unknown";
	return value;
}

function commentLine(comment: ReviewComment): string {
	const line = comment.line ?? comment.original_line ?? comment.start_line ?? comment.original_start_line;
	return line === null || line === undefined ? "?" : String(line);
}

function summarizePaths(comments: ReviewComment[]): string {
	const counts = new Map<string, number>();
	for (const comment of comments) {
		const path = comment.path?.trim();
		if (!path) continue;
		counts.set(path, (counts.get(path) ?? 0) + 1);
	}

	if (counts.size === 0) return "(no file-scoped review comments)";
	return [...counts.entries()]
		.sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
		.slice(0, 8)
		.map(([path, count]) => `${path} (${count})`)
		.join(", ");
}

function buildMarkdownBundle(bundle: Bundle): string {
	const threadStateIndex = buildThreadStateIndex(bundle.reviewThreads);
	const reviewSections = bundle.reviewComments.length > 0
		? bundle.reviewComments.flatMap((comment) => {
			const threadState = threadStateIndex.get(comment.id);
			return [
				`### Review comment ${comment.id}`,
				bullet(`author: ${comment.user?.login ?? "unknown"}`),
				bullet(`url: ${comment.html_url ?? "(unknown)"}`),
				bullet(`path: ${comment.path ?? "(unknown)"}`),
				bullet(`line: ${commentLine(comment)}`),
				bullet(`side: ${comment.side ?? "(unknown)"}`),
				bullet(`subject_type: ${comment.subject_type ?? "(unknown)"}`),
				bullet(`review_id: ${comment.pull_request_review_id ?? "(unknown)"}`),
				bullet(`reply_to: ${comment.in_reply_to_id ?? "(none)"}`),
				bullet(`thread_id: ${threadState?.threadId ?? "(unknown)"}`),
				bullet(`thread_resolved: ${threadState ? String(threadState.isResolved) : "(unknown)"}`),
				bullet(`thread_outdated: ${threadState ? String(threadState.isOutdated) : "(unknown)"}`),
				bullet(`created: ${formatWhen(comment.created_at)}`),
				bullet(`updated: ${formatWhen(comment.updated_at)}`),
				"",
				"Body:",
				...quoteBlock(comment.body),
				...(cleanBody(comment.diff_hunk)
					? ["", "Diff hunk:", ...quoteBlock(comment.diff_hunk)]
					: []),
				"",
			];
		})
		: ["- (none)"];

	const issueSections = bundle.issueComments.length > 0
		? bundle.issueComments.flatMap((comment) => [
			`### Issue comment ${comment.id}`,
			bullet(`author: ${comment.user?.login ?? "unknown"}`),
			bullet(`url: ${comment.html_url ?? "(unknown)"}`),
			bullet(`created: ${formatWhen(comment.created_at)}`),
			bullet(`updated: ${formatWhen(comment.updated_at)}`),
			"",
			"Body:",
			...quoteBlock(comment.body),
			"",
		])
		: ["- (none)"];

	const reviewBodies = bundle.reviews.length > 0
		? bundle.reviews.flatMap((review) => [
			`### Review ${review.id}`,
			bullet(`author: ${review.user?.login ?? "unknown"}`),
			bullet(`state: ${review.state ?? "unknown"}`),
			bullet(`url: ${review.html_url ?? "(unknown)"}`),
			bullet(`submitted: ${formatWhen(review.submitted_at)}`),
			bullet(`commit_id: ${review.commit_id ?? "(unknown)"}`),
			"",
			"Body:",
			...quoteBlock(review.body),
			"",
		])
		: ["- (none)"];

	return [
		"# PR comment address bundle",
		"",
		bullet(`Repository: ${bundle.repo.nameWithOwner}`),
		bullet(`Hostname: ${bundle.repo.hostname}`),
		bullet(`Repository URL: ${bundle.repo.url ?? "(unknown)"}`),
		bullet(`Working directory: ${bundle.repo.cwd}`),
		bullet(`PR: #${bundle.pr.number} ${bundle.pr.title ?? ""}`.trim()),
		bullet(`PR URL: ${bundle.pr.url ?? "(unknown)"}`),
		bullet(`State: ${bundle.pr.state ?? "unknown"}`),
		bullet(`Draft: ${bundle.pr.isDraft ? "yes" : "no"}`),
		bullet(`Review decision: ${bundle.pr.reviewDecision ?? "(none)"}`),
		bullet(`Base: ${bundle.pr.baseRefName ?? "unknown"}`),
		bullet(`Head: ${bundle.pr.headRefName ?? "unknown"}`),
		bullet(`Author: ${bundle.pr.author?.login ?? "unknown"}`),
		bullet(`Generated: ${bundle.generatedAt}`),
		"",
		"## Counts",
		bullet(`Issue comments: ${bundle.counts.issueComments}`),
		bullet(`Review comments: ${bundle.counts.reviewComments}`),
		bullet(`Reviews: ${bundle.counts.reviews}`),
		bullet(`Review threads: ${bundle.counts.reviewThreads}`),
		bullet(`Open review threads: ${bundle.counts.openReviewThreads}`),
		bullet(`Review-comment files: ${summarizePaths(bundle.reviewComments)}`),
		...(bundle.reviewThreadsWarnings.length > 0
			? ["", "## Review-thread warnings", ...bundle.reviewThreadsWarnings.map(bullet)]
			: []),
		"",
		"## Workflow rubric",
		bullet("Fix trivial, local, safe comments directly in code first."),
		bullet("Ask the user only about ambiguous, conflicting, architectural, or risky comments."),
		bullet("Keep comment metadata intact so replies can map back to GitHub threads later."),
		"",
		"## Reviews",
		...reviewBodies,
		"## Issue comments",
		...issueSections,
		"## Review comments",
		...reviewSections,
	].join("\n");
}

function buildAgentPrompt(bundle: Bundle, jsonPath: string, mdPath: string): string {
	const pathSummary = summarizePaths(bundle.reviewComments);
	const reviewThreadLine = bundle.reviewThreadsWarnings.length > 0
		? `- review-thread metadata warnings: ${bundle.reviewThreadsWarnings.join(" | ")}`
		: `- review threads: ${bundle.counts.reviewThreads} total, ${bundle.counts.openReviewThreads} open`;

	return [
		`Address PR comments for ${bundle.repo.nameWithOwner} PR #${bundle.pr.number}: ${bundle.pr.title ?? "(untitled)"}`,
		"",
		"The /pr-comment-address extension already fetched the PR discussion into local bundle files:",
		`- Markdown summary: ${mdPath}`,
		`- JSON metadata: ${jsonPath}`,
		"",
		"Quick summary:",
		`- issue comments: ${bundle.counts.issueComments}`,
		`- review comments: ${bundle.counts.reviewComments}`,
		`- reviews: ${bundle.counts.reviews}`,
		reviewThreadLine,
		`- review-comment files: ${pathSummary}`,
		"",
		"Workflow:",
		"1. Read the bundle files first (start with Markdown, use JSON when you need exact metadata).",
		"2. Group comments by file, theme, and likely fixability.",
		"3. Use a scout if needed to locate the relevant code, then use delegate_worker first to apply clearly local and safe fixes.",
		"4. Auto-fix only trivial/local items: typos, formatting, naming, docs, obvious test gaps, and small code changes with a clear requested outcome.",
		"5. Prefer unresolved/open feedback when thread metadata is available; avoid reworking already resolved or outdated comments unless another active comment still requires it.",
		"6. Run targeted validation for each change, then broader repo checks if code changed. Follow the repo validation commands required by AGENTS.",
		"7. Summarize what you fixed and include validation status.",
		"8. Ask the user only about unresolved or ambiguous items.",
		"",
		"Ask the user instead of guessing when comments are architectural, conflicting, unclear, broader than a local patch, or require product/policy judgement.",
		"Preserve comment metadata in your summary for unresolved items so follow-up replies can map back to the right GitHub thread/comment.",
	].join("\n");
}

export default function prCommentAddressExtension(pi: ExtensionAPI) {
	pi.registerCommand(COMMAND, {
		description: "Fetch PR comments into a temp bundle and trigger worker-first addressing. Usage: /pr-comment-address [PR selector]",
		handler: async (args, ctx) => {
			const selector = args.trim() || undefined;
			try {
				ctx.ui.notify("PR comment address: fetching PR metadata and discussion...", "info");
				const parsedSelector = parsePullSelector(selector, ctx.cwd);
				const currentRepo = parsedSelector ? undefined : await resolveCurrentRepo(pi, ctx.signal);
				const pr = await resolvePull(
					pi,
					parsedSelector?.prSelector ?? selector,
					parsedSelector?.repoOverride,
					ctx.signal,
				);
				const repo = parsedSelector?.repo ?? repoFromPrUrl(pr.url, currentRepo!);
				const [issueComments, reviewComments, reviews, reviewThreadResult] = await Promise.all([
					fetchPaginatedArray<IssueComment>(pi, repo, `/repos/${repo.nameWithOwner}/issues/${pr.number}/comments`, ctx.signal),
					fetchPaginatedArray<ReviewComment>(pi, repo, `/repos/${repo.nameWithOwner}/pulls/${pr.number}/comments`, ctx.signal),
					fetchPaginatedArray<Review>(pi, repo, `/repos/${repo.nameWithOwner}/pulls/${pr.number}/reviews`, ctx.signal),
					fetchReviewThreads(pi, repo, pr.number, ctx.signal),
				]);

				if (
					issueComments.length === 0
					&& reviewComments.length === 0
					&& reviews.length === 0
					&& reviewThreadResult.threads.length === 0
				) {
					ctx.ui.notify(`PR #${pr.number} has no comments or reviews to address.`, "info");
					return;
				}

				const bundle: Bundle = {
					generatedAt: new Date().toISOString(),
					selector: selector ?? null,
					repo,
					pr,
					counts: {
						issueComments: issueComments.length,
						reviewComments: reviewComments.length,
						reviews: reviews.length,
						reviewThreads: reviewThreadResult.threads.length,
						openReviewThreads: reviewThreadResult.threads.filter((thread) => !thread.isResolved).length,
					},
					issueComments,
					reviewComments,
					reviews,
					reviewThreads: reviewThreadResult.threads,
					reviewThreadsWarnings: reviewThreadResult.warnings,
				};

				const bundleDir = join(ctx.cwd, CONFIG_DIR_NAME, "agent", "pr-comment-address", `${pr.number}-${Date.now()}-${randomUUID()}`);
				await mkdir(bundleDir, { recursive: true });
				const jsonPath = join(bundleDir, "bundle.json");
				const mdPath = join(bundleDir, "bundle.md");
				await writeFile(jsonPath, `${JSON.stringify(bundle, null, 2)}\n`, "utf8");
				await writeFile(mdPath, `${buildMarkdownBundle(bundle)}\n`, "utf8");

				const prompt = buildAgentPrompt(bundle, jsonPath, mdPath);
				if (ctx.isIdle()) {
					pi.sendUserMessage(prompt);
					ctx.ui.notify(`Started PR #${pr.number} comment-addressing workflow`, "info");
				} else {
					pi.sendUserMessage(prompt, { deliverAs: "followUp" });
					ctx.ui.notify(`Queued PR #${pr.number} comment-addressing workflow as a follow-up`, "info");
				}
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(`PR comment address failed: ${message}`, "error");
			}
		},
	});
}
