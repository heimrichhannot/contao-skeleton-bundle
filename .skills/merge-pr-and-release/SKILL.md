---
name: merge-pr-and-release
description: Use when a user asks to merge a pull request and publish a versioned release, or resume an interrupted merge-and-release task.
---

# Merge a PR and publish a release

Complete the requested repository release, including branch cleanup. Use the repository's tools and conventions; GitHub CLI examples below are optional, not dependencies. A tag alone is not a published GitHub release.

## Establish state and choose the version

1. Read repository and company instructions, local overrides, status, worktrees, remotes, PR target/head, release automation, version files and tag conventions. Preserve unrelated changes; do not assume the default branch is the PR target.
2. Read remote tags and published releases in the maintained series, and inspect all changes since the previous release, including changes already merged into the target branch. A `DEV` heading or GitHub's `Latest` label is not authoritative for the highest released version. Preserve the existing tag prefix.
3. Apply SemVer: backward-compatible fixes are patch, backward-compatible features are minor, incompatible public behavior or removal of supported runtime/framework versions calls for major. Before ANY major release, or whenever version choice is uncertain, explain the concrete tradeoff and ask the user. Wait for the exact version; choosing “another version” is not a version. An explicit maintainer exception applies only to that release and must be reflected in its upgrade notes.
4. Verify effective Git author/committer/tagger identity and its configuration source (`git var GIT_AUTHOR_IDENT`, `git var GIT_COMMITTER_IDENT`, repository Git config). Do not infer permission to impersonate an earlier author. If the intended identity is missing, wrong or ambiguous, ask the user before writing history. Apply an agreed correction with scoped settings; do not change global config.
5. Verify remote publishing capability and repository access. For GitHub, confirm authenticated host/account, repository permission and release creation/read capability. Missing authentication is a concrete blocker; do not push only a tag as a substitute for the requested release.

A request to merge and release authorizes the ordinary commits, merge, branch cleanup, tag push and release publication. Do not ask for these permissions again. It does not authorize bypassing protection, rewriting existing published versions, manual publication to package registries, or unrelated maintenance. Normal tag/release webhooks (such as automatic Packagist updates) may run as a consequence of the requested release; inspect project automation and do not trigger additional publication steps.

## Prepare the candidate and merge

1. Update only the release-related files. Move applicable `Unreleased`/`DEV` entries to `## [VERSION] - YYYY-MM-DD`, using the current project-local date and leaving an empty `## [Unreleased]` above it. Follow existing language/style; use user-facing `- Added:`, `- Changed:`, `- Removed:`, etc. Include upgrade/migration requirements and meaningful compatibility changes in release notes. Do not create a Composer `version` field or other version file without a repository convention requiring it.
2. Commit and push the release preparation on the PR branch when the user requests preparation before merge. Follow an established different sequence only if consistent with the request; a fork branch without write access is a blocker, not permission to silently move release changes to the target branch. Verify the resulting identity and patch. Re-read the PR head, base, checks and reviews. Checks must apply to the actual candidate head, not the commit preceding the release commit. Run required project verification in its prescribed runtime; never suppress bundle-caused deprecations. Honor review requirements for the current head; do not bypass failing checks or branch protection. Recheck version availability and the project-local release date before merging.
3. Merge with the repository's established method and guard against head changes (for example `gh pr merge <PR> --squash --match-head-commit <HEAD>`). If someone pushes, inspect and reconcile before trying again.
4. Read back PR state and merge SHA; fetch the target branch and verify it contains that commit and the intended release files. With squash/rebase merging, the feature head is NOT necessarily the release commit. Record the exact merged release SHA; do not tag whichever commit happens to be latest later.

## Delete the requested feature branches

After verified merge, switch the main checkout to the target branch and fast-forward it. Inspect all worktrees and local/remote feature tips. Delete only branches whose content was merged and that have no new or unpushed changes. If GitHub already deleted the remote branch, verify absence and treat that step as complete; avoid combined merge/delete commands until worktree effects have been checked.

- A clean worktree holding the feature branch may be detached to permit deletion; preserve its files. Do not remove worktrees with user changes or discard untracked content.
- Verify the remote feature tip still equals the merged PR head before deleting it. Use an expected-SHA lease where supported to prevent deleting a new concurrent commit.
- Use normal local deletion first. After a squash merge, forced local deletion is appropriate only when the requested branch is clean, its tip is verified as the merged PR head (or included in it), and no worktree still holds it. Recheck the exact local tip immediately before deletion; an expected-old-SHA ref operation may be used where appropriate. The user's explicit cleanup request authorizes that specific deletion.
- If cleanup is unsafe, preserve the branch and report the precise remaining work; do not destroy changes to satisfy cleanup. Continue independent release steps only when the merged release target itself remains verified.

## Tag and publish

1. Recheck the version/tag against the remote. Create an annotated tag on the verified merged release SHA, following repository conventions. Inspect its tagger and target before pushing only that tag. Never replace an existing published tag as part of routine release creation.
2. For GitHub, publish a stable release from the verified remote tag with matching release notes and neither draft nor prerelease flags. For example, use `gh release create <TAG> --verify-tag --title <TAG> --notes-file <FILE>`. When this is the newest stable version, explicitly set it as latest if the repository follows that convention. Upload assets only when required by the project or user.
3. For repositories without GitHub, follow their release mechanism; do not claim a GitHub release exists.

## Resume safely and verify completion

After a timeout or interrupted write, read remote state before retrying. If the correct tag exists but release is missing, reuse that tag. If only a correct local tag exists, verify it before pushing. If a draft or incomplete release exists, complete its notes and publication flags only after verifying the target and requested intent. If publication already succeeded, verify it instead of creating a new version. A conflicting existing tag/release requires clarification; never force through it.

Independently read back the remote tag and peeled target (`git ls-remote` for both tag refs), compare with the intended merge SHA, and read the published release's version, URL, notes and draft/prerelease state. Verify requested branch deletion, final checkout and preserved user changes. Report the actual version and release URL, checks and any remaining blocker. Never equate a successful push or a GitHub release's branch-name `targetCommitish` with proof of the tag target.
