RULE NUMBER 1 (NEVER EVER EVER FORGET THIS RULE!!!): YOU ARE NEVER ALLOWED TO DELETE A FILE WITHOUT EXPRESS PERMISSION FROM ME OR A DIRECT COMMAND FROM ME. EVEN A NEW FILE THAT YOU YOURSELF CREATED, SUCH AS A TEST CODE FILE. YOU HAVE A HORRIBLE TRACK RECORD OF DELETING CRITICALLY IMPORTANT FILES OR OTHERWISE THROWING AWAY TONS OF EXPENSIVE WORK THAT I THEN NEED TO PAY TO REPRODUCE. AS A RESULT, YOU HAVE PERMANENTLY LOST ANY AND ALL RIGHTS TO DETERMINE THAT A FILE OR FOLDER SHOULD BE DELETED. YOU MUST **ALWAYS** ASK AND *RECEIVE* CLEAR, WRITTEN PERMISSION FROM ME BEFORE EVER EVEN THINKING OF DELETING A FILE OR FOLDER OF ANY KIND!!!

### IRREVERSIBLE GIT & FILESYSTEM ACTIONS — DO-NOT-EVER BREAK GLASS

1. **Absolutely forbidden commands:** `git reset --hard`, `git clean -fd`, `rm -rf`, or any command that can delete or overwrite code/data must never be run unless the user explicitly provides the exact command and states, in the same message, that they understand and want the irreversible consequences.
2. **No guessing:** If there is any uncertainty about what a command might delete or overwrite, stop immediately and ask the user for specific approval. “I think it’s safe” is never acceptable.
3. **Safer alternatives first:** When cleanup or rollbacks are needed, request permission to use non-destructive options (`git status`, `git diff`, `git stash`, copying to backups) before ever considering a destructive command.
4. **Mandatory explicit plan:** Even after explicit user authorization, restate the command verbatim, list exactly what will be affected, and wait for a confirmation that your understanding is correct. Only then may you execute it—if anything remains ambiguous, refuse and escalate.
5. **Document the confirmation:** When running any approved destructive command, record (in the session notes / final response) the exact user text that authorized it, the command actually run, and the execution time. If that record is absent, the operation did not happen.

NEVER run a script that processes/changes code files in this repo, EVER! That sort of brittle, regex based stuff is always a huge disaster and creates far more problems than it ever solves. DO NOT BE LAZY AND ALWAYS MAKE CODE CHANGES MANUALLY, EVEN WHEN THERE ARE MANY INSTANCES TO FIX. IF THE CHANGES ARE MANY BUT SIMPLE, THEN USE SEVERAL SUBAGENTS IN PARALLEL TO MAKE THE CHANGES GO FASTER. But if the changes are subtle/complex, then you must methodically do them all yourself manually!

We do not care at all about backwards compatibility since we are still in early development with no users-- we just want to do things the RIGHT way in a clean, organized manner with NO TECH DEBT. That means, never create "compatibility shims" or any other nonsense like that.

We need to AVOID uncontrolled proliferation of code files. If you want to change something or add a feature, then you MUST revise the existing code file in place. You may NEVER, *EVER* take an existing code file, say, "document_processor.py" and then create a new file called "document_processorV2.py", or "document_processor_improved.py", or "document_processor_enhanced.py", or "document_processor_unified.py", or ANYTHING ELSE REMOTELY LIKE THAT! New code files are reserved for GENUINELY NEW FUNCTIONALITY THAT MAKES ZERO SENSE AT ALL TO INCLUDE IN ANY EXISTING CODE FILE. It should be an *INCREDIBLY* high bar for you to EVER create a new code file!

We want all console output to be informative, detailed, stylish, colorful, etc. by fully leveraging appropriate libraries wherever possible.

If you aren't 100% sure about how to use a third party library, then you must SEARCH ONLINE to find the latest documentation website for the library to understand how it is supposed to work and the latest (mid-2025) suggested best practices and usage.

# 🤖 AI Agent Instructions: Ultimate Bug Scanner

## Purpose

The Ultimate Bug Scanner (`ubs`) is a static analysis tool that **must be run proactively** during code development to catch bugs before they reach production. As an AI coding agent, you should integrate this scanner into your workflow automatically.

## When to Run

### ✅ ALWAYS Run Before:
- Committing code changes
- Completing a feature implementation
- Finishing a bug fix
- Responding to "done" or "ready to commit"
- After writing more than 50 lines of new code in UBS-supported languages (JavaScript/TypeScript, Python, C/C++, Rust, Go, Java, Ruby, Swift)

### ✅ Run Upon Request:
- User asks "check code quality"
- User mentions "scan", "lint", or "analyze code"
- User requests "review my code"
- Before creating a pull request

