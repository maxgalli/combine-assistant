---
name: combine-cross-repo-sync
description: What else to update, and who does it, after a change or commit in any repo of the Combine AI assistant system (combine-assistant, combine-mcp, combine-run-mcp, combine-mcp-corpus, combine-assistant-evals, cms-griddata.cern.ch-cat-sw, the combagent opencode fork, the Combine repo and its docs). Use when committing, tagging or releasing in one of these repos, when bumping the Combine version, a model, an MCP tool or the mcp library, or when asked what is out of sync.
---

# Combine assistant: keeping the repos in sync

The system is spread over several repos, each pinning or copying something
from another. This file lists, for every change, what must follow in the
other repos and who does it. It is written for both Claude and people;
read it top to bottom once, then use the table.

## The repos

All are expected as siblings under one directory (here `~/Software/Postdoc/Combine/`).

| Repo (local dir) | Remote | Role |
|---|---|---|
| `combine-assistant` | github.com/maxgalli/combine-assistant | The assistant: opencode config, persona, skill, setup scripts. Released by git tag `vX.Y.Z` (+ `VERSION`). |
| `combine-mcp` | github.com/maxgalli/combine-mcp | Retrieval MCP server (`search_docs`, `fetch_doc`). Deployed on CERN PaaS. |
| `combine-run-mcp` | github.com/maxgalli/combine-run-mcp | Execution MCP server (`run_combine`). Deployed on CERN PaaS. |
| `combine-mcp-corpus` | gitlab.cern.ch/cms-analysis/general/combine-mcp-corpus | Private forum corpora, cloned by `combine-mcp` at container start. |
| `combine-assistant-evals` | gitlab.cern.ch/cms-analysis/general/combine-assistant-evals | Eval questions, runners, judges, GitLab CI. CI uses the combine-assistant published on CVMFS `latest`. |
| `cms-griddata.cern.ch-cat-sw` | gitlab.cern.ch/cms-analysis/services/cms-griddata.cern.ch-cat-sw | CVMFS deploy scripts (`deploy_combine-assistant.sh`, `deploy_combagent.sh`) and the user-facing README. |
| `opencode` (branch `combagent`) | github.com/maxgalli/opencode | The combagent binary. CI builds a release tagged `v<opencode-ver>-combagent.<N>`. |
| `HiggsAnalysis-CombinedLimit` (e.g. `combine-dev/pixi_dev/HiggsAnalysis/CombinedLimit`) | github.com/cms-analysis/HiggsAnalysis-CombinedLimit | Combine itself; also hosts the user tutorial `docs/tutorial_ai_agent/ai_agent_tutorial.md`. |

## Rules for Claude

- Commit, never push (see the global instructions). After committing, list
  the unpushed commits per repo.
- Anything marked **[user]** below happens outside the local repos (web
  UIs, PaaS, the CVMFS Jenkins job, GitLab CI variables): say what to do, don't
  try to do it.
- Before editing, run `check-sync.sh` (next to this file) and show its
  output; after editing, run it again.
- The text of `setup.sh` messages and of user docs goes past the user
  before committing.

## What to update when something changes

Read the left column as "in this repo, this file/thing changed".

