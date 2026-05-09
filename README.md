# claude-marketplace

A collection of Claude Code plugins by sirnovikov.

## Plugins

### `autoload-agents-md`

Automatically loads `AGENTS.md` files into your Claude Code session — identical to how `CLAUDE.md` is loaded.

When a session starts, the plugin walks up from your project directory to `$HOME`, finds all `AGENTS.md` files in the hierarchy, and injects their contents as high-priority instructions. Claude treats them with the same weight as `CLAUDE.md`.

This lets teams that use `AGENTS.md` (the convention used by OpenAI, Gemini, and other AI agents) work seamlessly in Claude Code without duplicating instructions.

```bash
claude plugin marketplace add https://github.com/sirnovikov/claude-marketplace
claude plugin install autoload-agents-md@sirnovikov
```

---

### `autoload-agents-skills`

Mirrors `.agents/skills/` entries ([agentskills.io](https://agentskills.io/specification) standard, used by Codex/OpenAI) into `.claude/skills/` via managed symlinks so they're discoverable by Claude Code's native `Skill` tool.

**How it works:**

1. On each session start, the plugin checks for `.agents/skills/` in your project hierarchy
2. If found and not yet enabled, it notifies you and prompts you to run `/agents-skills-enable` (one-time per project)
3. `/agents-skills-enable` creates relative symlinks from `.claude/skills/<name>` → `.agents/skills/<name>`, writes a per-project manifest, and auto-adds the managed paths to `.gitignore`
4. On subsequent sessions, the plugin auto-syncs — adding symlinks for new skills, pruning symlinks for removed ones
5. `/agents-skills-disable` removes all managed symlinks, the gitignore block, and the manifest

Skills in `.agents/skills/` follow the `SKILL.md` frontmatter format: a `name` and `description` field, with the directory name matching `name`.

```bash
claude plugin marketplace add https://github.com/sirnovikov/claude-marketplace
claude plugin install autoload-agents-skills@sirnovikov
```

**Design:** no global state, explicit opt-in, git-clean (symlinks are gitignored automatically), fully reversible, pure bash with no runtime dependencies.

---

## Development

```bash
# Run all tests
bun test --dots

# Install locally
claude plugin marketplace add ./.claude-plugin/marketplace.json
claude plugin install autoload-agents-md@sirnovikov
claude plugin install autoload-agents-skills@sirnovikov
```