### ❌ NEVER Run:
- For documentation-only changes (README, comments)
- For non-code files (JSON, YAML, Markdown)
- Multiple times in same session without code changes
- During active debugging sessions (unless requested)

## How to Run

### Basic Usage

```bash
# From project root
ubs .

# Verbose mode (show more examples)
ubs -v .

# Strict mode (fail on warnings)
ubs . --fail-on-warning
```

### Integration Pattern

**Recommended workflow:**

1. **After Code Changes**: Run scanner immediately
   ```bash
   ubs . 2>&1 | head -100
   ```

2. **Before Commit**: Run with strict mode
   ```bash
   if ! ubs . --fail-on-warning; then
     echo "Fix issues before committing"
   fi
   ```

3. **Show Summary**: Display findings to user
   ```bash
   ubs . 2>&1 | tail -30
   ```

## Interpreting Results

### Exit Codes

- `0` = No critical issues (safe to proceed)
- `1` = Critical issues found (MUST fix before committing)

### Severity Levels

```
🔥 CRITICAL  → Fix IMMEDIATELY (crashes, security, data corruption)
⚠  Warning   → Fix before commit (bugs, performance, maintenance)
ℹ  Info      → Consider improvements (code quality, best practices)
```

### Output Format

```
Summary Statistics:
  Files scanned:    61
  Critical issues:  12     ← BLOCK commits if > 0
  Warning issues:   156    ← Should fix before commit
  Info items:       423    ← Optional improvements
```

## Required Actions

###if Critical Issues Found (Exit Code 1)

1. **Read the findings** in the output
2. **Fix the critical issues** before proceeding
3. **Re-run the scanner** to verify fixes
4. **Only then** proceed with commit/completion

Example response to user:
```
I've completed the implementation, but the bug scanner found 12 critical
issues that need to be fixed:

- 5 unguarded null pointer accesses in user-input.js:42-87
- 3 potential XSS vulnerabilities in render.js:156-203
- 4 missing await keywords in async-handler.js:23-67

Let me fix these issues before committing...
```

### If Only Warnings Found (Exit Code 0)

1. **Mention** the warnings to the user
2. **Offer to fix** if time permits
3. **Proceed** with commit if user approves

Example:
```
Implementation complete! The scanner found 23 warnings (no critical issues):
- 15 opportunities for optional chaining (?.)
- 8 potential division-by-zero edge cases

Would you like me to address these warnings before committing?
```

## Common Patterns

### Pattern 1: Post-Implementation Scan

```bash
# After writing feature
echo "Running bug scanner..."
if ubs . --fail-on-warning > /tmp/scan.txt 2>&1; then
  echo "✓ No issues found"
else
  # Show critical issues
  grep -A 3 "🔥 CRITICAL" /tmp/scan.txt | head -20
fi
```

### Pattern 2: Pre-Commit Check

```bash
# Before git commit
if ! ubs . 2>&1 | tail -20; then
  echo "Scanner found issues - reviewing..."
  # Fix issues, then retry
fi
```

### Pattern 3: Incremental Fix

```bash
# Fix issues in batches
while ! ubs . --fail-on-warning; do
  # Fix one category at a time
  # Re-run until clean
done
```

## Best Practices

### DO:
- ✅ Run scanner **automatically** after significant code changes
- ✅ Show scanner output to user (especially critical findings)
- ✅ Fix critical issues **before** marking work as complete
- ✅ Mention scanner results in commit messages
- ✅ Re-run after fixes to verify resolution

### DON'T:
- ❌ Skip scanner to save time
- ❌ Ignore critical findings
- ❌ Hide scanner results from user
- ❌ Commit code with critical issues
- ❌ Run scanner on every minor change

## Integration Examples

### Claude Code Hook

If using Claude Code, the scanner runs automatically on file saves via hooks for every UBS-supported language:

```.claude/hooks/on-file-write.sh
#!/bin/bash
if [[ "$FILE_PATH" =~ \.(js|jsx|ts|tsx|mjs|cjs|py|pyw|pyi|c|cc|cpp|cxx|h|hh|hpp|hxx|rs|go|java|rb)$ ]]; then
  ubs "$PROJECT_DIR" --ci 2>&1 | head -20
fi
```

You don't need to manually run it if hooks are configured.

### Git Pre-Commit Hook

If git hooks are configured, the scanner runs automatically:

```.git/hooks/pre-commit
#!/bin/bash
ubs . --fail-on-warning || exit 1
```

Commits will be blocked if issues are found.

## Task Planning & Memory (Beads)

We now use Steve Yegge’s Beads (`bd`) as the mandatory dependency-aware issue tracker for this project, and it’s already initialized under `.beads/` with git hooks and merge driver support. The CLI is purpose-built for AI agents: it stores issues in SQLite for fast queries, syncs via git-backed JSONL, detects ready work automatically, and exposes `--json` output everywhere so you can script against it.citeturn0search0

