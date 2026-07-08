#!/usr/bin/env bash
#
# Stage (and optionally publish) the combine-assistant config to CVMFS.
#
# Usage:
#   ./script/cvmfs-deploy.sh                                          # stage only (default)
#   ./script/cvmfs-deploy.sh --stage-only                            # stage only, explicit
#   ./script/cvmfs-deploy.sh --cvmfs-base /cvmfs/<repo>/<path> \
#                            --cvmfs-repo <repo>                     \
#                            --publish                               # publish
#
# No CVMFS path is baked in. Pass --cvmfs-base to name the target
# directory and --cvmfs-repo to name the CVMFS repository on which to
# run the transaction. Publishing requires a CVMFS publisher node with
# cvmfs_server and write access to that repository.
#
# Layout produced under dist/cvmfs-stage/ (and mirrored on CVMFS):
#   <VERSION>/
#     VERSION
#     bin/setup.sh
#     config/...       (OPENCODE_CONFIG_DIR target)
#     README.md
#   latest -> <VERSION>

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE_DIR="${REPO_ROOT}/dist/cvmfs-stage"
PUBLISH=false
CVMFS_BASE=""
CVMFS_REPO=""

usage() {
  cat <<EOF
Usage: $0 [options]

  --cvmfs-base PATH   Target directory on CVMFS, e.g.
                        /cvmfs/<repo>/combine-assistant
  --cvmfs-repo NAME   CVMFS repository name for cvmfs_server, e.g.
                        <repo>
  --publish           Run cvmfs_server transaction + rsync + publish
                      (requires --cvmfs-base and --cvmfs-repo)
  --stage-only        (default) Only stage locally under dist/cvmfs-stage
  -h, --help          Show this help
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --cvmfs-base) CVMFS_BASE="$2"; shift 2 ;;
    --cvmfs-repo) CVMFS_REPO="$2"; shift 2 ;;
    --publish)    PUBLISH=true; shift ;;
    --stage-only) PUBLISH=false; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ ! -f "${REPO_ROOT}/VERSION" ]; then
  echo "ERROR: ${REPO_ROOT}/VERSION is missing" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
DEST="${STAGE_DIR}/${VERSION}"

echo "==> Staging combine-assistant v${VERSION}"
rm -rf "${DEST}"
mkdir -p "${DEST}"

# Copy the release payload only. Exclude dev-only and Claude-Code-only
# files (the CVMFS/opencode path uses config/ via OPENCODE_CONFIG_DIR).
# Root-anchored excludes (leading /) so we only drop the top-level
# Claude-Code-only files, NOT the real config/AGENTS.md the persona
# lives in. .DS_Store stays unanchored (drop at any depth).
rsync -a \
  --exclude '/.git' \
  --exclude '/dist' \
  --exclude '/.gitignore' \
  --exclude '.DS_Store' \
  --exclude '/.claude' \
  --exclude '/.mcp.json' \
  --exclude '/AGENTS.md' \
  --exclude '/script/cvmfs-deploy.sh' \
  "${REPO_ROOT}/" "${DEST}/"

# Ensure the entrypoint is executable.
chmod +x "${DEST}/bin/setup.sh"

# Maintain a "latest" symlink alongside the versioned tree.
ln -sfn "${VERSION}" "${STAGE_DIR}/latest"

echo "==> Staged at ${DEST}"
echo "    ${DEST}/config/      (OPENCODE_CONFIG_DIR target)"
echo "    ${DEST}/bin/setup.sh (users source this)"
echo "    ${STAGE_DIR}/latest  -> ${VERSION}"

if [ "$PUBLISH" != true ]; then
  cat <<EOF

==> Dry run complete. Inspect ${STAGE_DIR}/${VERSION}/, or test it:
      source ${STAGE_DIR}/latest/bin/setup.sh
    To publish (on a CVMFS publisher node):
      $0 --cvmfs-base /cvmfs/<repo>/<path> \\
          --cvmfs-repo <repo> --publish
EOF
  exit 0
fi

# ---------------------------------------------------------------------------
# Publish path
# ---------------------------------------------------------------------------
if [ -z "$CVMFS_BASE" ] || [ -z "$CVMFS_REPO" ]; then
  echo "ERROR: --publish requires both --cvmfs-base and --cvmfs-repo" >&2
  exit 1
fi

if ! command -v cvmfs_server >/dev/null 2>&1; then
  echo "ERROR: cvmfs_server not in PATH. Run --publish on a CVMFS publisher node." >&2
  exit 1
fi

echo "==> Publishing to ${CVMFS_BASE} on CVMFS repo ${CVMFS_REPO}"

cvmfs_server transaction "${CVMFS_REPO}"

mkdir -p "${CVMFS_BASE}"
rsync -a --delete "${STAGE_DIR}/" "${CVMFS_BASE}/"

cvmfs_server publish "${CVMFS_REPO}"

echo "==> Published combine-assistant v${VERSION} to ${CVMFS_BASE}"
echo "    Users can now run:"
echo "      source ${CVMFS_BASE}/latest/bin/setup.sh"
