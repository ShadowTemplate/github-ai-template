# Agent-driven project template

A GitHub template where AI agents implement issues, open and review PRs, and releases with changelogs happen automatically.
Humans write good issues and make the final calls.

```
Issue ──► Implementer ──► PR ──► CI + PR-title check ──► Reviewer ──► Merge ──► Release PR + changelog
(label     (Claude Code    │                              (Claude      (manual or    (release-please)
 agent-     Action, your   │                               GitHub App)  auto-merge)
 ready)     GitHub App)    └── `@claude fix ...` comment ──► Implementer pushes fixes
```

## Start here

1. Read [SETUP.md](SETUP.md) and follow the checklist. It covers authentication (API key vs subscription), the GitHub Apps,
   and `scripts/bootstrap.sh`.
2. Adapt [CLAUDE.md](CLAUDE.md): commands, architecture, conventions. Agent quality depends on this file.
3. Replace `src/` and `test/` with your project, and update the commands in `CLAUDE.md` and `.github/workflows/ci.yml` if not Node.

## What is where

| File | Purpose |
|---|---|
| `CLAUDE.md` | Standing instructions every agent run reads first |
| `.github/ISSUE_TEMPLATE/` | Forms that force agent-ready issues (goal, acceptance criteria, out of scope) |
| `.github/PULL_REQUEST_TEMPLATE.md` | Structure agents follow for PR bodies |
| `.github/workflows/ci.yml` | Lint, typecheck, tests (required check `test`) |
| `.github/workflows/pr-title.yml` | Enforces Conventional Commit PR titles (required check `pr-title`) |
| `.github/workflows/agent-implement.yml` | Label `agent-ready` or `@claude` comment triggers the implementer |
| `.github/workflows/agent-review.yml` | Reviewer agent on every PR |
| `.github/workflows/release-please.yml` | Release PR, version bump, `CHANGELOG.md`, GitHub Release |
| `release-please-config.json`, `.release-please-manifest.json` | Release configuration |
| `.github/CODEOWNERS` | Human approval for the files that control the agents |
| `.github/dependabot.yml` | Dependency update PRs |
| `scripts/bootstrap.sh` | Applies repo settings, labels, ruleset, secrets |

## Day-to-day

1. Open an issue with the *Task* form. Be specific about acceptance criteria.
2. Add the label `agent-ready`.
3. Review the PR (or let the reviewer agent and auto-merge handle it), then merge.
4. When you want to ship, merge the Release PR.
