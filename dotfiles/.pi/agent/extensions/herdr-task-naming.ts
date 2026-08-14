// Auto-set herdr pane task from first user input or goal creation
// ponytail: minimal viable hook — no LLM summarization, just truncate
import { execFileSync } from "node:child_process";

const HERDR_ENV = process.env.HERDR_ENV;
const paneId = process.env.HERDR_PANE_ID;
const MAX_TASK_LEN = 60;

function enabled(): boolean {
  return HERDR_ENV === "1" && !!paneId;
}

function truncate(text: string, max: number): string {
  const clean = text.replace(/\s+/g, " ").trim();
  if (clean.length <= max) return clean;
  return clean.slice(0, max - 1) + "…";
}

function setTask(task: string, title?: string): void {
  if (!enabled()) return;
  try {
    const args = [
      "pane", "report-metadata", paneId!,
      "--source", "pi:auto-task",
      "--agent", "pi",
      "--token", `task=${task}`,
    ];
    if (title) {
      args.push("--title", title);
    }
    execFileSync("herdr", args, { encoding: "utf8", timeout: 2000 });
  } catch {
    // Optional — cosmetic naming shouldn't break the session
  }
}

export default function(pi: any): void {
  if (!enabled()) return;

  let taskSet = false;

  // Hook: first user input → set task
  pi.on("input", (event: any) => {
    if (taskSet) return;
    const content = event?.text ?? event?.content;
    if (typeof content !== "string" || !content.trim()) return;
    // Skip slash commands
    if (content.trim().startsWith("/")) return;

    taskSet = true;
    const task = truncate(content, MAX_TASK_LEN);
    setTask(task);
  });

  // Hook: goal tool result → update task with goal objective
  pi.on("tool_result", (event: any) => {
    const toolName = event?.toolName ?? event?.name;
    if (toolName !== "create_goal" && toolName !== "pi__create_goal") return;

    // Parse the result to find the objective
    const result = event?.result ?? event?.content;
    if (typeof result !== "string") return;

    // Look for objective in the result
    const match = result.match(/objective[:\s]+["']?([^"'\n]+)/i);
    if (match?.[1]) {
      taskSet = true;
      const task = truncate(match[1], MAX_TASK_LEN);
      setTask(task, task);
    }
  });

  // Hook: before_agent_start with goal context
  pi.on("before_agent_start", (event: any) => {
    // Check if there's a goal in the context
    const goal = event?.goal ?? event?.context?.goal;
    if (!goal?.objective) return;
    if (typeof goal.objective !== "string") return;

    taskSet = true;
    const task = truncate(goal.objective, MAX_TASK_LEN);
    setTask(task, task);
  });
}
