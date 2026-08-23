---
name: GitHub publishing
description: How to publish a local feature commit when the workspace SSH proxy cannot authenticate a push.
---

Use the authenticated GitHub connector’s Git Data API to create a tree, commit,
feature-branch ref, and pull request when the configured Replit SSH remote
rejects authentication. Treat GitHub’s default branch as read-only: build the
new commit with that branch as its parent, update only the feature ref, then
open the PR with `base` set to the default branch.

**Why:** The configured SSH proxy can have no available public-key or password
credential even though the connected GitHub integration has repository access.

**How to apply:** Read the current base ref and tree first. Filter deletion
entries to paths that exist in the base tree, retain each existing node’s
mode/type for deletes, and verify the pull request’s `head` and `base` before
reporting success.