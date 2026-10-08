#!/usr/bin/env bash
#
# Print every pin that must agree across the Combine assistant repos, side
# by side, and flag the ones that don't. Read-only. See SKILL.md next to it.
#
# Usage: ./check-sync.sh [BASE_DIR]
#   BASE_DIR  directory holding the sibling repos
#             (default: the parent of combine-assistant)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${1:-$(cd "$HERE/../../.." && pwd)}"

CA="$BASE/combine-assistant"
MCP="$BASE/combine-mcp"
RUN="$BASE/combine-run-mcp"
EVALS="$BASE/combine-assistant-evals"
GRID="$BASE/cms-griddata.cern.ch-cat-sw"
TUTORIAL="${COMBINE_TUTORIAL:-$BASE/combine-dev/pixi_dev/HiggsAnalysis/CombinedLimit/docs/tutorial_ai_agent/ai_agent_tutorial.md}"

mismatches=0

# first_match FILE ERE  -> first match of ERE (grep -o) in FILE, or "-"
first_match() {
  [ -f "$1" ] || { echo "(missing $1)"; return; }
  local m
  m=$(grep -o -E "$2" "$1" | head -1)
  echo "${m:--}"
}

# row LABEL VALUE
row() { printf '  %-58s %s\n' "$1" "$2"; }

# same TITLE VALUE... -> MISMATCH unless all values are identical
same() {
  local title=$1; shift
  local first=$1 v
  for v in "$@"; do
    if [ "$v" != "$first" ]; then
      echo "  >> MISMATCH: $title"
      mismatches=$((mismatches + 1))
      return
    fi
  done
  echo "  ok: $title"
}

TAG_RE='v1[0-9]\.[0-9]+\.[0-9]+'

echo "== Combine version"
c1=$(first_match "$MCP/src/combine_mcp/docs_sources.json" "\"default_branch\": \"$TAG_RE\"" | grep -o -E "$TAG_RE")
c2=$(first_match "$MCP/src/combine_mcp/config.py" "blob/$TAG_RE" | grep -o -E "$TAG_RE")
c3=$(first_match "$MCP/src/combine_mcp/tools/_remote_code_index.py" "\"$TAG_RE\"" | grep -o -E "$TAG_RE")
c4=$(first_match "$RUN/Dockerfile" "combine-standalone:$TAG_RE" | grep -o -E "$TAG_RE")
c5=$(first_match "$CA/config/skills/combine/SKILL.md" "Source tree \($TAG_RE\)" | grep -o -E "$TAG_RE")
c6=$(first_match "$EVALS/.gitlab-ci.yml" "combine_$TAG_RE" | grep -o -E "$TAG_RE")
row "combine-mcp docs_sources.json default_branch" "${c1:--}"
row "combine-mcp config.py blob URL" "${c2:--}"
row "combine-mcp _remote_code_index.py tarball" "${c3:--}"
row "combine-run-mcp Dockerfile COMBINE_IMAGE" "${c4:--}"
row "combine-assistant skill sources table" "${c5:--}"
row "combine-assistant-evals CI IMAGE" "${c6:--}"
same "Combine tag" "${c1:--}" "${c2:--}" "${c3:--}" "${c4:--}" "${c5:--}" "${c6:--}"

echo
echo "== combine-assistant release"
v_file=$(cat "$CA/VERSION" 2>/dev/null || echo -)
v_tag=$(git -C "$CA" describe --tags --abbrev=0 2>/dev/null || echo -)
v_deploy=$(first_match "$GRID/deploy_combine-assistant.sh" 'COMBINE_ASSISTANT_TAG:-v[0-9.]+' | grep -o -E 'v[0-9.]+$')
row "combine-assistant VERSION" "v$v_file"
row "combine-assistant latest tag" "$v_tag"
row "cms-griddata deploy_combine-assistant.sh TAG" "${v_deploy:--}"
same "VERSION = latest tag = deploy TAG" "v$v_file" "$v_tag" "${v_deploy:--}"
ahead=$(git -C "$CA" rev-list --count "$v_tag"..HEAD 2>/dev/null || echo 0)
[ "$ahead" != "0" ] && echo "  note: combine-assistant has $ahead commit(s) after $v_tag (unreleased)"

