# LOCAL AI USAGE GUIDE

### Terminal-First, AI-Assisted Development — Current Setup & Future Goal

---

## Current Setup (What You Have Now)

Your aliases and models are already configured. Here's what's currently available:

### Your Aliases

```bash
# Single-model Aider sessions
alias aider-3b="aider --model ollama/qwen2.5:3b --no-auto-commits --no-attribute-author --attribute-committer"
alias aider-7b="aider --model ollama/qwen2.5-coder:7b --no-auto-commits --no-attribute-author --attribute-committer"
alias aider-8b="aider --model ollama/llama3.1:8b --no-auto-commits --no-attribute-author --attribute-committer"
alias aider-r="aider --model ollama/qwen2.5-coder:7b --no-auto-commits --no-attribute-author --attribute-committer"  # default

# Quick terminal queries
alias ai-3b="ollama run qwen2.5:3b"
alias ai-7b="ollama run qwen2.5-coder:7b"
alias ai-8b="ollama run llama3.1:8b"
alias models="ollama list"

# Architect-Coder modes (two models, one session)
a-c-h() { ... }  # 8B architect + 7B coder (~8-10GB RAM)
a-c-r() { ... }  # 8B architect + 3B coder (~6-7GB RAM)
a-c-l() { ... }  # 3B architect + 3B coder (~3-4GB RAM)
```

### Your Models

| Model | Size | Status |
|-------|------|--------|
| `qwen2.5:3b` | 1.9GB | ✅ Installed |
| `qwen2.5-coder:7b` | 4.7GB | ✅ Installed |
| `llama3.1:8b` | 4.7GB | ✅ Installed |
| `qwen2.5-vl:7b` | 4.7GB | Available in LM Studio |

---

## Goal Setup (Optimized for Your Hardware)

The following optimizations will make your machine more responsive. Implement when you have time:

### Add to `~/.bashrc`

```bash
# --- Ollama guardrails for 4c/4t CPU + 4GB VRAM + 16GB RAM ---
export OLLAMA_MAX_LOADED_MODELS=1   # never hold two models resident
export OLLAMA_NUM_PARALLEL=1        # one request at a time
export OLLAMA_KEEP_ALIVE=10m        # unload after 10 min idle
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_KV_CACHE_TYPE=q8_0    # halves KV-cache memory
```

### Create Throttled Model Variants

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

### Update Aliases to Use `-dev` Variants

```bash
alias aider-3b="aider --model ollama/qwen3b-dev --no-auto-commits --no-attribute-author --attribute-committer"
alias aider-7b="aider --model ollama/qwen7b-dev --no-auto-commits --no-attribute-author --attribute-committer"
alias aider-8b="aider --model ollama/llama8b-dev --no-auto-commits --no-attribute-author --attribute-committer"
alias aider-r="aider --model ollama/qwen7b-dev --no-auto-commits --no-attribute-author --attribute-committer"
alias ai-3b="ollama run qwen3b-dev"
alias ai-7b="ollama run qwen7b-dev"
alias ai-8b="ollama run llama8b-dev"
```

### Expected Speeds (After Optimization)

| Model | Where it runs | Tokens/sec |
|-------|---------------|------------|
| qwen3b-dev | Fully in 4GB VRAM | 20–35 t/s — interactive |
| qwen7b-dev | ~half GPU, half CPU | 4–8 t/s — coffee-sip speed |
| llama8b-dev | ~half GPU, half CPU | 4–7 t/s — planning speed |

---

## 1. The Golden Rules (hardware reality)

Your machine has **4 cores / 4 threads, 4GB VRAM, 16GB RAM**. Every rule below exists so local AI never makes the machine unusable:

1. **One model in memory at a time.** Never two models inferring simultaneously.
2. **Leave one CPU core for yourself.** Ollama gets 3 threads, not 4.
3. **8192 tokens is the context ceiling.** Bigger KV caches evict GPU layers and everything crawls.
4. **3B lives on the GPU (fast). 7B/8B split CPU+GPU (slow but smart).** Choose accordingly.
5. **Generated code never goes to a model.** Files like `*.g.dart` are huge and worthless as context.

