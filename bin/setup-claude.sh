#!/usr/bin/env bash
#
# combine-assistant setup for Claude Code (the `claude` CLI).
#
# Analogue of bin/setup.sh (which wires opencode/combagent). Claude Code is
# *project-based* rather than env-based, so instead of pointing one env var at a
# config tree, this materializes the assistant's config as a Claude Code PROJECT
# config in a per-user run dir — so `claude` launched from there picks up the
# Combine MCP servers, the combine skill, the persona, and tool permissions,
# with no manual copying.
#
# Source it (works from a local checkout OR read-only CVMFS):
#   source ./bin/setup-claude.sh
#   source /cvmfs/<repo>/<path>/latest/bin/setup-claude.sh
#
# It EXPORTS COMBINE_CLAUDE_DIR (the run dir). Launch Claude Code from there:
#   ( cd "$COMBINE_CLAUDE_DIR" && claude -p "..." --model <model> )
# The eval harness does this for you via `run_agent.py --engine claude`.
#
# Materialized into $COMBINE_CLAUDE_DIR (symlinks track the source; only
# settings.json is generated):
#   .mcp.json                 -> the assistant's MCP server list (.mcp.json)
#   .claude/skills/combine    -> the combine skill (config/skills/combine)
#   CLAUDE.md                 -> the persona (config/AGENTS.md)
#   .claude/settings.json     -> generated: enable project MCP + tool permissions
#
# Auth: Claude Code uses your logged-in Claude subscription (or ANTHROPIC_API_KEY)
# — this script does not manage model keys. Pick the model with `claude --model`.
#
# Overridable:
#   COMBINE_ASSISTANT_CLAUDE_HOME   run dir (default /tmp/<user>-combine-claude)

# --- locate this tree (follow symlinks) ------------------------------------
_cc_src="${BASH_SOURCE[0]:-$0}"
while [ -L "$_cc_src" ]; do
  _cc_dir="$(cd -P "$(dirname "$_cc_src")" >/dev/null 2>&1 && pwd)"
  _cc_src="$(readlink "$_cc_src")"
  [[ "$_cc_src" != /* ]] && _cc_src="$_cc_dir/$_cc_src"
done
_cc_bin="$(cd -P "$(dirname "$_cc_src")" >/dev/null 2>&1 && pwd)"
_cc_root="$(cd -P "$_cc_bin/.." >/dev/null 2>&1 && pwd)"
_cc_config="$_cc_root/config"
_cc_mcp="$_cc_root/.mcp.json"

if [ ! -d "$_cc_config" ] || [ ! -r "$_cc_mcp" ]; then
  echo "ERROR: combine-assistant config/.mcp.json not found under $_cc_root" >&2
  unset _cc_src _cc_dir _cc_bin _cc_root _cc_config _cc_mcp
  return 1 2>/dev/null || exit 1
fi

# --- per-user run dir -------------------------------------------------------
_cc_user="${USER:-$(id -un 2>/dev/null || echo user)}"
COMBINE_CLAUDE_DIR="${COMBINE_ASSISTANT_CLAUDE_HOME:-/tmp/${_cc_user}-combine-claude}"
mkdir -p "$COMBINE_CLAUDE_DIR/.claude/skills" 2>/dev/null || true

# --- materialize project config --------------------------------------------
# MCP servers, skill, persona: symlinks so a newer published version tracks.
ln -sfn "$_cc_mcp"                    "$COMBINE_CLAUDE_DIR/.mcp.json"
ln -sfn "$_cc_config/skills/combine"  "$COMBINE_CLAUDE_DIR/.claude/skills/combine"
ln -sfn "$_cc_config/AGENTS.md"       "$COMBINE_CLAUDE_DIR/CLAUDE.md"

# settings.json (generated): auto-enable the project MCP servers (so headless
# runs don't stall on an approval prompt) and allow the read-only Combine tools
# + the same safe shell commands the opencode config permits.
cat > "$COMBINE_CLAUDE_DIR/.claude/settings.json" <<'JSON'
{
  "enableAllProjectMcpServers": true,
  "permissions": {
    "allow": [
      "mcp__combine",
      "mcp__combine-run-remote",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(ls:*)",
      "Bash(command -v:*)",
      "Bash(which:*)",
      "Bash(combine:*)",
      "Bash(text2workspace.py:*)",
      "Bash(combineCards.py:*)"
    ],
    "ask": ["Bash"]
  }
}
JSON

# --- checks -----------------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  echo "setup-claude WARN: 'claude' (Claude Code CLI) not on PATH — install it" >&2
fi

export COMBINE_CLAUDE_DIR
export COMBINE_ASSISTANT_VERSION="$(cat "$_cc_root/VERSION" 2>/dev/null || echo unknown)"

echo "combine-assistant (Claude Code) v${COMBINE_ASSISTANT_VERSION} ready" >&2
echo "  COMBINE_CLAUDE_DIR=$COMBINE_CLAUDE_DIR" >&2
echo "  launch:  ( cd \"\$COMBINE_CLAUDE_DIR\" && claude -p \"...\" --model <model> )" >&2

unset _cc_src _cc_dir _cc_bin _cc_root _cc_config _cc_mcp _cc_user
