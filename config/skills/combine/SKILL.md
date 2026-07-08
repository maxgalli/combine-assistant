---
name: combine
description: Use when working with CMS Combine (the HiggsAnalysis-CombinedLimit statistical analysis tool used in CMS searches and measurements). Covers datacards, physics models, limits, fits, running modes (AsymptoticLimits, FitDiagnostics, MultiDimFit, HybridNew, Significance, GoodnessOfFit, ChannelCompatibilityCheck), Combine error messages and warnings, statistical methodology, interpreting Combine output, and running Combine commands to reproduce, diagnose, or confirm results. Routes questions to the combine retrieval sources (docs / paper / code / forum) and, when an execution server is available, runs commands via combine-run.
license: MIT
---

# Combine assistant

This skill covers two capabilities for CMS Combine
(HiggsAnalysis-CombinedLimit):

- **Answering questions** using the `combine` MCP server — read-only
  retrieval over four sources (`search_docs`, `fetch_doc`).
- **Running Combine** using the `combine-run` MCP server, when one is
  registered — execute a command and get its output (`run_combine`).

Most requests are answered by retrieval alone. Reach for execution when
a user reports a command that misbehaves, asks you to run or try
something, or when reproducing a result would confirm a diagnosis.

---

# Part 1 — Answering questions (retrieval)

Use the `combine` MCP server. It exposes four complementary sources
through `search_docs` and `fetch_doc`. Route each question to the right
source(s), iterate intelligently, and answer with citations.

## The corpus

| Source ID | Covers |
|---|---|
| `combine-docs` | Official docs (MkDocs). How-to, CLI flags, tutorials, reference. |
| `combine-paper` | arXiv:2404.06614v2. Methodology, definitions, the "why". |
| `combine-code` | Source tree (v10.6.0). The implementation. |
| `combine-forum` | cms-talk Statistics category. Errors, workarounds, real-world edge cases. |

## How to answer

### Step 1 — Pick the right source first

- **"How do I X?"** / **"What does flag --Y do?"** → start with
  `combine-docs`.
- **"Why does X work this way?"** / **"What is the formal definition of Y?"**
  → start with `combine-paper`.
- **"I'm getting this error"** / **"I see this warning"** → start with
  `combine-forum`.
- **"What does the implementation actually do?"** / **"Is feature Z really
  there?"** → start with `combine-code`.

Sources are complementary, not redundant. If the first source comes up
empty, fall through to the next most likely one.

### Step 2 — Search and read scores intelligently

Call `search_docs(query, source)` to get up to 10 ranked hits.
Interpret the scores:

- **Top score is high (>15) with a clear gap to the runner-up:** the
  top hit is almost certainly the right one. Fetch it.
- **Top hits cluster tight (within ~3 points):** all of them are
  relevant. Skim 2–3 snippets to pick the best one before fetching.
- **All scores low (<8):** the search probably missed. Reformulate:
  try synonyms, the exact CLI flag, the verbatim error message.
- **If two reformulations both miss:** the corpus may not cover this
  question. See "Anti-hallucination" below.

### Step 3 — Fetch with the right `mode`

`fetch_doc(url_or_path, source, mode=...)` projections:

| `mode` | Use for |
|---|---|
| `markdown` (default) | Paper sections, short forum threads, short code files. Full body. |
| `outline` | **Scout first** on long docs pages, long forum threads, unfamiliar code files. Headings (docs/paper), defs/classes (code), per-post summary (forum). |
| `sections:<heading>` | Pull one named section from a docs page or paper section. Case-insensitive. |
| `post:<N>` | Forum only. One specific post's body, with a per-post URL. |
| `post:accepted` | Forum only. The accepted-answer post. Cheap and high-signal for solved threads. Errors if the thread is unsolved — use `outline` first if uncertain. |

Default to the cheaper projection (`outline`, `sections:…`,
`post:accepted`) when you can. Reach for `markdown` when you actually
need the full body.

### Step 4 — Cross-source when it helps

Some questions are best answered by combining sources:

- **"Why does X work this way and how do I use it?"** → paper for the
  why, docs for the how.
- **"I'm getting this error from HybridNew"** → forum for the
  diagnosis, docs for HybridNew context.
- **"What does --robustHesse actually do under the hood?"** → docs for
  the description, code for the implementation.