---

## 2. Overview

This workflow turns AI into a **UNIX-like tool** — you invoke it, it solves a problem, you continue working.

- **Search first** — use `rg`, `fd` before asking AI.
- **Context is precious** — feed only 2–5 files to the coding model.
- **Documentation is memory** — the `docs/` folder is the AI's knowledge base.
- **You are Chief Engineer** — AI proposes, compilers decide, you commit.

---

## 3. Documentation Structure

For **any** project, create these core files in a `docs/` folder:

```
project/
├── docs/
│   ├── ARCHITECTURE.md       # overall system (diagrams, layers)
│   ├── GLOSSARY.md           # domain-specific terms
│   ├── DECISIONS.md          # why you chose certain technologies
│   ├── CONTEXT.md            # current task (rewrite often)
│   ├── API.md                # endpoints, functions, interfaces
│   └── LOCAL_AI_USAGE.md     # this file (for yourself)
```

**Which docs to feed which model:**

| Task | Feed these files |
|------|------------------|
| Planning a feature (8B) | `ARCHITECTURE.md`, `GLOSSARY.md`, `DECISIONS.md`, `CONTEXT.md` |
| Coding a file (7B) | `CONTEXT.md` + the 1–3 files being edited + `API.md` as `--read` |
| Quick question (3B) | Nothing — just ask |

> **Rule:** If a model asks about something that should be documented, update these files immediately after the session. Documentation is long-term memory; chat history is ephemeral.

---

## 4. The Workflow (The AI Ladder)

### Step 1 — Update CONTEXT.md

```bash
nvim docs/CONTEXT.md
```

Write: current objective (one sentence), files you expect to touch, known issues, expected outcome.

### Step 2 — Search First (Free, Instant)

**Never ask the AI to find things.**

```bash
rg "PlayerController"          # find usage
fd .rs                         # list Rust files
git log --oneline -10          # recent commits
```

### Step 3 — Plan with the 8B (Only for Real Features)

```bash
cat docs/ARCHITECTURE.md docs/GLOSSARY.md docs/DECISIONS.md docs/CONTEXT.md | ollama run llama8b-dev
```

Paste your feature request. Ask for a **batched plan** — a list of files and changes in dependency order. Save it to `docs/plan.md`:

```
FILE: src/routes/login.rs
CHANGE: add login endpoint
DEPENDS ON: update auth.rs first
```

### Step 4 — Implement with Aider, One File at a Time

```bash
aider-r src/routes/login.rs --read docs/plan.md --read docs/API.md
```

Inside Aider: *"Implement the change described in plan.md for this file."*

Review the diff, approve, move to the next file.

### Step 5 — Compile / Test / Commit After Every File

```bash
cargo build         # or flutter analyze, etc.
cargo test          # or flutter test
git add -p && git commit -m "feat: ..."
```

**Never accumulate AI edits without compiling.** The compiler is your final authority.

---

## 5. Architect-Coder Mode — Use Sparingly

The `a-c-` aliases run a planning model and a coding model in one Aider session. On this hardware, with `OLLAMA_MAX_LOADED_MODELS=1`, the two models **swap in and out of memory on every turn** (~10–20s per swap).

| Alias | Architect | Editor | Verdict |
|-------|-----------|--------|---------|
| `a-c-l` | 3B | 3B | ✅ Fine — single small model |
| `a-c-r` | 8B | 3B | ✅ Sweet spot — smart plans, fast edits |
| `a-c-h` | 8B | 7B | ⚠️ Avoid. Constant swaps. Use Step 3 + Step 4 manually instead. |

**Use architect-coder (`a-c-r`) when:** feature touches 5+ files, dependencies are unclear, or it's a cross-cutting refactor.

**Don't use it when:** single-file edit, bug fix, you already know the plan. Start with plain `aider-r` and escalate only if needed.

---

## 6. Model Selection Reference