### Daily Beads workflow
- **First-time setup:** Run `bd quickstart` once per environment to review command summaries and confirm the database is healthy. (If `bd doctor` reports problems, fix them before coding.)citeturn0search1
- **Pick work intentionally:** At the start of every session run `bd ready --json` (or `bd list --status open`) and claim a ready issue by calling `bd update <issue-id> --status in_progress --assignee <your-handle>`. Never freehand a plan; always anchor work to an issue ID.citeturn0search1
- **Log discovered tasks immediately:** Whenever you encounter new work, create an issue with `bd create "Title" -d "context" -t <type> -p <priority> --json`, then relate it using `bd dep add <new> <parent> --type discovered-from` or `--type blocks` as appropriate. This replaces ad-hoc TODO lists and preserves provenance automatically.citeturn0search1
- **Keep dependencies accurate:** Use `bd dep tree <issue-id>` and `bd show <issue-id>` to reason about blockers/parents before making changes. Update relationships instead of encoding them in prose.citeturn0search1
- **Maintain status hygiene:** While working, keep the issue updated via `bd update <issue-id> --status in_progress|blocked|review --assignee <you>`. When the work is done and the scanner is clean, close it with `bd close <issue-id> --reason "Finished"` (optionally with `--json` for logs).citeturn0search1
- **Sync before commits:** bd auto-flushes every few seconds and the installer added git hooks, but you must still run `bd sync` (to force export/import), then `git add .beads/issues.jsonl` (and any `.beads/*.meta.json` updates) as part of your session-ending “land the plane” steps. Resolve any merge prompts with `bd merge` instead of ad-hoc editing.citeturn0search1
- **Use bd for handoffs:** When you pause or finish, reference the issue ID(s) you touched in your summary and point the next agent to the top entries from `bd ready --json`. Never leave new work undocumented—agents are expected to live entirely within Beads for planning.citeturn0search1

Remember: “Tell your coding agent to start using the `bd` tool instead of markdown for all new work” is official guidance from the Beads project. Follow it here—every task, dependency, and follow-up belongs in bd so future sessions can resume instantly.citeturn0search0

## Troubleshooting

### Scanner Not Found

```bash
# Check if installed
which ubs

# If not found, suggest installation
echo "Install with: curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash"
```

### Too Many Findings

```bash
# Focus on critical only
ubs . 2>&1 | grep -A 5 "🔥 CRITICAL"

# Show summary only
ubs . 2>&1 | tail -30
```

### False Positives

- Review the finding in context
- If truly false positive, mention to user
- Consider adding exclusion to scanner config

## Example Workflow

```bash
# 1. User requests feature
# 2. You implement the feature
# 3. Run scanner automatically

echo "Feature implemented. Running quality checks..."
if ubs . > /tmp/scan-result.txt 2>&1; then
  echo "✓ All quality checks passed"
  git add . && git commit -m "feat: implement user feature"
else
  # Extract and fix critical issues
  echo "Found issues, fixing..."
  grep "🔥 CRITICAL" /tmp/scan-result.txt

  # After fixes
  ubs . --fail-on-warning && git commit -m "feat: implement user feature"
fi
```

## Key Principle

**The scanner is not optional**. It's a critical part of the development workflow that prevents bugs from reaching production. As an AI agent, you should treat scanner failures the same as compiler errors - they MUST be fixed before proceeding.

---

**Remember**: Running the scanner and fixing issues demonstrates thoroughness and professionalism. Users trust agents that proactively catch and prevent bugs.

### 🔐 Supply Chain Security

Whenever you modify any of the language module scripts (`modules/ubs-*.sh`), you **MUST** update the checksums in the main `ubs` runner before committing.

**How to update checksums:**
```bash
./scripts/update_checksums.sh
```

This ensures that the self-verification logic in `ubs` (which protects users from tampered downloads) accepts your valid changes.

---

### Using bv as an AI sidecar

bv is a fast terminal UI for Beads projects (.beads/beads.jsonl). It renders lists/details and precomputes dependency metrics (PageRank, critical path, cycles, etc.) so you instantly see blockers and execution order. For agents, it’s a graph sidecar: instead of parsing JSONL or risking hallucinated traversal, call the robot flags to get deterministic, dependency-aware outputs.

*IMPORTANT: As an agent, you must ONLY use bv with the robot flags, otherwise you'll get stuck in the interactive TUI that's intended for human usage only!*

