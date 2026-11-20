---
name: setup-kundenprojekt
description: Use when a user asks to set up a customer project from git.dd.net.hhsp.de locally (clone, DDEV, Composer, Encore, customer media from Nextcloud, database clone from the live system), or to repair such a setup.
---

# Set up a customer project locally

Set up a Contao customer project under `~/Kunden/<group>/<repo>` so that it runs in DDEV with dependencies, assets, media and a copy of the live database. Every phase first checks whether it is already done and reports one line (done / skipped / open). Never overwrite existing files, branches or databases without checking and asking.

`<skill>` below is this skill's directory (resolve the symlink). Read `reference/gotchas.md` when a phase fails.

## Rules

- Ask before: using the Nextcloud app password from the keyring, running `db:pull` (it overwrites the local database and deletes dumps on the live server), touching the Nextcloud desktop client or its sync database, changing `composer.json`/`composer.lock`, writing to `/etc/hosts`.
- Secrets: never print or log passwords. Ask for a sudo password with the host's secret-request tool (file delivery), never in chat.
- `.env.local` is gitignored and local; do not commit it. Do not commit anything unless asked.
- Customer data (media, database) stays local.

## Phase 0: Preconditions

Check `ddev`, `docker`, `git`, `nextcloudcmd`, `secret-tool` exist. Composer and Node run inside DDEV; do not require them on the host. Run `git ls-remote <url>`; the repository is only reachable from the company network, so on failure stop and say so.

## Phase 1: Clone

Clone to `~/Kunden/<group>/<repo>` (group and repo from the URL path). If it exists, `git fetch` and report the state instead of cloning. Use the requested branch, otherwise the default branch.

## Phase 2: Analyze (read only)

Run `<skill>/scripts/analyze-project.sh <repo-root>`. It reports the Contao root (the directory whose `composer.json` requires `contao/manager-bundle`, often a subfolder such as `produkte/contao`), DDEV name, PHP/Node, hostname, hook targets, `deploy.php` host and `shared_dirs`, `deployer-recipes` version, and whether `DNS_MAPPING` exists in `.env.dev`. Run all following commands from the Contao root.

## Phase 3: Media from Nextcloud

Customer media (usually `files/media/<customer>`) is not in git. The DDEV `pre-start` hook links it to `~/ownCloud/Kunden/...`. Synchronize only what the project needs, never a whole customer folder.

### 3.1 Which folders are needed

1. **Hook present:** the `~/ownCloud/...` targets from `.ddev/config.yaml` (shown by the analysis).
2. **No hook:** inspect `files/` by hand. Compare `ls files/` with `git ls-files files/`, check `.gitignore` and `deploy.php` `shared_dirs` (excluded folders are candidates), grep the code for references (`grep -rn "files/" resources templates contao src`), and let `ddev yd` name missing files ("file can not be found"). Look at the matching folder on the Nextcloud server. Show the list to the user and get confirmation before syncing.

### 3.2 Choose the way

Read the desktop client's selective-sync state from a copy of `~/ownCloud/.sync_*.db*` (the running client locks the original; copy `-wal` and `-shm` too; read-only; use `python3 -I`; table `selectivesync`, type 1 = blacklist, type 2 = whitelist).

| Customer folder in the desktop client | Action |
|---|---|
| Blacklisted (normal for new projects) | Way A |
| Not blacklisted and complete locally | nothing to do |
| Not blacklisted, missing locally | the client fetches it itself (new folders under 500 MB); otherwise Way A |

**Way A (preferred):** `<skill>/scripts/media-sync.sh <remote-path> [--exclude <rel/>]...` runs `nextcloudcmd --path` into the matching folder under `~/ownCloud`. The desktop client is not touched. Verified: the running client ignores files in a blacklisted folder (no delete, no upload, server unchanged, also after a client restart), and a second run only transfers changes. Use `--dry-run` first. Excludes are relative to the remote path, without leading slash, with trailing slash (`preistraeger/`); a leading slash silently excludes nothing. Adding an exclude to a folder that was already synced **deletes the local copy** of the excluded subfolder (verified), so confirm before excluding something that exists locally. Ask the user whether large subfolders can be skipped. The script uses the client's keyring entry as the app password; ask before the first use.

