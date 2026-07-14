#!/bin/bash
# combine-run-local — per-user Combine execution MCP server (stdio),
# running inside the official CMS combine-container apptainer image.
#
# Registered in config/opencode.json; the client spawns one instance
# per session and talks MCP over stdin/stdout. Combine comes from the
# container image; the MCP server runs from a Python 3.11 venv
# published on CVMFS (the image itself only has Python 3.9).
#
# Requirements (all present on lxplus): apptainer, and the CVMFS repos
# unpacked.cern.ch, cms.cern.ch, cms-griddata.cern.ch. Where they are
# missing this script exits with a message on stderr; the client just
# reports the server as unavailable and the skill falls back to the
# remote execution server.
#
# IMPORTANT: nothing before the final exec may write to STDOUT — that
# is the MCP protocol channel. Diagnostics go to stderr.

IMAGE=/cvmfs/unpacked.cern.ch/gitlab-registry.cern.ch/cms-analysis/general/combine-container:CMSSW_14_1_0_pre4-combine_v10.6.0-harvester_v3.1.0
VENV=/cvmfs/cms-griddata.cern.ch/cat/sw/combine-run-mcp/latest/venv
CMSSW_SRC=/home/cmsusr/CMSSW_14_1_0_pre4/src

err() { echo "combine-run-local: $*" >&2; exit 1; }

command -v apptainer >/dev/null 2>&1 \
  || err "apptainer not found on this machine"
[ -e /cvmfs/cms.cern.ch/cmsset_default.sh ] \
  || err "/cvmfs/cms.cern.ch not mounted"
[ -d "$IMAGE" ] \
  || err "container image not available (/cvmfs/unpacked.cern.ch not mounted?)"
[ -x "$VENV/bin/combine-run-mcp" ] \
  || err "server venv not available (/cvmfs/cms-griddata.cern.ch not mounted, or combine-run-mcp not deployed?)"

# Bind what exists; /eos and /afs are optional so this also works on
# nodes that don't mount them.
BINDS=(-B /cvmfs)
[ -d /afs ] && BINDS+=(-B /afs)
[ -d /eos ] && BINDS+=(-B /eos)

exec apptainer exec "${BINDS[@]}" "$IMAGE" bash -c '
  source /cvmfs/cms.cern.ch/cmsset_default.sh >/dev/null
  cd '"$CMSSW_SRC"' && eval "$(scramv1 runtime -sh)" && cd - >/dev/null
  export COMBINE_RUN_PYTHONPATH="$PYTHONPATH"
  unset PYTHONPATH PYTHONHOME
  exec '"$VENV"'/bin/combine-run-mcp serve --profile local
'
