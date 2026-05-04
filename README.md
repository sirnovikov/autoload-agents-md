# autoload-agents-md

A Claude Code plugin that automatically loads `AGENTS.md` files into your session context — identical to how `CLAUDE.md` is loaded.

## What it does

When you start a Claude Code session, this plugin walks up from your project directory to `$HOME`, finds all `AGENTS.md` files in the hierarchy, and injects their contents as high-priority instructions. Claude treats them with the same weight as `CLAUDE.md`.

This lets teams that use `AGENTS.md` (the convention used by OpenAI, Gemini, and other AI agents) work seamlessly in Claude Code without duplicating instructions.

## Installation

```bash
claude plugin marketplace add https://github.com/sirnovikov/autoload-agents-md
claude plugin install autoload-agents-md@sirnovikov
```

Restart Claude Code after installing.

## Usage

Create an `AGENTS.md` in your project root (or anywhere in the directory hierarchy):

```markdown
# My Project Rules
- Always write tests before implementation
- Use kebab-case for filenames
- Prefer early returns over nested conditionals
```

Start a new Claude Code session in that directory. Claude will automatically read and follow your `AGENTS.md` instructions.

### Hierarchy loading

Like `CLAUDE.md`, multiple `AGENTS.md` files are loaded — one per directory level, root-first. A file in `~/projects/myapp/src/` loads instructions from `~/projects/`, `~/projects/myapp/`, and `~/projects/myapp/src/` in that order.

## How it works

A `SessionStart` hook runs when each session starts. It searches for `AGENTS.md` files from `$PWD` up to `$HOME`, formats them using the same `# claudeMd` header Claude Code uses for `CLAUDE.md`, and injects them as `additionalContext`. Claude receives them as authoritative project instructions.

## Development

```bash
# Run tests
bun test --dots

# Install locally
claude plugin marketplace add ./.claude-plugin/marketplace.json
claude plugin install autoload-agents-md@sirnovikov
```
