#!/usr/bin/env bash
#
# combine-assistant setup script.
#
# Source it (works from any CWD once sourced):
#   Local dev:   source ./bin/setup.sh
#   From CVMFS:  source /cvmfs/<repo>/<path>/latest/bin/setup.sh
#
# Effect:
#   - exports OPENCODE_CONFIG_DIR pointing at this tree's config/, so
#     opencode loads config/opencode.json (providers, model, the Combine
#     MCP servers, permissions) and discovers config/skills/.
#   - exports OPENCODE_DISABLE_PROJECT_CONFIG=1 so a stray .opencode/
#     walked up from CWD doesn't leak in. Comment it out to keep
#     project-local config layering on top.
#   - exports COMBINE_ASSISTANT_VERSION from the VERSION file.
#
# You still supply your own model credential. The default provider is
# the CERN LiteLLM gateway — get your own key and:
#   export LITELLM_API_KEY=<your CERN LiteLLM key>
# (or use the Anthropic provider with ANTHROPIC_API_KEY and switch model).

# Resolve the directory this script lives in, following symlinks.
_ca_src="${BASH_SOURCE[0]:-$0}"
while [ -L "$_ca_src" ]; do
  _ca_dir="$(cd -P "$(dirname "$_ca_src")" >/dev/null 2>&1 && pwd)"
  _ca_src="$(readlink "$_ca_src")"
  [[ "$_ca_src" != /* ]] && _ca_src="$_ca_dir/$_ca_src"
done
_ca_bin="$(cd -P "$(dirname "$_ca_src")" >/dev/null 2>&1 && pwd)"
_ca_root="$(cd -P "$_ca_bin/.." >/dev/null 2>&1 && pwd)"
_ca_config="$_ca_root/config"

if [ ! -d "$_ca_config" ]; then
  echo "ERROR: combine-assistant config not found at $_ca_config" >&2
  unset _ca_src _ca_dir _ca_bin _ca_root _ca_config
  return 1 2>/dev/null || exit 1
fi

export OPENCODE_CONFIG_DIR="$_ca_config"

# Comment the next line out to keep project .opencode/ layering on top.
export OPENCODE_DISABLE_PROJECT_CONFIG=1

if [ -f "$_ca_root/VERSION" ]; then
  COMBINE_ASSISTANT_VERSION="$(cat "$_ca_root/VERSION")"
else
  COMBINE_ASSISTANT_VERSION="unknown"
fi
export COMBINE_ASSISTANT_VERSION

echo "combine-assistant v${COMBINE_ASSISTANT_VERSION} ready"
echo "  OPENCODE_CONFIG_DIR=$OPENCODE_CONFIG_DIR"
echo "  OPENCODE_DISABLE_PROJECT_CONFIG=$OPENCODE_DISABLE_PROJECT_CONFIG"
if [ -z "${LITELLM_API_KEY:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "  NOTE: no model key set. export LITELLM_API_KEY (CERN gateway)" >&2
  echo "        or ANTHROPIC_API_KEY before running opencode." >&2
fi

unset _ca_src _ca_dir _ca_bin _ca_root _ca_config
