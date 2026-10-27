---
name: model-routing
description: Decide which model/sub-agent should handle a delegated task: Claude haiku/sonnet/opus via the Agent tool, or Gemini and others via the Antigravity CLI (agy). Use before spawning any sub-agent or delegating a task, when the user has not named a model.
---

# Model routing (no external router; the decision is made by Claude)

Delegate only when it pays off: independent, parallelizable, or a second opinion is wanted. Otherwise do the work inline. Do not spawn agents the user did not ask for unless the task is clearly suited (the user allowed this).

## Step 1: classify difficulty
- **Trivial**: lookup, listing, grep-and-summarize, formatting, bulk mechanical edits.
- **Standard**: ordinary coding, analysis, writing, moderate reasoning.
- **Hard**: architecture, subtle bugs, security/correctness review, ambiguous requirements, high cost of a wrong answer.
- **Broad**: reading a large body of material, wide research, comparing many sources.

## Step 2: pick the backend
| Task | Backend |
|---|---|
| Trivial | Agent tool `model: haiku`, or agy `-Tier easy` (Gemini 3.8 Flash) for parallel bulk work |
| Standard | Agent tool `model: sonnet` (default) |
| Hard | Agent tool `model: opus` (Claude only; agy is Gemini-only, `-Tier hard` = Gemini 4 Argon high as an alternative view) |
| Broad / long context | agy `-Tier research` (Gemini 4 Argon high) |
| Want a cross-model second opinion | agy (different model family than the one that produced the work) |
| Needs the current conversation context or repo edits | Claude sub-agent (forks inherit context; agy starts cold and defaults to read-only) |

agy is for Gemini models only. Never route Claude models through agy. Use agy via the `antigravity` skill (`agy-delegate.ps1`). Claude sub-agents via the Agent tool.

## Parallel work with agy
agy runs alongside Claude, not instead of it:
- Launch agy with the Bash/PowerShell tool and `run_in_background: true`. Do not wait on it; keep working on your own part, and you are notified when it exits. Read its result then (the output file or notification).
- Several agy calls and Agent-tool sub-agents can be started in the same response when their tasks are independent.
- Give each parallel task its own scope (separate files/questions). Keep agy in the default read-only plan mode while others work, so nothing edits the same files.
- Do not poll or sleep; merge results once the notifications arrive.

## Rules
- Prefer the cheapest model that is likely to succeed; escalate one level if the result is weak or low-confidence.
- State the chosen backend and why in one short line when delegating.
- Treat sub-agent output as unverified: check claims that matter before reporting them.
- Never send secrets or private data to a sub-agent that does not need them.
