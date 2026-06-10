import type { Api, Model } from "@earendil-works/pi-ai";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export interface ModelRef {
  provider: string;
  id: string;
}

export function toRef(model?: Model<Api>): ModelRef | undefined {
  if (!model) return undefined;
  return {
    provider: model.provider,
    id: model.id,
  };
}

export function sameModel(a?: ModelRef, b?: ModelRef): boolean {
  return !!a && !!b && a.provider === b.provider && a.id === b.id;
}

export function findModel(ctx: ExtensionContext, ref: ModelRef): Model<Api> | undefined {
  return ctx.modelRegistry.find(ref.provider, ref.id);
}
