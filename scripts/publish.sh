#!/usr/bin/env bash
# Publishes every project folder as its own public repo at
# https://git.devai.io/templates/<folder> — one `git subtree split` per folder,
# pushed to that repo's main.
#
# This monorepo stays the source of truth. A split is deterministic (same
# history in, same commits out), so every run is a fast-forward or a no-op, and
# a lost git.devai.io can be rebuilt by running this again.
#
#   FORGEJO_TOKEN=... scripts/publish.sh               # every project
#   FORGEJO_TOKEN=... scripts/publish.sh tip-calculator todo-list
#
# The token needs write:organization + write:repository (create the repo,
# set its metadata, push). CI runs this on every push to main.
set -euo pipefail

HOST=${FORGEJO_HOST:-https://git.devai.io}
ORG=${FORGEJO_ORG:-templates}
PUSH_USER=${FORGEJO_USER:-devai}
TOKEN=${FORGEJO_TOKEN:?set FORGEJO_TOKEN to a $HOST access token}
REF=${PUBLISH_REF:-HEAD}

cd "$(git rev-parse --show-toplevel)"
[ "$(git rev-parse --is-shallow-repository)" = false ] \
  || { echo "publish: needs full history (git fetch --unshallow)" >&2; exit 1; }

if [ $# -gt 0 ]; then
  projects=("$@")
else
  mapfile -t projects < <(git ls-tree -d --name-only "$REF" | while read -r d; do
    [ "$d" != scripts ] && git cat-file -e "$REF:$d/README.md" 2>/dev/null && echo "$d"
  done)
fi

api() {
  curl -fsS -H "Authorization: token $TOKEN" -H "Content-Type: application/json" "$@"
}

# The README's first paragraph after the title is the repo description.
describe() {
  git show "$REF:$1/README.md" | awk 'NR>1 && NF {sub(/^> ?/, ""); p = p (p ? " " : "") $0; next} p {exit} END {print p}' \
    | sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g; s/[`*]//g' | cut -c1-255
}

auth=$(printf '%s:%s' "$PUSH_USER" "$TOKEN" | base64 -w0)

for p in "${projects[@]}"; do
  git cat-file -e "$REF:$p/README.md" 2>/dev/null || { echo "publish: $p is not a project folder" >&2; exit 1; }

  if ! api "$HOST/api/v1/repos/$ORG/$p" >/dev/null 2>&1; then
    api -X POST "$HOST/api/v1/orgs/$ORG/repos" \
      -d "$(jq -n --arg n "$p" '{name: $n, private: false, default_branch: "main"}')" >/dev/null
    echo "publish: created $ORG/$p"
  fi

  api -X PATCH "$HOST/api/v1/repos/$ORG/$p" -d "$(jq -n \
    --arg d "$(describe "$p")" --arg w "https://devai.io/templates/$p" \
    '{description: $d, website: $w, template: true, has_issues: false, has_wiki: false,
      has_pull_requests: false, has_projects: false, has_releases: false,
      has_packages: false, has_actions: false}')" >/dev/null

  sha=$(git subtree split --quiet --prefix="$p" "$REF")
  git -c http.extraHeader="Authorization: Basic $auth" \
    push --quiet "$HOST/$ORG/$p.git" "$sha:refs/heads/main"
  echo "publish: $ORG/$p @ ${sha:0:7}"
done

# Repos whose folder is gone are left alone (links to them may exist) — just flagged.
if [ $# -eq 0 ]; then
  page=1
  while names=$(api "$HOST/api/v1/orgs/$ORG/repos?limit=50&page=$page" | jq -r '.[].name') && [ -n "$names" ]; do
    echo "$names"; page=$((page + 1))
  done | sort \
    | comm -23 - <(printf '%s\n' "${projects[@]}" | sort) \
    | sed 's/^/publish: WARNING no folder for repo /' >&2
fi