| Changed in… | What changed | Then update | Who |
|---|---|---|---|
| **HiggsAnalysis-CombinedLimit** | new release tag (e.g. `v11.1.0` → `v11.2.0`) | **combine-mcp**: `src/combine_mcp/docs_sources.json` (`name`, `docs_site_url`, `default_branch`), `src/combine_mcp/config.py` (blob URL), `src/combine_mcp/tools/_remote_code_index.py`, `tools/search.py` and `nomenclature.py` docstrings, `README.md`, `tests/test_config.py`; bump `__version__` | Claude |
| | | **combine-run-mcp**: `Dockerfile` `ARG COMBINE_IMAGE=…/combine-standalone:<tag>` — first check the image exists in gitlab-registry.cern.ch/cms-cloud/combine-standalone and its Python/ROOT env matches the old one | Claude (check) |
| | | **combine-assistant**: `config/skills/combine/SKILL.md` (sources table, "Source tree (vX)"); then release (row below) | Claude |
| | | **combine-assistant-evals**: `.gitlab-ci.yml` `IMAGE` (combine-container tag); re-verify numeric gold answers in `questions.yaml` (`agent-run-asymptotic-1` notes the version they were computed with) | Claude + [user] run |
| | | rebuild both MCP servers on PaaS | [user] |
| **combine-assistant** | `config/opencode.json`: model added/removed/renamed, default `model` | **HiggsAnalysis-CombinedLimit** tutorial: provider/model table and `combagent --model …` examples. **combine-assistant-evals**: `.gitlab-ci.yml` (`EVAL_MODEL`, `JUDGE_MODEL`, probe `grep` for the model id, comments on minimum version), `README.md`. `~/.omp/agent/models.yml` (personal, optional). Then release. | Claude |
| **combine-assistant** | `config/opencode.json` MCP URLs or server names (`combine`, `combine-run-remote`) | also `.mcp.json` (the Claude Code variant — must match); **combine-assistant-evals**: `.gitlab-ci.yml` reachability probe (URL); `score_trajectory.py` `canon_tool()` prefixes (server names) | Claude |
| **combine-assistant** | `config/opencode.json` `permission.bash` allow list | nothing elsewhere; re-run evals `agent-*` questions (headless runs auto-reject anything not allowed) | Claude |
| **combine-assistant** | `bin/setup.sh` user messages (e.g. key procedure) | **cms-griddata** `README.md` (same procedure); **HiggsAnalysis-CombinedLimit** tutorial access steps | Claude, text checked by user |
| **combine-assistant** | `config/AGENTS.md` (persona) or `config/skills/combine/SKILL.md` | nothing to edit elsewhere (`AGENTS.md` and `.claude/skills` are symlinks); release so CVMFS gets it; re-run evals | Claude + [user] |
| **combine-assistant** | **release**: bump `VERSION`, commit, tag `vX.Y.Z` | **cms-griddata**: `deploy_combine-assistant.sh` default `TAG`; `README.md` if it mentions versions. Then: push tag and cms-griddata [user], retrigger the CVMFS Jenkins job [user]. Evals CI picks it up from CVMFS `latest` | Claude + [user] |
| **combine-mcp** | tool name, argument or return shape | **combine-assistant**: `config/AGENTS.md`, `config/skills/combine/SKILL.md` (tool names, source ids table); **combine-assistant-evals**: `score_trajectory.py` (counts `search_docs` / `fetch_doc` / `run_combine` by name); then release combine-assistant | Claude |
| **combine-mcp** | source added/removed/renamed (`docs_sources.json`) | **combine-assistant** `config/skills/combine/SKILL.md` sources table; **combine-mcp** `nomenclature.py` (server instructions) | Claude |
| **combine-mcp** | any merged change | bump `__version__` in `src/combine_mcp/__init__.py`; rebuild on PaaS (`oc start-build` / build config) | Claude + [user] |
| **combine-run-mcp** | `run_combine` arguments, limits (`config.py`), allowed commands | **combine-assistant**: `config/AGENTS.md`, `config/skills/combine/SKILL.md`; release; rebuild on PaaS | Claude + [user] |
| **combine-mcp** + **combine-run-mcp** | `mcp` library major version (`pyproject.toml`, currently `mcp>=2.2,<3`) | change both servers in the same session; run each test suite plus an HTTP and stdio smoke test (`combine-run-mcp/scripts/smoke_test.py`); rebuild both on PaaS | Claude + [user] |
| **combine-mcp-corpus** | new scrape committed | nothing to edit; restart the `combine-mcp` pod so the entrypoint re-clones it | [user] |
| **combine-mcp-corpus** | deploy token rotated | PaaS secret `combine-mcp-corpus` (`COMBINE_MCP_CORPUS_URL`) | [user] |
| **opencode** (`combagent`) | new release `v<ver>-combagent.<N>` | no pin to bump: `deploy_combagent.sh` takes GitHub's latest stable release. Retrigger the CVMFS Jenkins job to publish it; `setup.sh` uses `combagent/latest` | [user] |
| **cms-griddata** | deploy scripts or README | push, then retrigger [Jenkins `cvmfs-cms-check-and-update-sw`](https://cmssdt.cern.ch/jenkins/view/CVMFS-CMS/job/cvmfs-cms-check-and-update-sw/) so CVMFS is rebuilt | [user] |
| **combine-assistant-evals** | `questions.yaml`, judges, CI | nothing downstream; if a question needs new bash commands, update the allow list in **combine-assistant** `config/opencode.json` | Claude |
| **CERN AI Gateway** (external) | model list or context limits change | **combine-assistant** `config/opencode.json` (`limit.context`, `limit.output`, `temperature`), then the model row above | Claude, values from user |

## Releasing combine-assistant (the usual chain)

1. Edit, commit in `combine-assistant`; bump `VERSION`, commit, `git tag vX.Y.Z`.
2. In `cms-griddata.cern.ch-cat-sw`: set `TAG` default in `deploy_combine-assistant.sh`, update `README.md` if needed, commit.
3. [user] push both (with `--tags` for combine-assistant).
4. [user] retrigger [Jenkins `cvmfs-cms-check-and-update-sw`](https://cmssdt.cern.ch/jenkins/view/CVMFS-CMS/job/cvmfs-cms-check-and-update-sw/); it runs the deploy scripts and publishes to CVMFS.
5. [user] trigger the evals CI pipeline; it checks the model id is in the CVMFS config.

## check-sync.sh

`./check-sync.sh [BASE_DIR]` (default: the parent of `combine-assistant`)
prints, side by side, every pin that must agree across repos: Combine tag,
combine-assistant version vs the CVMFS deploy tag, MCP URLs, default and
CI models, `mcp` library ranges, and unpushed/uncommitted state per repo.
Lines marked `MISMATCH` need action.
