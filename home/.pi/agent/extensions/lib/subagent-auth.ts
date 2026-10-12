import type { Api, Model, ProviderHeaders } from "@earendil-works/pi-ai";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export type SubagentAuth = {
  apiKey?: string;
  headers?: ProviderHeaders;
  baseUrl?: string;
  env?: Record<string, string>;
};

export async function resolveSubagentAuth(ctx: ExtensionContext, model: Model<Api>): Promise<SubagentAuth> {
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
  if (!auth.ok) throw new Error(`Unable to resolve subagent authentication: ${auth.error}`);
  // The child owns subscription/OAuth resolution. Never forward a derived token.
  if (ctx.modelRegistry.isUsingOAuth(model)) return {};
  return { apiKey: auth.apiKey, headers: auth.headers, baseUrl: auth.baseUrl, env: auth.env };
}