Don't query all four sources routinely — that wastes calls. Default
to one source per question. Parallel-querying two sources upfront is
fine when the question genuinely spans dimensions (like "how AND
why", or "reproduce the error AND explain the cause"). Fall through
to a third source only when the first two leave a real gap.

## Output format

- Start with the **direct answer** in 1–3 sentences.
- Cite the URLs returned by the tools, **verbatim**. Use inline
  Markdown links. Combine users will click through to verify.
- For forum citations, use the per-post URL when you fetched a
  specific post (`post:N` or `post:accepted`); the topic URL otherwise.
- If multiple sources contributed, list all relevant citations.
- Use code blocks for actual code or CLI invocations only — not for
  prose.

## Anti-hallucination

Combine is a domain where wrong answers can lead to wrong physics
results. Be conservative:

- If you can't find the answer in the corpus after two reformulations,
  **say so explicitly**: "I couldn't find this in the Combine docs,
  paper, code, or forum."
- Suggest the user post on
  [cms-talk](https://cms-talk.web.cern.ch/c/physics/cat/cat-stats/279).
- Do **not** answer from prior knowledge without flagging it. If you
  add context beyond what the corpus returned (e.g. comparing a
  fetched method to a related one, or noting a well-known
  consequence), say so explicitly: "not covered in the fetched
  section, but…" or "this is well-known but not in the corpus".
- Never paraphrase a forum reply as if it were the canonical doc.
  Cite the thread and let the user judge.

## Worked example (retrieval)

> *User:* "I'm running AsymptoticLimits and getting 'cannot compute
> the expected limit'. What's wrong?"

Reasoning: this is an error message — start with the forum.

1. `search_docs(query="cannot compute expected limit AsymptoticLimits", source="combine-forum")`
   → look at the top hit(s).
2. If a solved thread surfaces: `fetch_doc(url_or_path="<topic_id>", source="combine-forum", mode="post:accepted")`.
3. If the thread is unsolved:
   `fetch_doc(url_or_path="<topic_id>", source="combine-forum", mode="outline")`,
   then fetch the most-relevant reply with `post:<N>`.
4. Optional context:
   `search_docs(query="AsymptoticLimits", source="combine-docs")` →
   fetch the section that explains what the expected limit
   calculation does.
5. Answer: explain the cause (cite the cms-talk URL), point at the
   fix (cite the post URL), and link the docs page for canonical
   reference.

---

# Part 2 — Running Combine (execution)

Use the `combine-run` MCP server's `run_combine` tool. It runs **one**
Combine-family command (`combine`, `combineTool.py`,
`text2workspace.py`, `combineCards.py`) in an isolated, throwaway
workspace and returns the output. Input files you pass are written into
that workspace; output files are reported by name.

## When to run vs. when to just explain

**Run** when:
- The user reports a command that errors or gives an unexpected result
  and you can reproduce it — running it is the fastest path to a real
  diagnosis.
- The user explicitly asks you to run, try, or check something.
- You've proposed a fix and want to confirm it works.

**Do not run — explain from the corpus instead** when:
- **No execution server is registered.** Never fabricate execution
  results. Say the execution server isn't available, then reason about
  the command from the `combine` sources (what the flag does, what the
  error usually means).
- The task is batch submission (e.g. `combineTool.py --job-mode condor`)
  — that's not what this tool is for; explain, don't submit.
- The inputs are large (see routing below) and only a remote server is
  available.

## Choosing the server: local vs. remote

Two servers may be registered. Check which are available and prefer
accordingly:

- **`combine-run-local`** (the user's own machine): no upload limits,
  longer timeouts. **Prefer this when it's available.** Requires a
  working Combine environment where the server runs.
- **`combine-run-remote`** (a shared CERN service): always reachable,
  but inputs are size-capped and timeouts are shorter. Use it when
  local isn't registered.

Routing rules:
- Prefer local when available; fall back to remote.
- If the datacards + shape files are more than a few MB, prefer local
  even if remote is available — the remote will reject oversized input.
- If neither is registered, don't run — explain from the corpus.

## How to call `run_combine`

- `command`: the full command line, e.g.
  `"combine -M AsymptoticLimits -d datacard.txt -m 125"`. One command;
  no shell pipes or redirects.
- `files`: text inputs as `{filename: content}` — the datacard, any
  text configs. Reference them in the command by the same filename.
- `files_b64`: binary inputs as `{filename: base64}` — ROOT shape
  files a datacard references.
- `timeout_s`: optional; the server clamps it to its ceiling.

Pass every file the command needs. A shape-based datacard that
references `shapes.root` won't run unless you also pass that file via
`files_b64`.

## Interpreting the result

The JSON distinguishes three outcomes:

- **`error` is set** (and `returncode` is null): a *setup* failure —
  disallowed executable, oversized input, unsafe filename, or Combine
  not found on PATH. This is not a physics result. If it says "not
  found on PATH", the server has no Combine environment — tell the
  user; don't guess at numbers.
- **`returncode` is non-zero**: Combine ran but failed. Read `stderr`.
  This is the interesting debugging case — cross-check the error
  against the `combine` sources (`combine-forum` for the message text,
  `combine-code` for what the code checks) to explain and fix.
- **`returncode` is 0**: success. Report the results from `stdout` and
  note the `artifacts` produced (e.g. `higgsCombine*.root`).

Watch `timed_out` (bump `timeout_s` or move heavy jobs local) and the
`*_truncated` flags (output was tailed).

## The reproduce → diagnose → fix loop

1. **Reproduce:** `run_combine` with the user's command and files.
2. **Read the outcome:** setup error vs. non-zero exit vs. success.
3. **Diagnose (if it failed):** cross-check `stderr` against the
   `combine` retrieval sources — forum for "has anyone hit this",
   code/docs for what the failing option requires.
4. **Fix:** propose a corrected command, explaining what changed.
5. **Confirm:** re-run the corrected command; report the new result
   with citations for the reasoning.

## Worked example (execution + diagnosis)

> *User:* "This errors: `combine -M FitDiagnostics -d card.txt
> --robustHesse 1`, and here's my datacard."

1. `run_combine(command="combine -M FitDiagnostics -d card.txt --robustHesse 1", files={"card.txt": <their card>})`.
2. Inspect the result: if `error` says Combine wasn't found, tell the
   user their execution server has no Combine environment. If
   `returncode` is non-zero, read `stderr`.
3. Take the key line from `stderr` and
   `search_docs(query="<that error text>", source="combine-forum")`;
   if needed, check `combine-code` for what the failing step requires.
4. Propose the fix (cite the forum thread / docs), then
   `run_combine(...)` the corrected command to confirm.
5. Report: what failed, why (with citations), and the confirmed
   working command.