**Way B (fallback, only after confirmation, it intervenes in the client):** quit the client (`nextcloud --quit`), back up `~/ownCloud/.sync_*.db*` and `~/.config/Nextcloud/nextcloud.cfg`, remove the `selectivesync` row, set `metadata.md5='_invalid_'` for the parent path, set `useNewBigFolderSizeLimit=false` for this sync only (otherwise the client re-blocks folders over 500 MB), start the client (`setsid nohup nextcloud --background`), `touch` the parent folder to trigger the sync, wait until the folder size is stable and the log shows "Sync finished", then restore `nextcloud.cfg` and verify the blacklist did not return.

After syncing, verify the target folder exists and is non-empty. The `pre-start` hook creates the symlink on `ddev restart`.

## Phase 4: DDEV

1. `ddev start`. The hostname must be in `/etc/hosts`; if start fails with a hosts/sudo error, request the sudo password, add the host with `sudo -S -p '' ~/.local/bin/ddev-hostname <host> 127.0.0.1 < <password-file>`, then start again.
2. Create `.env.local` if missing, never overwrite:
   ```
   DATABASE_URL=mysql://db:db@db:3306/db
   MAILER_URL=smtp://localhost:1025
   APP_ENV=dev
   ```
   `APP_ENV=dev` is required: Contao applies `DNS_MAPPING` only in the dev environment (phase 7).

## Phase 5: Composer

`ddev composer install`. Credentials for `packages.heimrich-hannot.com` are in `composer.json` or `auth.json`; if both are missing, ask.

## Phase 6: Encore

`ddev yd` (prepares Encore, installs node modules, builds). "file can not be found ... files/media/..." means phase 3 is incomplete; fix that first. Sass deprecation warnings are not errors.

## Phase 7: Database from the live system

1. **Update `deployer-recipes`.** `ddev dep db:pull -y` exists since `heimrichhannot/deployer-recipes` 1.16.0 (1.15.x rejects `-y`). Check the version from the analysis:
   - PHP below 8.3 or Deployer 7: `ddev composer update heimrichhannot/deployer-recipes` (the usual `^1.1` constraint allows 1.16.x; Deployer stays 7).
   - PHP 8.3 or newer: may move to `^2.1`, which bundles Deployer 8 and conflicts with `deployer/deployer` (run `composer remove --dev deployer/deployer` first; use `vendor/bin/dep` afterwards).
   The composer file changes belong to the project; show them, do not commit.
2. **Pull.** After the user confirms: `ddev dep db:pull -y`. `-y` answers every question with yes: create dump, import locally, delete the dump on the server and locally, run the migration. Plain `-n` is not a substitute (it keeps dumps and skips the migration).
3. **DNS mapping.** Contao's `DnsMigration` (part of `contao:migrate`) rewrites the root pages' domains from `DNS_MAPPING` only in the dev environment.
   - `.env.local` has `APP_ENV=dev` (phase 4), so the migration that `db:pull -y` runs applies it. If in doubt run `ddev cm` again.
   - If `.env.dev` has no `DNS_MAPPING`, set it in `.env.local`: `DNS_MAPPING='{"<live-domain>": "<ddev-host>"}'`, then `ddev cm`. Or update `tl_page.dns` of the published root pages directly.
   - Use the domain of the published root pages (`select id,dns,published from tl_page where type='root'`); unpublished roots may carry other domains.

## Phase 8: Verify and report

`curl -sk https://<ddev-host>/` should return 200 with a `<title>`. Report per phase: done, skipped, open. Mention: `.env.local` is not committed; changed `composer.json`/`composer.lock` are uncommitted; after every new `db:pull` the dev-mode migration must run again.
