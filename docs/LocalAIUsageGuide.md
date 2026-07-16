# LOCAL AI USAGE GUIDE

### Terminal-First, AI-Assisted Development — tuned for i5-6th Gen / GTX 1050 Ti (4GB VRAM) / 16GB RAM

---

## 0. The Golden Rules (hardware reality)

Your machine has **4 cores / 4 threads, 4GB VRAM, 16GB RAM**. Every rule below exists so local AI never makes the machine unusable:

1. **One model in memory at a time.** Never two models inferring simultaneously.
2. **Leave one CPU core for yourself.** Ollama gets 3 threads, not 4.
3. **8192 tokens is the context ceiling.** Bigger KV caches evict GPU layers and everything crawls.
4. **3B lives on the GPU (fast). 7B/8B split CPU+GPU (slow but smart).** Choose accordingly.
5. **The `.g.dart` files never go to a model.** Generated code is huge and worthless as context.

### One-time Ollama setup (do this first)

Add to `~/.bashrc` (or wherever your shell config lives):

```bash
# --- Ollama guardrails for 4c/4t CPU + 4GB VRAM + 16GB RAM ---
export OLLAMA_MAX_LOADED_MODELS=1   # never hold two models resident
export OLLAMA_NUM_PARALLEL=1        # one request at a time
export OLLAMA_KEEP_ALIVE=10m        # unload after 10 min idle, frees RAM for Flutter builds
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_KV_CACHE_TYPE=q8_0    # halves KV-cache memory, negligible quality loss
```

Then create throttled model variants (3 threads, sane context) so the defaults are safe:

```bash
ollama create qwen3b-dev -f - <<'EOF'
FROM qwen2.5:3b
PARAMETER num_ctx 8192
PARAMETER num_thread 3
EOF

ollama create qwen7b-dev -f - <<'EOF'
FROM qwen2.5-coder:7b
PARAMETER num_ctx 8192
PARAMETER num_thread 3
EOF

ollama create llama8b-dev -f - <<'EOF'
FROM llama3.1:8b
PARAMETER num_ctx 8192
PARAMETER num_thread 3
EOF
```

Point your `aider-*` / `ai-*` aliases at these `-dev` variants. Restart `ollama serve` after setting the env vars.

**Expected speeds** (so you know what "normal" is):

| Model | Where it runs | Tokens/sec (rough) |
|---|---|---|
| qwen3b-dev | Fully in 4GB VRAM | 20–35 t/s — interactive |
| qwen7b-dev | ~half GPU, half CPU | 4–8 t/s — coffee-sip speed |
| llama8b-dev | ~half GPU, half CPU | 4–7 t/s — planning speed |

If the machine ever lags while a model is loaded: `ollama ps` to see what's resident, `ollama stop <model>` to evict it immediately.

---

## 1. Overview

This workflow turns AI into a **UNIX-like tool** — you invoke it, it solves a problem, you continue working.

- **Search first** — use `rg`, `fd` before asking AI.
- **Context is precious** — feed only 2–5 files to the coding model.
- **Documentation is memory** — the `docs/` folder is the AI's knowledge base.
- **You are Chief Engineer** — AI proposes, `flutter analyze` decides, you commit.

---

## 2. Documentation Structure (this project)

This project already has most of its AI memory. The full set:

```
docs/
├── ARCHITECTURE.md        # system layers & data flow          (exists)
├── PROJECT RULES.md       # coding rules & conventions         (exists)
├── SRS.md                 # requirements                       (exists)
├── ROUTES.md / SCREEN MAP.md / UI_UX.md / DESIGN SYSTEM.md     (exist)
├── PROGRESS REPORT.md / TIMELINE.md                            (exist)
├── GLOSSARY.md            # domain terms (BDAT, translation…)  ← AI memory
├── DECISIONS.md           # why things are the way they are    ← AI memory
├── API.md                 # services/providers/routes surface  ← AI memory
├── CONTEXT.md             # current task (rewrite constantly)  ← AI memory
└── LocalAIUsageGuide.md   # this file (for you, not the AI)
```

**Which docs to feed which model:**

