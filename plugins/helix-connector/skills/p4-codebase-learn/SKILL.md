---
name: p4-codebase-learn
description: Use after first run, before building a feature in an unfamiliar area, or when asked to learn, document or refresh knowledge of the existing code base. Reads the workspace (read-only), understands the domain, conventions, best practices and existing reusable methods, and saves a CODEBASE_NOTES.md that later work follows so new code reuses what exists.
---

# Learn the existing code base

Goal: before writing new code, know the project well enough to match its domain language, follow its conventions, and **reuse existing methods instead of duplicating them**.

## Hard rules
- Read-only on the server and on source files. The only file you may write is `CODEBASE_NOTES.md` in the workspace root, and only after the user approves the draft.
- Never read or copy secrets (`.env*`, `secrets/`, keys, passwords, tokens in config). Name keys only.
- Never invent. Every statement needs a `path:line` or is marked "unclear". A convention needs at least three examples.
- Do not change source files, and do not run `p4 edit`, `shelve` or `submit` here.
- If the login is expired, stop and tell the user to run `p4 login`.

## Step 1: Scope
1. Ask which area to learn if it is not clear (whole workspace, one module, or one folder). Default: the folders this user can write (see the `helix-first-run` block in `CLAUDE.md`), since that is where new code will go.
2. If `CODEBASE_NOTES.md` exists, read it. Offer to refresh only what changed (compare its recorded changelist with `p4 changes -m1 <path>...`).

## Step 2: Analyse
Delegate to the `p4-codebase-analyst` agent with the scope. It returns: stack and build, structure, domain glossary, conventions, reusable methods, best practices and anti-patterns, change habits, and gaps. For a large workspace, run it per module and merge the results.

## Step 3: Draft the notes
Show the draft to the user in chat first, using this shape:

~~~
# Codebase notes
Scope: <paths>   Learned: <date>   At changelist: <number>

## Stack and commands
## Structure
## Domain glossary
## Conventions to follow
## Reuse before you write   (table: need | existing method/class | path:line)
## Best practices seen
## Watch out for
## How changes are described here
## Unknowns
~~~
Keep it under about 300 lines: link to paths rather than pasting code.

## Step 4: Save after approval
1. Write `CODEBASE_NOTES.md` in the workspace root (create or replace; keep the user's manual edits if refreshing).
2. Add `CODEBASE_NOTES.md` to `.p4ignore` unless the user wants it versioned in the depot.
3. Add one line to `CLAUDE.md` if missing: `Before writing code, read CODEBASE_NOTES.md and reuse the methods listed there.`
4. Tell the user what was written.

## Using the notes later
When implementing anything, check the "Reuse before you write" table first. If an existing method fits, use it. If you must add something new, say why nothing existing fits and match the listed conventions and glossary terms. Re-run this skill when the code has changed a lot (the recorded changelist is the marker).
