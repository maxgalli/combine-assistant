# combine-assistant

An AI assistant for **CMS Combine** (HiggsAnalysis-CombinedLimit). It
assembles MCP servers and skills into one coherent agent that
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

No credential is shared in this repo — you pick a provider and (for the
hosted ones) bring your own key. Switch model per-session with
`opencode --model <provider>/<model>`.

| Provider | Model(s) | Key | Notes |
|---|---|---|---|
| `litellm` **(default)** | `litellm/gpt-4.1`, `litellm/mistral-small-latest` | `LITELLM_API_KEY` | CERN LiteLLM gateway. Mint your own key from the CERN LLM gateway self-service; data stays in CERN's governed gateway. |
| `anthropic` | `anthropic/claude-sonnet-5`, `anthropic/claude-opus-4-8` | `ANTHROPIC_API_KEY` | Public Anthropic API, your own key. |
| `nrp` | `nrp/qwen3`, `nrp/qwen3-small`, `nrp/kimi` | `NRP_API_KEY` | Free-for-researchers GPU gateway (National Research Platform / Nautilus). Get a token at the NRP LLM token page. Good open-model option without a CERN key. |
| `cern-vm` | `cern-vm/qwen2.5-coder:7b` | none | **Self-hosted** Ollama on `Combine-bot.cern.ch`. No key at all — but see the warning below. |

**⚠️ The `cern-vm` self-hosted model is *very* slow.** It runs on a
CPU-only VM (no GPU), so a small 7B model generates only a few tokens
per second. Since the assistant is agentic — several model calls per
question (think → call tool → read result → answer) — a single question
can take from tens of seconds to minutes. It needs no key and keeps
data on the VM, which makes it a legitimate zero-credential fallback,
but it is not a pleasant primary. For responsive use, prefer `litellm`
(CERN) or `nrp` (if you can get a token). Also note it's reachable only from the
CERN network (lxplus/SWAN, or VPN).

## Local execution

The `combine` retrieval MCP and the `combine-run-remote` execution MCP
are deployed on CERN PaaS (reachable from the CERN network). The remote
execution server is what lets someone with **no local Combine install**
run commands at all — it ships Combine itself, in a sandbox.

If you *do* have Combine on your own machine, you don't need a server for
it: **just source your Combine environment before launching the agent,
and let the agent run Combine through its built-in shell tool.** Both
Claude Code and opencode inherit the environment of the shell that
started them, so once `combine` is on `PATH` the agent can run it
directly:

```bash
cd /path/to/CMSSW_14_1_0_pre4/src && cmsenv   # combine, text2workspace.py, … on PATH
cd /your/analysis                             # your real datacards live here
claude        # or: source .../combine-assistant/latest/bin/setup.sh && opencode
```

This runs Combine in your actual working directory against your real
files — no upload, no size cap, no separate server process, and none of
the Python-version juggling the container image needs. The skill
(`config/skills/combine/SKILL.md`) tells the agent to prefer the shell
when `combine` is on `PATH` and to fall back to the remote `run_combine`
tool otherwise.

To keep Combine runs friction-free while still gating arbitrary shell,
`config/opencode.json` allow-lists the Combine executables in
`permission.bash` (`combine`, `text2workspace.py`, `combineCards.py`).
`combineTool.py` is intentionally **not** auto-allowed — it can submit
batch jobs (condor/crab) — so those calls still prompt.

## Releasing a new version

Two version numbers must stay in lockstep: the **`VERSION` file** (used
by `cvmfs-deploy.sh` to name the published directory and to point
`latest` at) and the **git tag** (what the CVMFS deploy driver clones).
If they disagree, the deploy publishes the new content under the *old*
directory name — silently overwriting a version users may have pinned.

Checklist, in this order:

1. **Bump `VERSION` first**, then commit:

   ```bash
   echo "0.3.0" > VERSION
   git add VERSION && git commit -m "Bump version to 0.3.0"
   ```

2. **Tag that commit** with the matching name (`v` + `VERSION`) and
   push branch and tag:

   ```bash
   git tag -a v0.3.0 -m "combine-assistant v0.3.0"
   git push origin master
   git push origin v0.3.0
   ```

3. **Update the pinned default** in the CVMFS deploy repo
   (`cms-griddata.cern.ch-cat-sw/deploy_combine-assistant.sh`,
   `COMBINE_ASSISTANT_TAG:-v0.3.0`) and commit there — the script in
   git is the record of what is deployed. Its
   `COMBINE_ASSISTANT_TAG=... ` env override is for one-off tests
   only.

Sanity check before pushing the tag: run
`./script/cvmfs-deploy.sh --stage-only` and confirm the directory under
`dist/cvmfs-stage/` is named after the **new** version — that catches a
forgotten `VERSION` bump before it reaches CVMFS.

## Deploying to CVMFS

`config/` is designed to ship read-only on CVMFS. It deploys to the CMS
CAT software area, so users just:

```bash
source /cvmfs/cms-griddata.cern.ch/cat/sw/combine-assistant/latest/bin/setup.sh
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
# Defaults to /cvmfs/cms-griddata.cern.ch/cat/sw/combine-assistant
# on repo cms-griddata.cern.ch:
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