| Task | Feed these files |
|---|---|
| Planning a feature (8B) | `ARCHITECTURE.md`, `GLOSSARY.md`, `DECISIONS.md`, `CONTEXT.md` |
| Coding a file (7B) | `CONTEXT.md` + the 1–3 files being edited + `API.md` as `--read` |
| Quick question (3B) | Nothing — just ask |

**Never** `cat docs/*.md` into a model — that's ~10 files and blows the 8k context. Pick the 3–4 relevant ones.

> **Rule:** If a model asks about something that should be documented, update these files right after the session. Documentation is long-term memory; chat history is ephemeral.

---

## 3. The Workflow (the AI Ladder)

### Step 1 — Update CONTEXT.md

```bash
nvim docs/CONTEXT.md
```

Write: current objective (one sentence), files you expect to touch, known issues, expected outcome. This is your daily standup for the AI.

### Step 2 — Search first (free, instant)

**Never ask the AI to find things.**

```bash
rg "readerProvider" lib/                 # find usage
fd .dart lib/features/bible             # list files in a feature
git log --oneline -10                    # recent work
rg "TODO|FIXME" lib/ --glob '!*.g.dart' # open work
```

### Step 3 — Plan with the 8B (only for real features)

```bash
cat docs/ARCHITECTURE.md docs/GLOSSARY.md docs/DECISIONS.md docs/CONTEXT.md | ollama run llama8b-dev
```

Paste your feature request. Ask for a **batched plan** — a list of files and changes in dependency order. Save it to `docs/plan.md`:

```
FILE: lib/features/bible/domain/reader_provider.dart
CHANGE: add chapter-navigation state
DEPENDS ON: nothing
...
```

### Step 4 — Implement with Aider, one file at a time

```bash
aider-r lib/features/bible/domain/reader_provider.dart --read docs/plan.md --read docs/API.md
```

Inside Aider: *"Implement the change described in plan.md for this file."* Review the diff, approve, move to the next file. Aider must **not** auto-commit (`--no-auto-commits`).

For Drift table changes, remember codegen after edits:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 5 — Analyze / test / commit after every file

```bash
flutter analyze
flutter test
git add -p && git commit -m "feat: ..."
```

**Never accumulate AI edits without analyzing.** `flutter analyze` is the final authority.

---

## 4. Architect-Coder Mode — use sparingly

The `a-c-` aliases run a planning model and a coding model in one Aider session. On this hardware, with `OLLAMA_MAX_LOADED_MODELS=1`, the two models **swap in and out of memory on every turn** (~10–20s per swap). That's the price of keeping the machine usable — accept it or don't use the mode.

| Alias | Architect | Editor | Verdict on this machine |
|---|---|---|---|
| `a-c-l` | 3B | 3B | ✅ Fine — single small model, no swapping pain |
| `a-c-r` | 8B | 3B | ✅ The sweet spot — smart plans, fast edits |
| `a-c-h` | 8B | 7B | ⚠️ Avoid. Constant 8B↔7B swaps, both CPU-bound. Use Step 3 + Step 4 manually instead — same result, half the pain |

**Use architect-coder (`a-c-r`) when:** the feature touches 5+ files, dependencies are unclear, or it's a cross-cutting refactor (e.g., changing how sync status flows through providers).

**Don't use it when:** single-file edit, bug fix in one function, you already know the plan. Start with plain `aider-r` and escalate only if the task fights back.

**Rule of thumb:** if you can write the plan yourself in 2 minutes, you don't need an architect model.

---

## 5. Model Selection

| Alias | Model | Use for |
|---|---|---|
| `ai-3b` | qwen3b-dev | Regex, shell one-liners, quick Dart questions — it's the only *fast* model you have |
| `aider-3b` | qwen3b-dev | Trivial mechanical edits |
| `aider-r` / `aider-7b` | qwen7b-dev | **Default for all code changes** |
| `ai-8b` / `aider-8b` | llama8b-dev | Planning & review only — it's worse at editing than the 7B coder |
| `a-c-r` | 8B + 3B | Multi-file features (see §4) |

---

## 6. One Model at a Time (non-negotiable)

Do **not** run multiple Aider sessions with models in parallel. Two 7B models on a 4-core CPU is thrashing, not concurrency — both sessions slow to <2 t/s and the desktop freezes.

What parallel terminals **are** for:

- **Tab 1:** Aider (the only model)
- **Tab 2:** `flutter analyze` / `flutter test` / `build_runner`
- **Tab 3:** git, `rg`, editor

