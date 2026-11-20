#!/usr/bin/env bash
# Read-only analysis of a customer project. Usage: analyze-project.sh <repo-root>
# Prints the facts the setup phases depend on. Changes nothing.
set -uo pipefail
root="${1:?usage: analyze-project.sh <repo-root>}"

# Contao root = directory with a composer.json that requires contao/manager-bundle
croot=""
while IFS= read -r f; do
  if grep -q 'contao/manager-bundle' "$f"; then croot="$(dirname "$f")"; break; fi
done < <(find "$root" -maxdepth 4 -name composer.json -not -path '*/vendor/*' -not -path '*/node_modules/*' | sort)
[ -n "$croot" ] || { echo "contao_root: NOT FOUND"; exit 1; }
echo "contao_root: $croot"
cd "$croot" || exit 1

echo "--- ddev"
if [ -f .ddev/config.yaml ]; then
  grep -E '^(name|php_version|nodejs_version|docroot|project_tld):' .ddev/config.yaml
  n="$(grep -E '^name:' .ddev/config.yaml | awk '{print $2}')"; t="$(grep -E '^project_tld:' .ddev/config.yaml | awk '{print $2}')"
  echo "hostname: ${n}.${t:-ddev.site}"
else echo ".ddev/config.yaml: MISSING"; fi

echo "--- pre-start hook targets (Nextcloud folders needed)"
if [ -f .ddev/config.yaml ]; then
  grep -oE '[~$"A-Za-z_/{}.-]*ownCloud/[^" ]+' .ddev/config.yaml | sort -u | sed 's/^/target: /'
  grep -q 'ownCloud' .ddev/config.yaml || echo "NO HOOK: inspect files/ manually (see SKILL.md, step 3.1)"
fi

echo "--- files/"
ls -la files 2>/dev/null | tail -n +2
echo "tracked in git:"; git ls-files files | cut -d/ -f1-2 | sort -u | sed 's/^/  /'

echo "--- deploy.php"
if [ -f deploy.php ]; then
  grep -nE "host\(|setPort|setRemoteUser|set\('public_url'|'bin/php'" deploy.php | sed 's/^/  /'
  sed -n "/set('shared_dirs'/,/\]);/p" deploy.php | sed 's/^/  /'
else echo "deploy.php: MISSING"; fi

echo "--- deployer-recipes / deployer (composer.lock)"
python3 -I - <<'PY'
import json, os
if not os.path.exists('composer.lock'):
    print('composer.lock: MISSING')
else:
    lock = json.load(open('composer.lock'))
    pk = {p['name']: p['version'] for p in lock.get('packages', []) + lock.get('packages-dev', [])}
    for n in ('heimrichhannot/deployer-recipes', 'deployer/deployer', 'contao/core-bundle'):
        print(f'{n}: {pk.get(n, "not installed")}')
    print('php constraint:', json.load(open('composer.json')).get('require', {}).get('php', '?'))
PY

echo "--- env"
for f in .env .env.dev .env.local; do
  [ -f "$f" ] && { echo "$f:"; grep -E '^(APP_ENV|DNS_MAPPING|DATABASE_URL)' "$f" | sed -E 's#(://[^:]+:)[^@]*@#\1***@#; s/^/  /'; }
done
grep -q DNS_MAPPING .env.dev 2>/dev/null && echo "dns_mapping: present in .env.dev" || echo "dns_mapping: NOT in .env.dev (set manually, see SKILL.md phase 7)"