echo
echo "== MCP server URLs"
u_oc=$(grep -o -E 'https://[^"]+/mcp' "$CA/config/opencode.json" 2>/dev/null | sort | tr '\n' ' ')
u_cc=$(grep -o -E 'https://[^"]+/mcp' "$CA/.mcp.json" 2>/dev/null | sort | tr '\n' ' ')
u_ci=$(grep -o -E 'https://[^" ]+/mcp' "$EVALS/.gitlab-ci.yml" 2>/dev/null | sort -u | tr '\n' ' ')
row "combine-assistant config/opencode.json" "$u_oc"
row "combine-assistant .mcp.json" "$u_cc"
row "combine-assistant-evals CI probe" "$u_ci"
same "opencode.json URLs = .mcp.json URLs" "$u_oc" "$u_cc"
case "$u_oc" in *"$u_ci"*) echo "  ok: CI probe URL is one of the config URLs" ;;
  *) echo "  >> MISMATCH: CI probe URL not in opencode.json"; mismatches=$((mismatches + 1)) ;; esac

echo
echo "== Models"
m_default=$(first_match "$CA/config/opencode.json" '"model": "[^"]+"' | sed 's/.*: "//; s/"$//')
row "combine-assistant default model" "$m_default"
grep -E '^\s+(EVAL_MODEL|JUDGE_MODEL):' "$EVALS/.gitlab-ci.yml" 2>/dev/null | sed 's/^ */  CI  /'
# every aigw/<id> or nrp/<id> CI uses must exist in opencode.json
for m in $(grep -o -E 'EVAL_MODEL: "[^"]+"' "$EVALS/.gitlab-ci.yml" 2>/dev/null | sed 's/.*"\(.*\)"/\1/'); do
  id=${m#*/}
  if grep -q "\"$id\"" "$CA/config/opencode.json"; then echo "  ok: CI agent $m is in opencode.json"
  else echo "  >> MISMATCH: CI agent $m is not in opencode.json"; mismatches=$((mismatches + 1)); fi
done
if [ -f "$TUTORIAL" ]; then
  for id in $(grep -o -E '(gpt-[0-9.]+-[a-z]+-preview|qwen3\.[0-9]+-[0-9a-z-]+)' "$TUTORIAL" | sort -u); do
    grep -q "\"$id\"" "$CA/config/opencode.json" || {
      echo "  >> MISMATCH: tutorial mentions $id, not in opencode.json"; mismatches=$((mismatches + 1)); }
  done
  echo "  tutorial model ids checked against opencode.json"
else
  echo "  (tutorial not found at $TUTORIAL; set COMBINE_TUTORIAL to check it)"
fi

echo
echo "== mcp library"
# the dependency line itself, not a comment that mentions an old range
p1=$(grep -E '^[[:space:]]*"mcp[^"]*",' "$MCP/pyproject.toml" 2>/dev/null | grep -o -E '"mcp[^"]*"' | head -1)
p2=$(grep -E '^[[:space:]]*"mcp[^"]*",' "$RUN/pyproject.toml" 2>/dev/null | grep -o -E '"mcp[^"]*"' | head -1)
row "combine-mcp pyproject.toml" "$p1"
row "combine-run-mcp pyproject.toml" "$p2"
same "mcp range" "$p1" "$p2"

echo
echo "== Git state"
for r in combine-assistant combine-mcp combine-run-mcp combine-assistant-evals cms-griddata.cern.ch-cat-sw combine-mcp-corpus; do
  d="$BASE/$r"
  [ -d "$d/.git" ] || { row "$r" "(not found)"; continue; }
  branch=$(git -C "$d" rev-parse --abbrev-ref HEAD)
  # compare with the upstream, or origin/<branch> when none is set
  upstream='@{u}'
  git -C "$d" rev-parse -q --verify '@{u}' >/dev/null 2>&1 || upstream="origin/$branch"
  up=$(git -C "$d" rev-list --count "$upstream..HEAD" 2>/dev/null || echo "?")
  dirty=$(git -C "$d" status --porcelain | wc -l | tr -d ' ')
  utags=""
  # local tags missing on origin (asks the remote; skipped if unreachable)
  if remote_tags=$(git -C "$d" ls-remote --tags origin 2>/dev/null); then
    utags=$(comm -23 <(git -C "$d" tag | sort) \
                     <(echo "$remote_tags" | sed 's#.*refs/tags/##; s/\^{}//' | sort -u) | tr '\n' ' ')
  fi
  row "$r ($branch)" "unpushed: $up  uncommitted files: $dirty${utags:+  unpushed tags: $utags}"
done

echo
if [ "$mismatches" -eq 0 ]; then echo "No mismatches."; else echo "$mismatches mismatch(es)."; fi
exit "$mismatches"