If you need a second AI opinion mid-session, that's what the cloud fallback (§8) is for.

---

## 7. Context Windows & Reference Code

**Context ceiling is 8192** (baked into the `-dev` variants). Do not create 16k variants — on 4GB VRAM the KV cache evicts GPU layers and a "bigger context" run is *slower and dumber*.

If a task doesn't fit in 8k: the task is too big. Split it (that's what `docs/plan.md` is for).

**Feeding reference code:**

```bash
# read-only files in Aider (preferred)
aider-r lib/features/bible/domain/reader_provider.dart \
  --read lib/features/settings/domain/book_name_settings_provider.dart

# or a one-shot pipe
cat lib/core/providers/sync_status_provider.dart | ollama run qwen7b-dev \
  "Write a similar provider for download progress, matching this project's style."
```

**Never add to context:** `*.g.dart`, `build/`, `pubspec.lock`, asset files.

---

## 8. Cloud Fallback — when and how

Cloud models (Claude, GPT) remain better for:

- Deep debugging of obscure errors (Drift codegen issues, platform channel weirdness)
- Security review (Supabase RLS policies, auth flows)
- Architecture decisions with many trade-offs
- Anything where the 8B goes in circles twice — **stop burning local cycles, escalate**

When you use the cloud:

1. Use it to **understand and plan**, bring the plan back to local Aider to implement.
2. **Immediately** record the outcome in `docs/DECISIONS.md`.
3. Never rely on cloud chat history — your docs are the real memory.

---

## 9. Troubleshooting

| Problem | Solution |
|---|---|
| Machine lags / UI freezes | `ollama ps` → `ollama stop <model>`. Check the `-dev` variant is in use (`num_thread 3`). |
| Model painfully slow | You're probably on a raw model with 4096+ ctx and 4 threads. Use the `-dev` variants. |
| Two models loaded at once | `OLLAMA_MAX_LOADED_MODELS=1` not exported, or `ollama serve` not restarted after setting it. |
| RAM pressure during `flutter build` | `ollama stop` everything first; keep_alive will have models lingering otherwise. |
| Aider wants an API key | `export OPENAI_API_KEY="dummy"` — Aider still works with Ollama. |
| Aider auto-commits | `--no-auto-commits` (your aliases should already include it). |
| See loaded files in Aider | `/ls` |
| 8B architect never asks questions | Prompt it: "Ask me clarifying questions before planning." |
| Drift edits break the build | Re-run `dart run build_runner build --delete-conflicting-outputs`. |

---

## 10. Daily Start

```bash
alias start-bible='cd "/mnt/0ccd5012-67f4-4bcc-bc51-4ffc5f15fd84/PROJECTS/Flutter and Dart/universal_bible" && nvim docs/CONTEXT.md'
```

1. `start-bible` — update CONTEXT.md
2. `rg` / `fd` to locate the work
3. `aider-r <file> --read docs/plan.md` to do the work
4. `flutter analyze && flutter test` → commit

---

## 11. Final Philosophy

- **AI is your pair programmer, not your architect.** You remain Chief Engineer.
- **`flutter analyze` is your QA department.** Always analyze before committing.
- **Documentation is your memory.** Write down decisions and context; never trust AI to remember.
- **Search is free, context is expensive.** Use `rg` and `fd` liberally.
- **A usable machine beats a smarter model.** When in doubt, use the smaller model.

---

## 12. Quick Reference Card

| Task | Command |
|---|---|
| Plan a feature | `cat docs/ARCHITECTURE.md docs/GLOSSARY.md docs/DECISIONS.md docs/CONTEXT.md \| ollama run llama8b-dev` |
| Save the plan | paste into `docs/plan.md` |
| Edit a file | `aider-r lib/path/file.dart --read docs/plan.md` |
| Quick question | `ai-3b "how do I …"` |
| Multi-file feature | `a-c-r` (never `a-c-h`) |
| What's loaded? | `ollama ps` |
| Free the machine | `ollama stop <model>` |
| Regenerate Drift code | `dart run build_runner build --delete-conflicting-outputs` |
| Verify | `flutter analyze && flutter test` |

---

**This document is your companion.** Read it when you feel lost, update it when you learn something new.
