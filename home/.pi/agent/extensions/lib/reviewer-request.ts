import type { ThinkingLevel } from "@earendil-works/pi-agent-core";
import type { Model, Api } from "@earendil-works/pi-ai";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { SubagentRunState } from "./subagent-runtime.ts";

// One no-tools request, using provider-native request-time auth and cancellation.
export async function runReviewerRequest(
  registry: ExtensionContext["modelRegistry"],
  model: Model<Api>, thinkingLevel: ThinkingLevel, systemPrompt: string, prompt: string,
  signal?: AbortSignal, onProgress?: (phase: string) => void,
): Promise<SubagentRunState> {
  signal?.throwIfAborted();
  const state: SubagentRunState = {
    messages: [], streamedText: "", stderr: "", exitCode: 0, providerRequestStartedAt: Date.now(),
  };
  onProgress?.("thinking");
  const stream = registry.streamSimple(model, {
    systemPrompt,
    messages: [{ role: "user", content: [{ type: "text", text: prompt }], timestamp: Date.now() }],
    tools: [],
  }, { reasoning: thinkingLevel === "off" ? undefined : thinkingLevel, signal });
  for await (const event of stream) {
    if (event.type === "text_delta" || event.type === "text_end") {
      state.firstTextAt ??= Date.now();
      onProgress?.("responding");
    }
  }
  const response = await stream.result();
  state.messages.push(response);
  state.assistantCompletedAt = Date.now();
  state.finishedAt = Date.now();
  state.stopReason = signal?.aborted ? "aborted" : response.stopReason;
  state.errorMessage = response.errorMessage;
  state.exitCode = state.stopReason === "error" || state.stopReason === "aborted" ? 1 : 0;
  return state;
}
