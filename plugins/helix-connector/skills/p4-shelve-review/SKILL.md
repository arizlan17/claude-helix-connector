---
name: p4-shelve-review
description: Use when the user wants to shelve, unshelve, update a shelf, share work in progress, or have work reviewed without submitting in Helix Core.
---

# Shelving for review

A shelf stores your open files on the server without submitting them. It is the hand-off point in this workflow.

1. Put the work in a **numbered** changelist: `modify_changelists` `create` (clear description: what and why), then `edit` or `add` files into it.
2. **Before shelving**, run the `p4-guard` agent on that changelist. If it reports BLOCKED (credentials or connection files, or a path on `main`), stop and tell the user what to fix; do not shelve.
3. `modify_shelves` `shelve` with that `changelist_id`. Update later with action `update`.
4. Tell the user the changelist number and the files shelved. Offer a first-pass review with the `p4-reviewer` agent.
5. To review someone else's shelf: `query_shelves` `files` and `diff` (read only).
6. To continue someone's shelf: `modify_shelves` `unshelve` into your own changelist.

Shelving does not change `dev` or `main`. Submitting does, and only happens when the user explicitly asks.
