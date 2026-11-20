# Gotchas

| Symptom | Cause | Fix |
|---|---|---|
| `ddev start` fails: hostname not resolvable, sudo needs a terminal | DDEV adds the host to `/etc/hosts` via sudo | Add it with `sudo -S -p '' ~/.local/bin/ddev-hostname <host> 127.0.0.1` and a password file, then start again |
| Encore: "file can not be found ... files/media/<customer>/..." | Dead symlink, media not synced | Phase 3 |
| Media folder stays empty after removing it from the client blacklist | The client blocks new folders over 500 MB again and re-adds them to the blacklist | Way A, or set `useNewBigFolderSizeLimit=false` only for the sync (Way B) |
| Desktop client does not start a sync after DB edit | Root ETag unchanged | `metadata.md5='_invalid_'` for the parent path and `touch` the parent folder |
| `--unsyncedfolders` has no effect | Entry with leading slash | Relative to `--path`, no leading slash, trailing slash: `preistraeger/` |
| Local files vanished after a second `media-sync.sh` run | A newly added `--exclude` removes the already synced local copy of that subfolder | Only exclude before the first sync, or confirm the removal |
| `dep db:pull -y`: option does not exist | `deployer-recipes` below 1.16.0 | Update to 1.16.x (Deployer 7) or 2.x (Deployer 8, PHP 8.3+) |
| 404 after the database pull | `tl_page.dns` still holds the live domain; `DNS_MAPPING` is applied only by `contao:migrate` in dev mode | `APP_ENV=dev` in `.env.local`, then `ddev cm` |
| `ddev cm` reports "0 SQL queries" but the DNS changed | The DNS migration reports differently | Check `select id,dns from tl_page where type='root'` |
| Hook runs `rm -rf files/media` (e.g. regionalportal) | The hook deletes anything that is not the expected symlink | Never put real folders at hook targets |
| Sass deprecation warnings during `ddev yd` | Old Bootstrap/Sass setup | Not an error; the build succeeds |
