import { describe, it, expect } from "bun:test";
import { execSync } from "child_process";
import { join } from "path";

const HOOK_SCRIPT = join(import.meta.dir, "../hooks/session-start");
const FIXTURES = join(import.meta.dir, "fixtures");
const FAKE_PLUGIN_ROOT = join(import.meta.dir, "..");

function runHook(
  fixtureName: string,
  extraEnv?: Record<string, string>
): { stdout: string; exitCode: number } {
  const cwd = join(FIXTURES, fixtureName);
  try {
    const stdout = execSync(`bash "${HOOK_SCRIPT}"`, {
      cwd,
      env: {
        HOME: join(FIXTURES, fixtureName), // limit walk-up to fixture root
        PATH: process.env.PATH,
        CLAUDE_PLUGIN_ROOT: FAKE_PLUGIN_ROOT,
        ...extraEnv,
      },
      encoding: "utf8",
    });
    return { stdout, exitCode: 0 };
  } catch (err: unknown) {
    const e = err as { stdout?: string; status?: number };
    return { stdout: e.stdout ?? "", exitCode: e.status ?? 1 };
  }
}

describe("session-start hook", () => {
  it("produces no output when no AGENTS.md exists", () => {
    const { stdout, exitCode } = runHook("empty");
    expect(exitCode).toBe(0);
    expect(stdout.trim()).toBe("");
  });

  it("injects AGENTS.md content when file exists in cwd", () => {
    const { stdout, exitCode } = runHook("flat");
    expect(exitCode).toBe(0);
    const parsed = JSON.parse(stdout);
    const context: string = parsed.hookSpecificOutput.additionalContext;
    expect(context).toContain("# claudeMd\n");
    expect(context).toContain("Flat Project Rules");
    expect(context).toContain("Always use tabs");
  });

  it("injects the file path in the context header", () => {
    const { stdout } = runHook("flat");
    const parsed = JSON.parse(stdout);
    const context: string = parsed.hookSpecificOutput.additionalContext;
    expect(context).toContain("AGENTS.md");
    expect(context).toContain("(project agent instructions):");
  });

  it("finds AGENTS.md in a parent directory when cwd has none", () => {
    // Set HOME to nested/ so the walk stops there; run from nested/child/
    const { stdout, exitCode } = runHook("nested/child", {
      HOME: join(FIXTURES, "nested"),
    });
    expect(exitCode).toBe(0);
    const parsed = JSON.parse(stdout);
    const context: string = parsed.hookSpecificOutput.additionalContext;
    expect(context).toContain("Parent Rules");
  });

  it("collects multiple AGENTS.md files from the hierarchy (root first)", () => {
    // Run from multi/sub/ with HOME at multi/
    const { stdout } = runHook("multi/sub", {
      HOME: join(FIXTURES, "multi"),
    });
    const parsed = JSON.parse(stdout);
    const context: string = parsed.hookSpecificOutput.additionalContext;
    // Both files present
    expect(context).toContain("Root Rules");
    expect(context).toContain("Sub Rules");
    // Root appears before sub (root-first ordering)
    expect(context.indexOf("Root Rules")).toBeLessThan(
      context.indexOf("Sub Rules")
    );
  });

  it("correctly escapes special JSON characters", () => {
    const { stdout } = runHook("special-chars");
    // Must parse without throwing — that is the core assertion
    const parsed = JSON.parse(stdout);
    const context: string = parsed.hookSpecificOutput.additionalContext;
    expect(context).toContain("double quotes");
    expect(context).toContain("backslash");
  });

  it("emits additional_context key when CURSOR_PLUGIN_ROOT is set", () => {
    const { stdout } = runHook("flat", {
      CURSOR_PLUGIN_ROOT: FAKE_PLUGIN_ROOT,
    });
    const parsed = JSON.parse(stdout);
    expect(parsed).toHaveProperty("additional_context");
    expect(parsed).not.toHaveProperty("hookSpecificOutput");
  });
});
