import { basename } from "node:path";
import type { ThinkingLevel } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import {
  createStatuslineItem,
  getStatuslineSessionKey,
  listStatuslineItems,
  subscribeStatusline,
  type StatuslineBackground,
  type StatuslineItem,
} from "./registry";

type StyledItem = StatuslineItem & {
  background: StatuslineBackground;
  rendered: string;
  compactRendered?: string;
};

const DEFAULT_BG_ANSI = "\x1b[49m";

const modelItem = createStatuslineItem({
  id: "statusline:model",
  side: "right",
  order: 10,
  importance: 100,
  background: "selectedBg",
});

const reasoningItem = createStatuslineItem({
  id: "statusline:reasoning",
  side: "right",
  order: 20,
  importance: 90,
  background: "customMessageBg",
});

const LEFT_BACKGROUNDS: StatuslineBackground[] = [
  "selectedBg",
  "customMessageBg",
  "userMessageBg",
  "toolPendingBg",
  "toolSuccessBg",
  "toolErrorBg",
];

const RIGHT_BACKGROUNDS: StatuslineBackground[] = ["selectedBg", "customMessageBg", "userMessageBg"];

function bgAnsiToFgAnsi(ansi: string) {
  return ansi.replace(/\[48;/g, "[38;").replace(/\[48m/g, "[38m");
}

function renderSegment(
  theme: ExtensionContext["ui"]["theme"],
  content: string,
  background: StatuslineBackground,
) {
  return theme.bg(background, ` ${content} `);
}

function renderRightDivider(
  theme: ExtensionContext["ui"]["theme"],
  fromBackground: StatuslineBackground,
  toBackground?: StatuslineBackground,
) {
  const toBgAnsi = toBackground ? theme.getBgAnsi(toBackground) : DEFAULT_BG_ANSI;
  const fromFgAnsi = bgAnsiToFgAnsi(theme.getBgAnsi(fromBackground));
  return `${toBgAnsi}${fromFgAnsi}`;
}

function renderLeftDivider(
  theme: ExtensionContext["ui"]["theme"],
  fromBackground: StatuslineBackground | undefined,
  toBackground: StatuslineBackground,
) {
  const fromBgAnsi = fromBackground ? theme.getBgAnsi(fromBackground) : DEFAULT_BG_ANSI;
  const toFgAnsi = bgAnsiToFgAnsi(theme.getBgAnsi(toBackground));
  return `${fromBgAnsi}${toFgAnsi}`;
}

function renderInlineSeparator(
  theme: ExtensionContext["ui"]["theme"],
  background: StatuslineBackground,
  side: "left" | "right",
) {
  const glyph = side === "left" ? "" : "";
  return theme.bg(background, theme.fg("text", glyph));
}

function thinkingTone(level: ThinkingLevel) {
  switch (level) {
    case "minimal":
      return "thinkingMinimal" as const;
    case "low":
      return "thinkingLow" as const;
    case "medium":
      return "thinkingMedium" as const;
    case "high":
      return "thinkingHigh" as const;
    case "xhigh":
      return "thinkingXhigh" as const;
    default:
      return "thinkingOff" as const;
  }
}

function formatModel(ctx: ExtensionContext) {
  const provider = ctx.model?.provider ?? "no-provider";
  const id = ctx.model?.id ?? "no-model";
  return {
    full: `${provider}/${id}`,
    compact: id,
  };
}

function renderBuiltinSegments(pi: ExtensionAPI, ctx: ExtensionContext) {
  const sessionKey = getStatuslineSessionKey(ctx);
  const model = formatModel(ctx);

  modelItem.set(
    {
      content: `${ctx.ui.theme.fg("accent", "M")}${ctx.ui.theme.fg("text", ` ${model.full}`)}`,
      compactContent: `${ctx.ui.theme.fg("accent", "M")}${ctx.ui.theme.fg("text", ` ${model.compact}`)}`,
    },
    sessionKey,
  );

  const level = pi.getThinkingLevel();
  const tone = thinkingTone(level);
  const label = level === "off" ? "off" : level;

  reasoningItem.set(
    {
      content: `${ctx.ui.theme.fg(tone, "R")}${ctx.ui.theme.fg("dim", ` ${label}`)}`,
      compactContent: `${ctx.ui.theme.fg(tone, "R")}${ctx.ui.theme.fg("dim", ` ${label}`)}`,
    },
    sessionKey,
  );
}

function compareItems(left: StatuslineItem, right: StatuslineItem) {
  const leftSide = left.side ?? "right";
  const rightSide = right.side ?? "right";
  if (leftSide !== rightSide) {
    return leftSide.localeCompare(rightSide);
  }

  const orderCompare = (left.order ?? 0) - (right.order ?? 0);
  if (orderCompare !== 0) {
    return orderCompare;
  }

  return left.id.localeCompare(right.id);
}

function buildBuiltinItems(
  ctx: ExtensionContext,
  theme: ExtensionContext["ui"]["theme"],
  footerData: { getGitBranch(): string | null },
): StatuslineItem[] {
  const items: StatuslineItem[] = [
    {
      id: "statusline:directory",
      side: "left",
      order: 0,
      importance: 100,
      background: "selectedBg",
      content: `${theme.fg("accent", "")}${theme.fg("text", ` ${basename(ctx.cwd) || ctx.cwd}`)}`,
      compactContent: `${theme.fg("accent", "")}${theme.fg("text", ` ${basename(ctx.cwd) || ctx.cwd}`)}`,
    },
  ];

  const branch = footerData.getGitBranch();
  if (branch) {
    items.push({
      id: "statusline:branch",
      side: "left",
      order: 5,
      importance: 95,
      background: "customMessageBg",
      content: `${theme.fg("accent", "")}${theme.fg("text", ` ${branch}`)}`,
      compactContent: `${theme.fg("accent", "")}${theme.fg("text", ` ${branch}`)}`,
    });
  }

  return items;
}

function assignBackgrounds(
  theme: ExtensionContext["ui"]["theme"],
  items: StatuslineItem[],
  palette: StatuslineBackground[],
) {
  return items.map<StyledItem>((item, index) => {
    const background = item.background ?? palette[index % palette.length] ?? "selectedBg";
    return {
      ...item,
      background,
      rendered: renderSegment(theme, item.content, background),
      compactRendered: item.compactContent ? renderSegment(theme, item.compactContent, background) : undefined,
    };
  });
}

function toStyledItems(
  theme: ExtensionContext["ui"]["theme"],
  sessionKey: string,
  builtins: StatuslineItem[],
) {
  const combined = [...builtins, ...listStatuslineItems(sessionKey)].sort(compareItems);
  const left = combined.filter((item) => item.side === "left");
  const right = combined.filter((item) => item.side !== "left");
  return {
    left: assignBackgrounds(theme, left, LEFT_BACKGROUNDS),
    right: assignBackgrounds(theme, right, RIGHT_BACKGROUNDS),
  };
}

function renderLeftChain(theme: ExtensionContext["ui"]["theme"], items: StyledItem[]) {
  if (items.length === 0) {
    return "";
  }

  let rendered = "";
  for (let index = 0; index < items.length; index++) {
    const current = items[index]!;
    const next = items[index + 1];
    rendered += current.rendered;

    if (!next) {
      rendered += renderRightDivider(theme, current.background);
      continue;
    }

    if (current.background === next.background) {
      rendered += renderInlineSeparator(theme, current.background, "right");
      continue;
    }

    rendered += renderRightDivider(theme, current.background, next.background);
  }
  return rendered;
}

function renderRightChain(theme: ExtensionContext["ui"]["theme"], items: StyledItem[]) {
  if (items.length === 0) {
    return "";
  }

  let rendered = "";
  for (let index = 0; index < items.length; index++) {
    const previous = items[index - 1];
    const current = items[index]!;

    if (!previous) {
      rendered += renderLeftDivider(theme, undefined, current.background);
    } else if (previous.background === current.background) {
      rendered += renderInlineSeparator(theme, current.background, "left");
    } else {
      rendered += renderLeftDivider(theme, previous.background, current.background);
    }

    rendered += current.rendered;
  }
  return rendered;
}

function measureWidth(theme: ExtensionContext["ui"]["theme"], left: StyledItem[], right: StyledItem[]) {
  const leftText = renderLeftChain(theme, left);
  const rightText = renderRightChain(theme, right);
  return visibleWidth(leftText) + visibleWidth(rightText) + (leftText && rightText ? 1 : 0);
}

function compressItems(
  theme: ExtensionContext["ui"]["theme"],
  left: StyledItem[],
  right: StyledItem[],
  maxWidth: number,
) {
  const compressedLeft = left.map((item) => ({ ...item }));
  const compressedRight = right.map((item) => ({ ...item }));

  const compactCandidates = [...compressedLeft, ...compressedRight]
    .filter((item) => item.compactRendered && item.compactRendered !== item.rendered)
    .sort((leftItem, rightItem) => {
      const importanceCompare = (leftItem.importance ?? 0) - (rightItem.importance ?? 0);
      if (importanceCompare !== 0) return importanceCompare;

      return visibleWidth(leftItem.rendered) - visibleWidth(rightItem.rendered);
    });

  for (const candidate of compactCandidates) {
    if (measureWidth(theme, compressedLeft, compressedRight) <= maxWidth) {
      break;
    }

    const collection = candidate.side === "left" ? compressedLeft : compressedRight;
    const current = collection.find((item) => item.id === candidate.id);
    if (current?.compactRendered) {
      current.rendered = current.compactRendered;
    }
  }

  const removable = [...compressedLeft, ...compressedRight].sort((leftItem, rightItem) => {
    const importanceCompare = (leftItem.importance ?? 0) - (rightItem.importance ?? 0);
    if (importanceCompare !== 0) return importanceCompare;

    return (rightItem.side === "left" ? 1 : 0) - (leftItem.side === "left" ? 1 : 0);
  });

  for (const candidate of removable) {
    if (measureWidth(theme, compressedLeft, compressedRight) <= maxWidth) {
      break;
    }

    const collection = candidate.side === "left" ? compressedLeft : compressedRight;
    const index = collection.findIndex((item) => item.id === candidate.id);
    if (index >= 0) {
      collection.splice(index, 1);
    }
  }

  return { left: compressedLeft, right: compressedRight };
}

function renderFooterLine(
  width: number,
  theme: ExtensionContext["ui"]["theme"],
  left: StyledItem[],
  right: StyledItem[],
) {
  if (left.length === 0 && right.length === 0) {
    return [""];
  }

  const compressed = compressItems(theme, left, right, width);
  const leftText = renderLeftChain(theme, compressed.left);
  const rightText = renderRightChain(theme, compressed.right);
  const leftWidth = visibleWidth(leftText);
  const rightWidth = visibleWidth(rightText);

  if (!leftText) {
    return [truncateToWidth(rightText, width)];
  }

  if (!rightText) {
    return [truncateToWidth(leftText, width)];
  }

  const gap = width - leftWidth - rightWidth;
  if (gap >= 1) {
    return [leftText + " ".repeat(gap) + rightText];
  }

  if (leftWidth >= width) {
    return [truncateToWidth(leftText, width)];
  }

  const availableRight = Math.max(0, width - leftWidth - 1);
  return [truncateToWidth(`${leftText} ${truncateToWidth(rightText, availableRight)}`, width)];
}

export default function statusline(pi: ExtensionAPI) {
  let currentSessionKey = "ephemeral";

  pi.on("session_start", async (_event, ctx) => {
    currentSessionKey = getStatuslineSessionKey(ctx);
    renderBuiltinSegments(pi, ctx);

    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsubscribeStatusline = subscribeStatusline(() => tui.requestRender());
      const unsubscribeBranch = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose() {
          unsubscribeStatusline();
          unsubscribeBranch();
        },
        invalidate() {
          renderBuiltinSegments(pi, ctx);
        },
        render(width: number) {
          const builtins = buildBuiltinItems(ctx, theme, footerData);
          const { left, right } = toStyledItems(theme, currentSessionKey, builtins);
          return renderFooterLine(width, theme, left, right);
        },
      };
    });
  });

  pi.on("model_select", async (_event, ctx) => {
    renderBuiltinSegments(pi, ctx);
  });

  pi.on("thinking_level_select", async (_event, ctx) => {
    renderBuiltinSegments(pi, ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    const sessionKey = getStatuslineSessionKey(ctx);
    modelItem.clear(sessionKey);
    reasoningItem.clear(sessionKey);
    ctx.ui.setFooter(undefined);
  });
}
