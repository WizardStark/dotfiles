import { type ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function continueHotkey(pi: ExtensionAPI) {
	pi.registerShortcut("alt+c", {
		description: "Send 'Continue' to the agent",
		handler: async (ctx) => {
			const message = "Continue";
			
			if (ctx.isIdle()) {
				pi.sendUserMessage(message);
				ctx.ui.notify("Sent: Continue", "info");
			} else {
				pi.sendUserMessage(message, { deliverAs: "followUp" });
				ctx.ui.notify("Queued: Continue (follow-up)", "info");
			}
		},
	});
}
