# combine-assistant

An AI assistant for **CMS Combine** (HiggsAnalysis-CombinedLimit). It
assembles two MCP servers and a skill into one coherent agent that can
answer Combine questions with citations and run Combine commands to
reproduce, diagnose, and confirm results.

This repo is the *assembly layer*. The servers live in their own repos:

| Piece | Repo | Role |
|---|---|---|
| Retrieval MCP | [`combine-mcp`](https://github.com/maxgalli/combine-mcp) | Read-only search/fetch over docs, paper, code, forum. |
| Execution MCP | [`combine-run-mcp`](https://github.com/maxgalli/combine-run-mcp) | Runs a Combine command in an isolated workspace. |

## What's in here

```
combine-assistant/
├── AGENTS.md                       top-level persona / system prompt
├── .mcp.json                       Claude Code: MCP registration
├── opencode.json                   opencode: MCP registration + permissions
└── .claude/skills/combine/
    └── SKILL.md                    routing + execution guidance (both clients)
```

## Requirements

- An MCP-aware client: [Claude Code](https://claude.com/claude-code) or
  [opencode](https://opencode.ai).
- Network access to the deployed `combine` retrieval MCP (a CERN PaaS
  URL; see [`.mcp.json`](.mcp.json)).
- *(optional, for execution)* A local Combine environment, if you want
  to run commands on your own machine — see
  [Local execution](#local-execution-optional).

## Usage

### Claude Code

Open this repo in Claude Code. The `combine` retrieval MCP is
auto-registered from [`.mcp.json`](.mcp.json), and the skill is
auto-discovered from `.claude/skills/`. Confirm with `/mcp` (you should
see `combine`) and start asking Combine questions.

### opencode

From this repo, opencode reads [`opencode.json`](opencode.json) (MCP
registration + a starter bash-permission allowlist) and discovers the
skill from `.claude/skills/`. Add your provider/model block to
`opencode.json` as you prefer.

## Local execution (optional)

The `combine` retrieval MCP works for everyone with no setup. The
**execution** MCP is different: running Combine needs a real Combine
environment, which is inherently machine-specific, so it is **not**
baked into this repo's shared config. Register it yourself, once:

```bash
# Point the wrapper at YOUR Combine environment and the installed
# combine-run-mcp. Example using a pixi-managed Combine build:
claude mcp add combine-run-local --scope user -- \
  <path-to>/pixi run --manifest-path <combine>/pixi.toml \
  <path-to>/combine-run-mcp serve
```

Any launcher works as long as the spawned server process has `combine`
on its PATH. See [`combine-run-mcp`](https://github.com/maxgalli/combine-run-mcp)
for the server itself.

A shared **remote** execution server is deployed on CERN PaaS and
registered in this repo's config as `combine-run-remote` (see
[`.mcp.json`](.mcp.json)). It is reachable from the **CERN network**
only. So:

- On the CERN network with no local setup → `combine-run-remote` works
  out of the box.
- With `combine-run-local` also registered → the skill **prefers
  local** (no upload limits, longer timeouts).
- Off the CERN network with no local setup → no execution server is
  reachable; the assistant answers from the corpus and won't fabricate
  results.

## How it fits together

- **Questions** ("how / why / what does this do / has anyone hit
  this") → the `combine` retrieval MCP, answered with citations.
- **Running Combine** (reproduce a failing command, confirm a fix) →
  the `combine-run` MCP, when registered.
- The [skill](.claude/skills/combine/SKILL.md) contains the routing
  logic: which retrieval source to use, when to run vs. explain, and
  local-vs-remote execution preference.

## License

[MIT](LICENSE)
