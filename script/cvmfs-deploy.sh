#!/usr/bin/env bash
#
# Stage (and optionally publish) the combine-assistant config to CVMFS.
#
# Usage:
#   ./script/cvmfs-deploy.sh                 # stage only (default)
#   ./script/cvmfs-deploy.sh --stage-only    # stage only, explicit
#   ./script/cvmfs-deploy.sh --publish       # stage + publish to the default target
#   ./script/cvmfs-deploy.sh --publish \
#       --cvmfs-base /cvmfs/<repo>/<path> \
#       --cvmfs-repo <repo>                  # publish to a custom target
#
# Publishing requires a machine with cvmfs_server and write access to the
# target repository. The publish uses cvmfs_rsync when available (the
# CVMFS-aware rsync) and is add-only (no --delete) so older published
# versions that users may have pinned are never removed.
#
# Gateway repos: if the target uses the CVMFS publisher-gateway model
# (leases on a subpath), pass the leased subpath as --cvmfs-repo, e.g.
#   --cvmfs-repo cms.cern.ch/cat/combine-assistant
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

# Default deployment target: the CMS Common Analysis Tools area.
CVMFS_BASE="/cvmfs/cms.cern.ch/cat/combine-assistant"
CVMFS_REPO="cms.cern.ch"

usage() {
  cat <<EOF
Usage: $0 [options]

  --cvmfs-base PATH   Target directory on CVMFS
                        (default: ${CVMFS_BASE})
  --cvmfs-repo NAME   CVMFS repository / lease for cvmfs_server
                        (default: ${CVMFS_REPO})
  --publish           Run cvmfs_server transaction + cvmfs_rsync + publish
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

# Copy the release payload only. Root-anchored excludes (leading /) so we
# only drop the top-level dev / Claude-Code-only files, NOT the real
# config/AGENTS.md. .DS_Store stays unanchored (drop at any depth).
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
    To publish (on a machine with cvmfs_server + write access):
      $0 --publish
    (defaults to ${CVMFS_BASE} on repo ${CVMFS_REPO}; override with
     --cvmfs-base / --cvmfs-repo)
EOF
  exit 0
fi

# ---------------------------------------------------------------------------
# Publish path
# ---------------------------------------------------------------------------
if [ -z "$CVMFS_BASE" ] || [ -z "$CVMFS_REPO" ]; then
  echo "ERROR: --publish needs a non-empty --cvmfs-base and --cvmfs-repo" >&2
  exit 1
fi

if ! command -v cvmfs_server >/dev/null 2>&1; then
  echo "ERROR: cvmfs_server not in PATH. Run --publish on a CVMFS publisher node." >&2
  exit 1
fi

# Prefer the CVMFS-aware rsync; fall back to plain rsync. Add-only (no
# --delete) so older published versions are preserved.
RSYNC_BIN="$(command -v cvmfs_rsync || command -v rsync)"

echo "==> Publishing to ${CVMFS_BASE} on CVMFS repo ${CVMFS_REPO}"
echo "    using ${RSYNC_BIN}"

cvmfs_server transaction "${CVMFS_REPO}"

mkdir -p "${CVMFS_BASE}"
"${RSYNC_BIN}" -av "${STAGE_DIR}/" "${CVMFS_BASE}/"

cvmfs_server publish "${CVMFS_REPO}"

echo "==> Published combine-assistant v${VERSION} to ${CVMFS_BASE}"
echo "    Users can now run:"
echo "      source ${CVMFS_BASE}/latest/bin/setup.sh"
