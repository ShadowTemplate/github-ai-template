# Setup checklist

GitHub templates copy files, not settings. Do this once per repo created from the template.
Total time: about 15 minutes.

## 0. One-time: make this repo a template

Settings > General > tick **Template repository**. New projects: **Use this template** > *Create a new repository*, then clone it.

## 1. Choose how the agents authenticate to Claude

Set exactly one of these as a repository secret (Settings > Secrets and variables > Actions).

| | `ANTHROPIC_API_KEY` | `CLAUDE_CODE_OAUTH_TOKEN` |
|---|---|---|
| Billing | Pay per token, on the Anthropic Console | Uses your Claude Pro/Max subscription limits |
| Cost predictability | Varies with usage; you can set spend limits in the Console | Flat monthly price, but agent runs consume the same usage allowance as your interactive Claude Code |
| Risk | A runaway loop costs money | A runaway loop exhausts your limits, so you are locked out until they reset |
| Best for | Teams, org repos, anything serious or shared | A personal project you are experimenting with |
| How to get it | https://console.anthropic.com > API keys | Run `claude setup-token` locally and copy the token |

Rule of thumb: start with the subscription token for a personal sandbox. Switch to an API key when the project
matters or other people use it. The workflows accept either, so switching is just a different secret.

## 2. Create the "agent" GitHub App (the identity that opens PRs)

Why: PRs and pushes made with the default `GITHUB_TOKEN` do **not** trigger other workflows, so CI and the reviewer
would never run on agent PRs. A GitHub App token does trigger them.

1. GitHub > Settings > Developer settings > GitHub Apps > **New GitHub App**.
2. Name it, for example `<yourname>-agent`. Homepage URL: your repo URL. Untick **Webhook > Active**.
3. Repository permissions: **Contents** Read & write, **Pull requests** Read & write, **Issues** Read & write.
   Leave everything else at No access (in particular, do not grant *Workflows*).
4. Create it, then **Generate a private key** (downloads a `.pem`) and note the **App ID**.
5. **Install App** on your account/org, restricted to the repositories that use this template.
6. Store in the repo: variable `AGENT_APP_ID`, secret `AGENT_APP_PRIVATE_KEY` (the full `.pem` contents).

For many repos, create the App once and reuse it, or put the values at the organization level.

## 3. Install the Claude GitHub App (the reviewer identity)

Install https://github.com/apps/claude on the repo (or run `/install-github-app` inside Claude Code, which also
offers to add the secret from step 1). The reviewer workflow runs as this app, so it is a different account from your
agent App, which is what lets it approve the PRs your agent App opens.

## 4. Run the bootstrap script

```bash
gh auth login              # if you have not already
export ANTHROPIC_API_KEY=...       # or CLAUDE_CODE_OAUTH_TOKEN
export AGENT_APP_ID=123456
export AGENT_APP_PRIVATE_KEY_FILE=~/Downloads/your-agent.private-key.pem
./scripts/bootstrap.sh
```

It sets squash-only merging with the PR title as commit message, enables auto-merge, creates labels, creates a ruleset
on the default branch (PR required, checks `test` and `pr-title` must pass), and stores whatever secrets/variables you
passed. It lists what is still missing at the end. You can also do everything by hand in Settings.

## 5. Tune the human gates

- **Approvals.** The ruleset starts at 0 required approvals, so the reviewer agent is advisory. Once you have watched it
  approve a few PRs, run `REQUIRED_APPROVALS=1 ./scripts/bootstrap.sh` on a fresh repo, or edit the ruleset
  (Settings > Rules) to require 1 approval. Then a PR only merges after the reviewer agent (or you) approves.
- **Auto-merge.** Default is off, so you press merge. Set repository variable `AGENT_AUTOMERGE` to `true` for fully hands-off merging.
- **Code owners.** Edit `.github/CODEOWNERS` and tick "Require review from Code Owners" in the ruleset so that only you can change
  `.github/`, `CLAUDE.md`, and release config, the files that control the agents.
- **Releases.** Release PRs are opened by release-please and are ordinary PRs. Merging one is the release. Keep this manual at first.

## 6. First test (do this with a throwaway issue)

1. New issue > *Task (agent-ready)*: "feat: add a `farewell(name)` function" with acceptance criteria.
2. Add the label `agent-ready`. Watch Actions > *Agent - implement*.
3. A PR appears. Check that `CI`, `PR title` and `Agent - review` all ran on it. If they did not, the App token (step 2) is the problem.
4. Merge it. `Release` opens a Release PR with a changelog entry under **Features**. Merge that to get `v0.1.0`.
5. Comment `@claude please rename X to Y` on a PR's Conversation tab to test the fix loop.
6. Or leave `@claude fix this` as an inline comment on one line in the "Files changed" tab - the agent
   replies on that same review thread and pushes a fix scoped to that line.

## Troubleshooting

- **Agent PR has no checks:** the PR was opened with `GITHUB_TOKEN`, not the App token. Check `AGENT_APP_ID` / `AGENT_APP_PRIVATE_KEY`.
- **`Could not fetch an OIDC token`:** the job needs `id-token: write` (already set) and the Claude GitHub App must be installed.
- **Reviewer cannot approve or request changes:** fall back to it commenting only (keep required approvals at 0) and read its comments.
- **Release PR does not update / no changelog entries:** commits on `main` are not Conventional Commits. Check the squash-merge settings and the `PR title` check.
- **Runaway cost or loops:** lower `--max-turns` in the workflows, and keep `concurrency` groups in place.

## Security notes

- Issue and PR text is untrusted input to an agent that can write code. The mitigations here: the label needs triage access, `@claude`
  comments are limited to owner/member/collaborator, tool access is an allow-list, `CLAUDE.md` tells agents to distrust that text,
  and CODEOWNERS protects the agent config.
- Do not put production secrets in the repo's Actions secrets that agents do not need.
- Keep the agent App's permissions minimal and never grant it *Workflows* or *Administration*.
