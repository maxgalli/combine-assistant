#!/usr/bin/env bash
#
# combine-assistant setup.
#
# Source it (works from any CWD; a local checkout OR read-only CVMFS):
#   source ./bin/setup.sh
#   source /cvmfs/<repo>/<path>/latest/bin/setup.sh
#
# What it does:
#   1. Ensures `opencode` is on PATH. If it isn't already installed, it
#      borrows the combagent binary published on CVMFS (default:
#      /cvmfs/cms-griddata.cern.ch/cat/sw/combagent/latest/bin).
#      combagent is our rebranded opencode build. Override the location
#      with COMBINE_ASSISTANT_OPENCODE_BIN=/path/to/dir.
#   2. Points OPENCODE_CONFIG_DIR at this tree's config/ (providers,
#      default model, the Combine MCP servers, permissions, skills,
#      persona). opencode WRITES into that dir (it installs a plugin
#      runtime), so when config/ is read-only (CVMFS) it is copied to a
#      per-user writable dir first; a writable checkout is used in place.
#   3. Applies the CVMFS/EOS hardening: the opencode DB goes on local fs
#      (EOS doesn't support SQLite WAL), autoupdate is disabled (versions
#      come from CVMFS), and a per-user scratch dir is created.
#
# You bring your own model key: LITELLM_API_KEY (CERN LiteLLM gateway,
# the default provider) or ANTHROPIC_API_KEY.
#
# Overridable knobs:
#   COMBINE_ASSISTANT_OPENCODE_BIN  dir containing the opencode binary
#   COMBINE_ASSISTANT_HOME          per-user writable base (default /tmp/...)

# --- locate this tree (follow symlinks) ------------------------------------
_ca_src="${BASH_SOURCE[0]:-$0}"
while [ -L "$_ca_src" ]; do
  _ca_dir="$(cd -P "$(dirname "$_ca_src")" >/dev/null 2>&1 && pwd)"
  _ca_src="$(readlink "$_ca_src")"
  [[ "$_ca_src" != /* ]] && _ca_src="$_ca_dir/$_ca_src"
done
_ca_bin="$(cd -P "$(dirname "$_ca_src")" >/dev/null 2>&1 && pwd)"
_ca_root="$(cd -P "$_ca_bin/.." >/dev/null 2>&1 && pwd)"
_ca_config_src="$_ca_root/config"

if [ ! -d "$_ca_config_src" ]; then
  echo "ERROR: combine-assistant config not found at $_ca_config_src" >&2
  unset _ca_src _ca_dir _ca_bin _ca_root _ca_config_src
  return 1 2>/dev/null || exit 1
fi

# --- per-user writable scratch (CVMFS is read-only; EOS breaks SQLite WAL) --
_ca_user="${USER:-$(id -un 2>/dev/null || echo user)}"
_ca_data="${COMBINE_ASSISTANT_HOME:-/tmp/${_ca_user}-combine-assistant}"
mkdir -p "$_ca_data" 2>/dev/null || true

# --- ensure `opencode` is available ----------------------------------------
if ! command -v opencode >/dev/null 2>&1; then
  # Borrow a published opencode binary (default: combagent's CVMFS bin).
  _ca_ocbin="${COMBINE_ASSISTANT_OPENCODE_BIN:-/cvmfs/cms-griddata.cern.ch/cat/sw/combagent/latest/bin}"
  if [ -x "${_ca_ocbin}/opencode" ]; then
    case ":${PATH}:" in
      *":${_ca_ocbin}:"*) ;;
      *) export PATH="${_ca_ocbin}:${PATH}" ;;
    esac
  fi
fi

# --- OPENCODE_CONFIG_DIR must be writable (opencode installs a plugin there)-
if [ -w "$_ca_config_src" ]; then
  # Writable checkout: use in place so local edits are picked up live.
  export OPENCODE_CONFIG_DIR="$_ca_config_src"
else
  # Read-only (CVMFS): copy to a per-user writable dir on every source, so
  # a new published version is refreshed.
  _ca_cfg="${_ca_data}/config"
  mkdir -p "$_ca_cfg"
  cp -a "${_ca_config_src}/." "$_ca_cfg/" 2>/dev/null || true
  export OPENCODE_CONFIG_DIR="$_ca_cfg"
fi

# --- CVMFS/EOS hardening ----------------------------------------------------
export OPENCODE_DISABLE_PROJECT_CONFIG=1   # ignore a stray .opencode/ from CWD
export OPENCODE_DISABLE_AUTOUPDATE=1       # versions are managed via CVMFS
export OPENCODE_DB="${_ca_data}/opencode.db"  # off EOS (SQLite WAL needs local fs)

# --- version ---------------------------------------------------------------
export COMBINE_ASSISTANT_VERSION="$(cat "$_ca_root/VERSION" 2>/dev/null || echo unknown)"

echo "combine-assistant v${COMBINE_ASSISTANT_VERSION} ready"
echo "  OPENCODE_CONFIG_DIR=$OPENCODE_CONFIG_DIR"
if ! command -v opencode >/dev/null 2>&1; then
  echo "  NOTE: 'opencode' not found on PATH. Install it, or set" >&2
  echo "        COMBINE_ASSISTANT_OPENCODE_BIN to a dir containing it." >&2
fi
if [ -z "${LITELLM_API_KEY:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "  NOTE: no model key set. Export LITELLM_API_KEY (CERN gateway)" >&2
  echo "        or ANTHROPIC_API_KEY before running opencode." >&2
fi

unset _ca_src _ca_dir _ca_bin _ca_root _ca_config_src \
      _ca_user _ca_data _ca_cfg _ca_ocbin
