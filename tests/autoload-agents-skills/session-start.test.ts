import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { execSync } from "child_process";
import { join } from "path";
import { existsSync, lstatSync, readlinkSync, mkdirSync } from "fs";
import { rm, writeFile } from "fs/promises";

const HOOK_SCRIPT = join(import.meta.dir, "../../plugins/autoload-agents-skills/hooks/session-start");
const FIXTURES = join(import.meta.dir, "fixtures");
const FAKE_PLUGIN_ROOT = join(import.meta.dir, "../../plugins/autoload-agents-skills");

function runHook(
  fixtureName: string,
  extraEnv?: Record<string, string>
): { stdout: string; exitCode: number } {
  const cwd = join(FIXTURES, fixtureName);
  try {
    const stdout = execSync(`bash "${HOOK_SCRIPT}"`, {
      cwd,
      env: {
        HOME: join(FIXTURES, fixtureName),
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

describe("session-start hook (autoload-agents-skills)", () => {
  it("produces no output when no .agents/skills/ exists", () => {
    const { stdout, exitCode } = runHook("empty");
    expect(exitCode).toBe(0);
    expect(stdout.trim()).toBe("");
  });

  it("notifies about discovered skills when not opted in", () => {
    const { stdout, exitCode } = runHook("discovers-not-opted-in");
    expect(exitCode).toBe(0);
    const parsed = JSON.parse(stdout);
    const ctx: string = parsed.hookSpecificOutput.additionalContext;
    expect(ctx).toContain("# agentSkills");
    expect(ctx).toContain("hello");
    expect(ctx).toContain("Say hello to the world");
    expect(ctx).toContain("/agents-skills-enable");
  });

  it("uses the hookSpecificOutput envelope for Claude Code", () => {
    const { stdout } = runHook("discovers-not-opted-in");
    const parsed = JSON.parse(stdout);
    expect(parsed).toHaveProperty("hookSpecificOutput");
    expect(parsed.hookSpecificOutput.hookEventName).toBe("SessionStart");
    expect(parsed.hookSpecificOutput).toHaveProperty("additionalContext");
  });

  it("uses additional_context envelope for Cursor", () => {
    const { stdout } = runHook("discovers-not-opted-in", {
      CURSOR_PLUGIN_ROOT: FAKE_PLUGIN_ROOT,
    });
    const parsed = JSON.parse(stdout);
    expect(parsed).toHaveProperty("additional_context");
    expect(parsed.additional_context).toContain("# agentSkills");
  });

  it("produces no output when opted in with no changes", () => {
    const { stdout, exitCode } = runHook("opted-in-no-change");
    expect(exitCode).toBe(0);
    expect(stdout.trim()).toBe("");
  });

  it("creates a symlink for a newly discovered skill when opted in", async () => {
    const fixture = join(FIXTURES, "opted-in-new-skill");
    const manifestPath = join(fixture, ".claude", ".agents-skills-managed.json");
    const newLink = join(fixture, ".claude", "skills", "newskill");

    // Always reset to known good state (only "existing" managed, no "newskill")
    const knownGoodManifest = JSON.stringify({
      version: 1,
      managed: [
        { name: "existing", source: ".agents/skills/existing", createdAt: "2026-05-01T00:00:00Z" },
      ],
    }, null, 2);
    await writeFile(manifestPath, knownGoodManifest);
    if (existsSync(newLink)) await rm(newLink);

    try {
      const { stdout, exitCode } = runHook("opted-in-new-skill");
      expect(exitCode).toBe(0);

      const parsed = JSON.parse(stdout);
      const ctx: string = parsed.hookSpecificOutput.additionalContext;
      expect(ctx).toContain("added 1");
      expect(ctx).toContain("newskill");

      expect(lstatSync(newLink).isSymbolicLink()).toBe(true);
      expect(readlinkSync(newLink)).toContain("newskill");
    } finally {
      // Restore manifest and remove symlink so the test is repeatable
      await writeFile(manifestPath, knownGoodManifest);
      if (existsSync(newLink)) await rm(newLink);
    }
  });

  it("removes symlink for a skill whose source directory no longer exists", async () => {
    const fixture = join(FIXTURES, "opted-in-removed");
    const manifestPath = join(fixture, ".claude", ".agents-skills-managed.json");
    const ghostLink = join(fixture, ".claude", "skills", "ghost");
    const skillsDir = join(fixture, ".claude", "skills");

    // Always reset to known good state before running
    const knownGoodManifest = JSON.stringify({
      version: 1,
      managed: [
        { name: "survivor", source: ".agents/skills/survivor", createdAt: "2026-05-01T00:00:00Z" },
        { name: "ghost", source: ".agents/skills/ghost", createdAt: "2026-05-01T00:00:00Z" },
      ],
    }, null, 2);
    mkdirSync(skillsDir, { recursive: true });
    await writeFile(manifestPath, knownGoodManifest);
    execSync(`ln -sfn "../../.agents/skills/ghost" "${ghostLink}"`);

    try {
      const { stdout, exitCode } = runHook("opted-in-removed");
      expect(exitCode).toBe(0);

      const parsed = JSON.parse(stdout);
      const ctx: string = parsed.hookSpecificOutput.additionalContext;
      expect(ctx).toContain("removed 1");
      expect(ctx).toContain("ghost");

      // Ghost symlink gone; survivor still present
      let ghostExists = false;
      try { lstatSync(ghostLink); ghostExists = true; } catch {}
      expect(ghostExists).toBe(false);
      expect(lstatSync(join(fixture, ".claude", "skills", "survivor")).isSymbolicLink()).toBe(true);
    } finally {
      // Restore for repeatability
      await writeFile(manifestPath, knownGoodManifest);
      execSync(`ln -sfn "../../.agents/skills/ghost" "${ghostLink}"`);
    }
  });

  it("skips a skill with missing frontmatter fields", () => {
    const { stdout, exitCode } = runHook("bad-frontmatter");
    expect(exitCode).toBe(0);
    // Since no manifest exists (not opted in), we get a notification listing only valid skills
    const parsed = JSON.parse(stdout);
    const ctx: string = parsed.hookSpecificOutput.additionalContext;
    // "good" is valid and should appear; "broken" has no description and should not
    expect(ctx).toContain("good");
    expect(ctx).not.toContain("broken");
  });

  it("skips a skill where frontmatter name does not match directory name", () => {
    const { stdout, exitCode } = runHook("name-mismatch");
    expect(exitCode).toBe(0);
    // No valid skills found → no output
    expect(stdout.trim()).toBe("");
  });

  it("includes skill count in notification message", () => {
    const { stdout } = runHook("discovers-not-opted-in");
    const parsed = JSON.parse(stdout);
    const ctx: string = parsed.hookSpecificOutput.additionalContext;
    expect(ctx).toContain("Found 1 skill");
  });
});
