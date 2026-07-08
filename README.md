# combine-assistant

An AI assistant for **CMS Combine** (HiggsAnalysis-CombinedLimit). It
assembles two MCP servers and a skill into one coherent agent that
answers Combine questions with citations and runs Combine commands to
reproduce, diagnose, and confirm results.

This repo is the *assembly layer*. The servers live in their own repos:

| Piece | Repo | Role |
|---|---|---|
| Retrieval MCP | [`combine-mcp`](https://github.com/maxgalli/combine-mcp) | Read-only search/fetch over docs, paper, code, forum. |
| Execution MCP | [`combine-run-mcp`](https://github.com/maxgalli/combine-run-mcp) | Runs a Combine command in an isolated workspace. |

## Layout

`config/` is the single source of truth (the tree that ships to CVMFS
and that opencode reads). The Claude Code discovery paths are symlinks
into it, so there is no duplicated content.

```
combine-assistant/
├── VERSION
├── bin/setup.sh              opencode: source to point at config/
├── script/cvmfs-deploy.sh    stage + publish config/ to CVMFS
├── .mcp.json                 Claude Code: MCP registration
├── AGENTS.md            -> config/AGENTS.md      (symlink)
├── .claude/skills      -> ../config/skills       (symlink)
└── config/
    ├── opencode.json         providers, model, MCP servers, permissions
    ├── AGENTS.md             persona / system prompt
    └── skills/combine/
        └── SKILL.md          routing + execution guidance
```

## Using it

### Claude Code

Open this repo in Claude Code. The `combine` and `combine-run-remote`
MCP servers are auto-registered from [`.mcp.json`](.mcp.json), and the
skill is discovered via the `.claude/skills` symlink. Claude Code uses
its own model — nothing to configure here.

### opencode

```bash
source ./bin/setup.sh          # wires opencode at this repo's config/
export LITELLM_API_KEY=<key>   # your own CERN LiteLLM gateway key
opencode
```

`setup.sh` handles both the binary and the config:

- **Binary.** It uses an `opencode` already on your PATH. If there
  isn't one, it borrows the opencode binary published on CVMFS
  (default: lumi's, `/cvmfs/sw.escape.eu/lumi/latest/bin`; override with
  `COMBINE_ASSISTANT_OPENCODE_BIN`). So on lxplus/SWAN you need no
  install; elsewhere, install opencode
  (`curl -fsSL https://opencode.ai/install | bash`) or point the
  variable at one.
- **Config.** It sets `OPENCODE_CONFIG_DIR` to this repo's `config/`,
  which **adds** the Combine MCP servers, the skill, the persona, and a
  default model on top of your own global opencode config (opencode
  merges config sources — it doesn't replace them). When `config/` is
  read-only (CVMFS) it is copied to a per-user writable dir first,
  because opencode installs a plugin runtime into that directory.

It also keeps the opencode DB on local fs (EOS can't do SQLite WAL) and
disables opencode autoupdate (versions come from CVMFS).

### Model / credentials

You bring your own key — nothing is shared in this repo.

- **Default: CERN LiteLLM gateway.** Mint your own key from the CERN
  LLM gateway self-service and `export LITELLM_API_KEY=…`. Data stays
  in CERN's governed gateway. Default model: `litellm/gpt-4.1`.
- **Alternative: Anthropic.** `export ANTHROPIC_API_KEY=…` and switch
  the model to `anthropic/claude-sonnet-5` (or `claude-opus-4-8`).

Override the model per-session in opencode if you prefer another.

## Local execution (optional)

The `combine` retrieval MCP and the `combine-run-remote` execution MCP
are deployed on CERN PaaS (reachable from the CERN network). If you
want to run Combine on **your own machine** instead, register the
execution server locally — it's machine-specific, so it is not baked
into this shared config:

```bash
claude mcp add combine-run-local --scope user -- \
  <path-to>/pixi run --manifest-path <combine>/pixi.toml \
  <path-to>/combine-run-mcp serve
```

The skill prefers a local execution server when one is registered and
falls back to the remote one.

## Deploying to CVMFS

`config/` is designed to ship read-only on CVMFS. It deploys to the CMS
Common Analysis Tools area, so users just:

```bash
source /cvmfs/cms.cern.ch/cat/combine-assistant/latest/bin/setup.sh
export LITELLM_API_KEY=<key>
opencode
```

Publishing is two phases:

```bash
# Phase 1 — stage locally (anywhere). Produces dist/cvmfs-stage/<VERSION>/.
./script/cvmfs-deploy.sh --stage-only

# (optional) test the staged tree before publishing:
source dist/cvmfs-stage/latest/bin/setup.sh

# Phase 2 — publish (on a machine with cvmfs_server + write access).
# Defaults to /cvmfs/cms.cern.ch/cat/combine-assistant on repo cms.cern.ch:
./script/cvmfs-deploy.sh --publish
```

The publish uses `cvmfs_rsync` when available and is **add-only** (no
`--delete`), so previously published versions that users may have
pinned are never removed — a new release just adds its `<VERSION>/`
tree and repoints `latest`. `.claude/`, `.mcp.json`, and the root
`AGENTS.md` symlink (Claude-Code-only) are excluded from the published
tree.

Note that the opencode **binary** is not shipped here — `setup.sh`
borrows lumi's published binary from `/cvmfs/sw.escape.eu/lumi/...`, so
users need both `cms.cern.ch` and `sw.escape.eu` mounted (both are on
lxplus/SWAN).

## License

[MIT](LICENSE)
