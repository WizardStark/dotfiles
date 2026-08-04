import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const CUSTOM = "Type a custom answer…";
const DONE = "Done";

const optionSchema = Type.Object({
  label: Type.String({ maxLength: 60, description: "Short option label" }),
  description: Type.String({ maxLength: 240, description: "Brief explanation or trade-off" }),
});

const questionSchema = Type.Object({
  question: Type.String({ description: "Question to show the user" }),
  header: Type.String({ maxLength: 16, description: "Short category label" }),
  options: Type.Array(optionSchema, { minItems: 2, maxItems: 4 }),
  multiSelect: Type.Optional(Type.Boolean({ description: "Allow more than one option" })),
});

const parameters = Type.Object({
  questions: Type.Array(questionSchema, { minItems: 1, maxItems: 4 }),
});

type Option = { label: string; description: string };
type Question = { question: string; header: string; options: Option[]; multiSelect?: boolean };
type Answer = {
  question: string;
  header: string;
  kind: "option" | "custom" | "multi";
  answer: string | null;
  selected?: string[];
};

function result(text: string, answers: Answer[], cancelled = false) {
  return {
    content: [{ type: "text" as const, text }],
    details: { answers, cancelled },
  };
}

function displayedOptions(options: Option[]): Map<string, string> {
  return new Map(options.map((option) => [
    option.description ? `${option.label} — ${option.description}` : option.label,
    option.label,
  ]));
}

async function selectOne(ctx: ExtensionContext, question: Question, signal?: AbortSignal) {
  const options = displayedOptions(question.options);
  const choice = await ctx.ui.select(question.question, [...options.keys(), CUSTOM], { signal });
  if (choice === undefined || signal?.aborted) return undefined;
  if (choice !== CUSTOM) {
    return { question: question.question, header: question.header, kind: "option" as const, answer: options.get(choice)! };
  }

  const custom = await ctx.ui.input(question.question, "Your answer", { signal });
  if (custom === undefined || signal?.aborted) return undefined;
  return { question: question.question, header: question.header, kind: "custom" as const, answer: custom.trim() };
}

async function selectMany(ctx: ExtensionContext, question: Question, signal?: AbortSignal) {
  const remaining = displayedOptions(question.options);
  const selected: string[] = [];

  while (remaining.size > 0) {
    const choice = await ctx.ui.select(question.question, [...remaining.keys(), CUSTOM, DONE], { signal });
    if (choice === undefined || signal?.aborted) return undefined;
    if (choice === DONE) break;
    if (choice === CUSTOM) {
      const custom = await ctx.ui.input(question.question, "Add an answer", { signal });
      if (custom === undefined || signal?.aborted) return undefined;
      const value = custom.trim();
      if (value) selected.push(value);
      continue;
    }
    selected.push(remaining.get(choice)!);
    remaining.delete(choice);
  }

  return {
    question: question.question,
    header: question.header,
    kind: "multi" as const,
    answer: null,
    selected,
  };
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user_question",
    label: "Ask User Question",
    description: "Ask the user for a concrete decision with 1–4 short multiple-choice questions.",
    promptSnippet: "Ask the user for a necessary decision.",
    promptGuidelines: [
      "Use ask_user_question only when a required decision cannot be inferred safely; group related questions in one call.",
    ],
    parameters,
    executionMode: "sequential",
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      if (!ctx.hasUI) return result("Interactive UI is unavailable; ask the user in chat instead.", [], true);

      const answers: Answer[] = [];
      for (const question of params.questions) {
        if (signal?.aborted) return result("Questionnaire cancelled.", answers, true);
        const answer = question.multiSelect ? await selectMany(ctx, question, signal) : await selectOne(ctx, question, signal);
        if (!answer || signal?.aborted) return result("User cancelled the questions.", answers, true);
        answers.push(answer);
      }
      if (signal?.aborted) return result("Questionnaire cancelled.", answers, true);

      const summary = answers
        .map((answer) => `${JSON.stringify(answer.question)}=${JSON.stringify(answer.selected ?? answer.answer)}`)
        .join("; ");
      return result(`User answered: ${summary}`, answers);
    },
  });
}
