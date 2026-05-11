# Consolidate to Single Repo

**Date:** 2026-05-11

## Goal

Eliminate the redundant `sirnovikov/autoload-agents-md` GitHub repo and `~/.claude/plugins/marketplaces/sirnovikov` local clone. End state: one GitHub repo (`sirnovikov/claude-marketplace`), one local directory (`~/repos/read-agents-md-claude-plugin`), a symlink making Claude Code's marketplace path point there.

## Current State

| | Source repo | Marketplace repo |
|---|---|---|
| Local path | `~/repos/read-agents-md-claude-plugin` | `~/.claude/plugins/marketplaces/sirnovikov` |
| GitHub remote | `sirnovikov/autoload-agents-md` | `sirnovikov/claude-marketplace` |
| Referenced by | active development | `~/.claude/settings.json` |
| `autoload-agents-skills` version | 0.1.0 | 0.2.0 |

The repos share a common ancestor (`f3309ab`) and diverged by one commit each. All meaningful content is in the source repo; the marketplace's extra commit only bumped a version number.

## Steps

1. Fix `~/repos/read-agents-md-claude-plugin/.claude-plugin/marketplace.json`: bump `autoload-agents-skills` from `0.1.0` → `0.2.0`
2. Commit: `chore: bump autoload-agents-skills to 0.2.0`
3. Update remote: `git remote set-url origin https://github.com/sirnovikov/claude-marketplace.git`
4. Force-push: `git push --force origin main`
5. Delete marketplace clone: `rm -rf ~/.claude/plugins/marketplaces/sirnovikov`
6. Symlink: `ln -s ~/repos/read-agents-md-claude-plugin ~/.claude/plugins/marketplaces/sirnovikov`
7. Archive `sirnovikov/autoload-agents-md` on GitHub via `gh repo archive sirnovikov/autoload-agents-md`

## Verification

- `~/.claude/settings.json` already references `claude-marketplace.git` — no change needed
- Source README already says `claude plugin marketplace add https://github.com/sirnovikov/claude-marketplace` — no change needed
- After symlink: `readlink ~/.claude/plugins/marketplaces/sirnovikov` → `~/repos/read-agents-md-claude-plugin`
- `git remote -v` in either path shows `claude-marketplace`
