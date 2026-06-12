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

export type ExactModelReferenceResolution =
  | { status: "matched"; model: Model<Api> }
  | { status: "invalid" }
  | { status: "ambiguous"; models: Model<Api>[] }
  | { status: "not_found" };

/**
 * Mirrors pi's main-window exact model matching behavior:
 * - accepts provider/model or bare model id
 * - rejects ambiguous bare ids across providers
 */
export function resolveExactModelReference(
  modelReference: string,
  availableModels: Model<Api>[],
): ExactModelReferenceResolution {
  const trimmedReference = modelReference.trim();
  if (!trimmedReference) {
    return { status: "invalid" };
  }

  const normalizedReference = trimmedReference.toLowerCase();
  const canonicalMatches = availableModels.filter(
    (model) => `${model.provider}/${model.id}`.toLowerCase() === normalizedReference,
  );
  if (canonicalMatches.length === 1) {
    return { status: "matched", model: canonicalMatches[0] };
  }
  if (canonicalMatches.length > 1) {
    return { status: "ambiguous", models: canonicalMatches };
  }

  const slashIndex = trimmedReference.indexOf("/");
  if (slashIndex !== -1) {
    const provider = trimmedReference.substring(0, slashIndex).trim();
    const modelId = trimmedReference.substring(slashIndex + 1).trim();
    if (!provider || !modelId) {
      return { status: "invalid" };
    }

    const providerMatches = availableModels.filter(
      (model) =>
        model.provider.toLowerCase() === provider.toLowerCase() &&
        model.id.toLowerCase() === modelId.toLowerCase(),
    );
    if (providerMatches.length === 1) {
      return { status: "matched", model: providerMatches[0] };
    }
    if (providerMatches.length > 1) {
      return { status: "ambiguous", models: providerMatches };
    }
    return { status: "not_found" };
  }

  const idMatches = availableModels.filter(
    (model) => model.id.toLowerCase() === normalizedReference,
  );
  if (idMatches.length === 1) {
    return { status: "matched", model: idMatches[0] };
  }
  if (idMatches.length > 1) {
    return { status: "ambiguous", models: idMatches };
  }
  return { status: "not_found" };
}

export function findExactModelReferenceMatch(
  modelReference: string,
  availableModels: Model<Api>[],
): Model<Api> | undefined {
  const resolved = resolveExactModelReference(modelReference, availableModels);
  return resolved.status === "matched" ? resolved.model : undefined;
}
