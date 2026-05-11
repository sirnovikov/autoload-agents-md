# Consolidate Repos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace two diverged GitHub repos with one (`sirnovikov/claude-marketplace`), backed by a single local directory at `~/repos/read-agents-md-claude-plugin`.

**Architecture:** Fix the one meaningful file difference (version number), force-push the source repo onto `claude-marketplace`, then replace the stale marketplace clone with a symlink to the source dir. `~/.claude/settings.json` already references `claude-marketplace` so no settings change is needed.

**Tech Stack:** git, gh CLI, bash (ln)

---

### Task 1: Fix version and commit

**Files:**
- Modify: `~/repos/read-agents-md-claude-plugin/.claude-plugin/marketplace.json`

- [ ] **Step 1: Edit marketplace.json**

Change `autoload-agents-skills` version from `"0.1.0"` to `"0.2.0"`:

```json
{
  "name": "sirnovikov",
  "description": "sirnovikov's Claude Code plugins",
  "owner": {
    "name": "sirnovikov",
    "email": "noreply@example.com"
  },
  "plugins": [
    {
      "name": "autoload-agents-md",
      "description": "Loads AGENTS.md files from the project hierarchy into Claude's context, identical to how CLAUDE.md is loaded.",
      "version": "0.2.0",
      "source": "./plugins/autoload-agents-md"
    },
    {
      "name": "autoload-agents-skills",
      "description": "Mirrors .agents/skills/ (agentskills.io spec) into .claude/skills/ via managed symlinks so they're discoverable by Claude Code's native Skill tool.",
      "version": "0.2.0",
      "source": "./plugins/autoload-agents-skills"
    }
  ]
}
```

- [ ] **Step 2: Commit**

```bash
cd ~/repos/read-agents-md-claude-plugin
git add .claude-plugin/marketplace.json
git commit -m "chore: bump autoload-agents-skills to 0.2.0"
```

Expected: commit succeeds, `git log --oneline -1` shows the new commit.

---

### Task 2: Retarget remote and force-push

**Files:** git config only (no source files changed)

- [ ] **Step 1: Update remote URL**

```bash
cd ~/repos/read-agents-md-claude-plugin
git remote set-url origin https://github.com/sirnovikov/claude-marketplace.git
```

Verify:
```bash
git remote -v
```
Expected:
```
origin  https://github.com/sirnovikov/claude-marketplace.git (fetch)
origin  https://github.com/sirnovikov/claude-marketplace.git (push)
```

- [ ] **Step 2: Force-push to claude-marketplace**

```bash
git push --force origin main
```

Expected: output shows `+ <sha>...HEAD -> main (forced update)` with no errors.

---

### Task 3: Replace local marketplace clone with symlink

- [ ] **Step 1: Delete the stale clone**

```bash
rm -rf ~/.claude/plugins/marketplaces/sirnovikov
```

- [ ] **Step 2: Create symlink**

```bash
ln -s ~/repos/read-agents-md-claude-plugin ~/.claude/plugins/marketplaces/sirnovikov
```

- [ ] **Step 3: Verify symlink**

```bash
readlink ~/.claude/plugins/marketplaces/sirnovikov
```

Expected: `/Users/i/repos/read-agents-md-claude-plugin`

```bash
cat ~/.claude/plugins/marketplaces/sirnovikov/.claude-plugin/marketplace.json | grep -A2 autoload-agents-skills
```

Expected: shows `"version": "0.2.0"` for autoload-agents-skills.

---

### Task 4: Archive the old GitHub repo

- [ ] **Step 1: Archive sirnovikov/autoload-agents-md**

```bash
gh repo archive sirnovikov/autoload-agents-md --yes
```

Expected: `✓ Archived repository sirnovikov/autoload-agents-md`

- [ ] **Step 2: Confirm end state**

```bash
cd ~/repos/read-agents-md-claude-plugin && git remote -v
```

Expected: both fetch and push show `claude-marketplace.git`.

```bash
ls -la ~/.claude/plugins/marketplaces/
```

Expected: `sirnovikov -> /Users/i/repos/read-agents-md-claude-plugin`
