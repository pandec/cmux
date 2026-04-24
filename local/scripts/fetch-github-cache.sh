#!/usr/bin/env bash
set -euo pipefail

# Fetches open issues and PRs from manaflow-ai/cmux into .github-cache/
# for fast local searching. Run periodically to refresh.
#
# Usage: ./scripts/fetch-github-cache.sh
# Search: grep -i "emoji" .github-cache/issues.tsv .github-cache/prs.tsv

REPO="manaflow-ai/cmux"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$(dirname "$SCRIPT_DIR")/.github-cache"
# If run from local/scripts/, resolve cache dir relative to repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CACHE_DIR="$REPO_ROOT/local/.github-cache"
mkdir -p "$CACHE_DIR"

echo "==> Fetching open issues..."
gh issue list --repo "$REPO" --state open --limit 1000 \
  --json number,title,labels,createdAt,author,body \
  --jq '.[] | [
    .number,
    .title,
    ([.labels[]?.name] | join(";")),
    (.createdAt | split("T")[0]),
    .author.login,
    (.body[:300] | gsub("\n"; " ") | gsub("\t"; " "))
  ] | @tsv' > "$CACHE_DIR/issues.tsv"

ISSUE_COUNT=$(wc -l < "$CACHE_DIR/issues.tsv" | tr -d ' ')
echo "    $ISSUE_COUNT issues saved"

echo "==> Fetching open PRs..."
gh pr list --repo "$REPO" --state open --limit 1000 \
  --json number,title,labels,createdAt,author,headRefName,additions,deletions,changedFiles,body \
  --jq '.[] | [
    .number,
    .title,
    .headRefName,
    ([.labels[]?.name] | join(";")),
    (.createdAt | split("T")[0]),
    .author.login,
    .additions,
    .deletions,
    .changedFiles,
    (.body[:300] | gsub("\n"; " ") | gsub("\t"; " "))
  ] | @tsv' > "$CACHE_DIR/prs.tsv"

PR_COUNT=$(wc -l < "$CACHE_DIR/prs.tsv" | tr -d ' ')
echo "    $PR_COUNT PRs saved"

echo "==> Fetching recently merged PRs (last 200)..."
gh pr list --repo "$REPO" --state merged --limit 200 \
  --json number,title,labels,mergedAt,author,headRefName,additions,deletions,changedFiles,body \
  --jq '.[] | [
    .number,
    .title,
    .headRefName,
    ([.labels[]?.name] | join(";")),
    (.mergedAt | split("T")[0]),
    .author.login,
    .additions,
    .deletions,
    .changedFiles,
    (.body[:300] | gsub("\n"; " ") | gsub("\t"; " "))
  ] | @tsv' > "$CACHE_DIR/prs-merged.tsv"

MERGED_COUNT=$(wc -l < "$CACHE_DIR/prs-merged.tsv" | tr -d ' ')
echo "    $MERGED_COUNT merged PRs saved"

echo "==> Fetching recently closed (not merged) PRs..."
gh pr list --repo "$REPO" --state closed --limit 200 \
  --json number,title,mergedAt,author,headRefName,body \
  --jq '[.[] | select(.mergedAt == null)] | .[] | [
    .number,
    .title,
    .headRefName,
    (.body[:300] | gsub("\n"; " ") | gsub("\t"; " "))
  ] | @tsv' > "$CACHE_DIR/prs-rejected.tsv"

REJECTED_COUNT=$(wc -l < "$CACHE_DIR/prs-rejected.tsv" | tr -d ' ')
echo "    $REJECTED_COUNT rejected PRs saved"

date -u "+%Y-%m-%dT%H:%M:%SZ" > "$CACHE_DIR/.last-fetched"
echo ""
echo "==> Done. Cache at: $CACHE_DIR"
echo "    Last fetched: $(cat "$CACHE_DIR/.last-fetched")"
echo ""
echo "Search examples:"
echo "  grep -i 'emoji' $CACHE_DIR/issues.tsv $CACHE_DIR/prs.tsv"
echo "  grep -i 'shortcut' $CACHE_DIR/issues.tsv"
echo "  grep -i 'home\|end\|pageup\|pagedown' $CACHE_DIR/issues.tsv"
