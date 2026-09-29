#!/usr/bin/env bash
# Configure the GitHub settings that a template repo cannot carry over.
# Run once in each new repo created from this template, from inside the clone:
#
#   gh auth login            # once, if needed
#   ./scripts/bootstrap.sh
#
# Optional environment variables:
#   REQUIRED_APPROVALS   approvals needed to merge (default 0; set 1 once the reviewer agent is proven)
#   AGENT_AUTOMERGE      "true" to let agent PRs merge themselves when checks pass (default false)
#   ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN   stored as repo secrets if set
#   AGENT_APP_ID / AGENT_APP_PRIVATE_KEY_FILE     GitHub App id, and path to its .pem file
set -euo pipefail

command -v gh >/dev/null || { echo "gh CLI is required: https://cli.github.com"; exit 1; }

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
APPROVALS=${REQUIRED_APPROVALS:-0}
echo "Configuring $REPO (required approvals: $APPROVALS)"

echo "-> Merge settings: squash only, PR title as commit message, auto-merge allowed, delete merged branches"
gh api -X PATCH "repos/$REPO" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F allow_auto_merge=true \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY >/dev/null

echo "-> Labels"
gh label create agent-ready --color 0E8A16 --description "Ready for an AI agent to implement" --force
gh label create needs-info  --color D93F0B --description "Agent needs clarification before continuing" --force
gh label create bug         --color B60205 --description "Something is broken" --force

echo "-> Ruleset protecting the default branch"
if gh api "repos/$REPO/rulesets" --jq '.[].name' | grep -qx "protect-default-branch"; then
  echo "   already exists, skipping (edit it in Settings > Rules)"
else
  gh api -X POST "repos/$REPO/rulesets" --input - >/dev/null <<JSON
{
  "name": "protect-default-branch",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": $APPROVALS,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "test" }, { "context": "pr-title" } ]
      }
    }
  ]
}
JSON
fi

echo "-> Repository variables and secrets (only those provided in the environment)"
gh variable set AGENT_AUTOMERGE --body "${AGENT_AUTOMERGE:-false}"
[ -n "${AGENT_APP_ID:-}" ]               && gh variable set AGENT_APP_ID --body "$AGENT_APP_ID"
[ -n "${AGENT_APP_PRIVATE_KEY_FILE:-}" ] && gh secret set AGENT_APP_PRIVATE_KEY < "$AGENT_APP_PRIVATE_KEY_FILE"
[ -n "${ANTHROPIC_API_KEY:-}" ]          && gh secret set ANTHROPIC_API_KEY --body "$ANTHROPIC_API_KEY"
[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]    && gh secret set CLAUDE_CODE_OAUTH_TOKEN --body "$CLAUDE_CODE_OAUTH_TOKEN"

echo
echo "Done. Still manual (see SETUP.md): create + install your agent GitHub App, install the Claude GitHub App,"
echo "and add any of the secrets/variables above that you did not pass in. Missing right now:"
have_secrets=$(gh secret list --json name --jq '.[].name')
have_vars=$(gh variable list --json name --jq '.[].name')
for s in AGENT_APP_PRIVATE_KEY; do grep -qx "$s" <<<"$have_secrets" || echo "  secret   $s"; done
grep -qxE "ANTHROPIC_API_KEY|CLAUDE_CODE_OAUTH_TOKEN" <<<"$have_secrets" || echo "  secret   ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN"
grep -qx "AGENT_APP_ID" <<<"$have_vars" || echo "  variable AGENT_APP_ID"