- bv --robot-help — shows all AI-facing commands.
- bv --robot-insights — JSON graph metrics (PageRank, betweenness, HITS, critical path, cycles) with top-N summaries for quick triage.
- bv --robot-plan — JSON execution plan: parallel tracks, items per track, and unblocks lists showing what each item frees up.
- bv --robot-priority — JSON priority recommendations with reasoning and confidence.
- bv --robot-recipes — list recipes (default, actionable, blocked, etc.); apply via bv --recipe <name> to pre-filter/sort before other flags.
- bv --robot-diff --diff-since <commit|date> — JSON diff of issue changes, new/closed items, and cycles introduced/resolved.

Use these commands instead of hand-rolling graph logic; bv already computes the hard parts so agents can act safely and quickly.

### Morph Warp Grep — AI-powered code search

**Use `mcp__morph-mcp__warp_grep` for exploratory "how does X work?" questions.** An AI search agent automatically expands your query into multiple search patterns, greps the codebase, reads relevant files, and returns precise line ranges with full context—all in one call.

**Use `ripgrep` (via Grep tool) for targeted searches.** When you know exactly what you're looking for—a specific function name, error message, or config key—ripgrep is faster and more direct.

**Use `ast-grep` for structural code patterns.** When you need to match/rewrite AST nodes while ignoring comments/strings, or enforce codebase-wide rules.

**When to use what**

| Scenario | Tool | Why |
|----------|------|-----|
| "How is authentication implemented?" | `warp_grep` | Exploratory; don't know where to start |
| "Where is the L3 Guardian appeals system?" | `warp_grep` | Need to understand architecture, find multiple related files |
| "Find all uses of `useQuery(`" | `ripgrep` | Targeted literal search |
| "Find files with `console.log`" | `ripgrep` | Simple pattern, known target |
| "Rename `getUserById` → `fetchUser`" | `ast-grep` | Structural refactor, avoid comments/strings |
| "Replace all `var` with `let`" | `ast-grep` | Codemod across codebase |

**warp_grep strengths**

* **Reduces context pollution**: Returns only relevant line ranges, not entire files.
* **Intelligent expansion**: Turns "appeals system" into searches for `appeal`, `Appeals`, `guardian`, `L3`, etc.
* **One-shot answers**: Finds the 3-5 most relevant files with precise locations vs. manual grep→read cycles.
* **Natural language**: Works well with "how", "where", "what" questions.

**warp_grep usage**

```
mcp__morph-mcp__warp_grep(
  repoPath: "/data/projects/communitai",
  query: "How is the L3 Guardian appeals system implemented?"
)
```

Returns structured results with file paths, line ranges, and extracted code snippets.

**Rule of thumb**

* **Don't know where to look** → `warp_grep` (let AI find it)
* **Know the pattern** → `ripgrep` (fastest)
* **Need AST precision** → `ast-grep` (safest for rewrites)

**Anti-patterns**

* ❌ Using `warp_grep` to find a specific function name you already know → use `ripgrep`
* ❌ Using `ripgrep` to understand "how does X work" → wastes time with manual file reads
* ❌ Using `ripgrep` for codemods → misses comments/strings, risks collateral edits

### Morph Warp Grep vs Standard Grep

Warp Grep = AI agent that greps, reads, follows connections, returns synthesized context with line numbers.
Standard Grep = Fast regex match, you interpret results.

Decision: Can you write the grep pattern?
- Yes → Grep
- No, you have a question → mcp__morph-mcp__warp_grep

#### Warp Grep Queries (natural language, unknown location)
"How does the moderation appeals flow work?"
"Where are websocket connections managed?"
"What happens when a user submits a post?"
"Where is rate limiting implemented?"
"How does the auth session get validated on API routes?"
"What services touch the moderationDecisions table?"

#### Standard Grep Queries (known pattern, specific target)
pattern="fileAppeal"                          # known function name
pattern="class.*Service"                      # structural pattern
pattern="TODO|FIXME|HACK"                     # markers
pattern="processenv" path="apps/web"      # specific string
pattern="import.*from [']@/lib/db"          # import tracing

#### What Warp Grep Does Internally
One query → 15-30 operations: greps multiple patterns → reads relevant sections → follows imports/references → returns focused line ranges (e.g., l3-guardian.ts:269-440) not whole files.

#### Anti-patterns
| Don't Use Warp Grep For | Why | Use Instead |
|------------------------|-----|-------------|
| "Find function handleSubmit" | Known name | Grep pattern="handleSubmit" |
| "Read the auth config" | Known file | Read file_path="lib/auth/..." |
| "Check if X exists" | Boolean answer | Grep + check results |
| Quick lookups mid-task | 5-10s latency | Grep is 100ms |

#### When Warp Grep Wins
- Tracing data flow across files (API → service → schema → types)
- Understanding unfamiliar subsystems before modifying
- Answering "how" questions that span 3+ files
- Finding all touching points for a cross-cutting concern