| Alias | Model | Use For |
|-------|-------|---------|
| `ai-3b` / `aider-3b` | qwen2.5:3b (or qwen3b-dev) | Regex, shell, quick Dart questions — the only *fast* model |
| `aider-r` / `aider-7b` | qwen2.5-coder:7b (or qwen7b-dev) | **Default for all code changes** |
| `ai-8b` / `aider-8b` | llama3.1:8b (or llama8b-dev) | Planning & review only — worse at editing |
| `a-c-r` | 8B + 3B | Multi-file features (see §5) |

---

## 7. One Model at a Time (Non-Negotiable)

Do **not** run multiple Aider sessions with models in parallel. Two 7B models on a 4-core CPU is thrashing — both sessions slow to <2 t/s and the desktop freezes.

**What parallel terminals ARE for:**

- **Tab 1:** Aider (the only model)
- **Tab 2:** Compiler / tests / build_runner
- **Tab 3:** git, `rg`, editor

---

## 8. Context Windows & Reference Code

**Context ceiling is 8192** (baked into the `-dev` variants). Do not create 16k variants — on 4GB VRAM the KV cache evicts GPU layers and everything crawls.

**Feeding reference code:**

```bash
# Read-only files in Aider (preferred)
aider-r src/main.rs --read src/helpers.rs

# Or a one-shot pipe
cat src/helpers.rs | ollama run qwen7b-dev "Write a similar function for..."
```

**Never add to context:** `*.g.dart`, `build/`, `pubspec.lock`, asset files.

---

## 9. Cloud Fallback — When and How

Cloud models remain better for:

- Deep debugging of obscure errors
- Security reviews
- Architecture decisions with many trade-offs
- Anything where the 8B goes in circles twice

**When you use the cloud:**

1. Use it to **understand and plan**, bring the plan back to local Aider.
2. **Immediately** record the outcome in `docs/DECISIONS.md`.
3. Never rely on cloud chat history — your docs are the real memory.

---

## 10. Troubleshooting

| Problem | Solution |
|---|---|
| Machine lags / freezes | `ollama ps` → `ollama stop <model>` |
| Model painfully slow | You're probably using raw model with 4096+ ctx and 4 threads. Use `-dev` variants. |
| Two models loaded at once | `OLLAMA_MAX_LOADED_MODELS=1` not exported, or `ollama serve` not restarted. |
| RAM pressure during builds | `ollama stop` everything first. |
| Aider wants API key | `export OPENAI_API_KEY="dummy"` |
| Aider auto-commits | `--no-auto-commits` (your aliases already have this) |
| See loaded files in Aider | `/ls` |
| 8B architect never asks questions | Prompt: "Ask me clarifying questions before planning." |

---

## 11. Daily Start

```bash
# In ~/.bashrc
alias start-project='cd "/path/to/your/project" && nvim docs/CONTEXT.md'
```

1. `start-project` — update CONTEXT.md
2. `rg` / `fd` to locate the work
3. `aider-r <file> --read docs/plan.md` to do the work
4. Compile → test → commit

---

## 12. Final Philosophy

- **AI is your pair programmer, not your architect.** You remain Chief Engineer.
- **The compiler is your QA department.** Always analyze before committing.
- **Documentation is your memory.** Write down decisions and context; never trust AI to remember.
- **Search is free, context is expensive.** Use `rg` and `fd` liberally.
- **A usable machine beats a smarter model.** When in doubt, use the smaller model.

---

## 13. Quick Reference Card

| Task | Command |
|---|---|
| Plan a feature | `cat docs/ARCHITECTURE.md docs/GLOSSARY.md docs/DECISIONS.md docs/CONTEXT.md \| ollama run llama8b-dev` |
| Save the plan | paste into `docs/plan.md` |
| Edit a file | `aider-r lib/path/file.dart --read docs/plan.md` |
| Quick question | `ai-3b "how do I …"` |
| Multi-file feature | `a-c-r` (prefer over `a-c-h`) |
| What's loaded? | `ollama ps` |
| Free the machine | `ollama stop <model>` |
| Regenerate code | `dart run build_runner build --delete-conflicting-outputs` (Flutter) |
| Verify | `flutter analyze && flutter test` or `cargo build && cargo test` |

---

**This document is your companion.** Read it when you feel lost, update it when you learn something new. Over time, it will evolve into your personal AI development playbook.
