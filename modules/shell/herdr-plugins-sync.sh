# Link the Nix-declared Herdr plugins (programs.herdr.plugins) and unlink the
# ones this script linked before that are no longer declared. Linking works
# without a running server (the CLI writes the registry directly); unlinking
# needs one, so a failed unlink stays recorded and is retried next time.
# Herdr failures only warn, so activation never aborts over an unreachable
# or incompatible server.
#
# Usage: herdr-plugins-sync DESIRED_JSON   ({"plugin.id": "/nix/store/..."})
desired=$1
state="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/nix-managed-plugins.json"
mkdir -p "$(dirname "$state")"

warn() { echo "herdr-plugins-sync: $*" >&2; }

previous='[]'
[ -f "$state" ] && previous=$(cat "$state")

pending=()
for id in $(jq -rn --argjson prev "$previous" --slurpfile want "$desired" \
  '$prev - ($want[0] | keys) | .[]'); do
  herdr plugin unlink "$id" >/dev/null 2>&1 || {
    warn "could not unlink $id (no running server?); will retry"
    pending+=("$id")
  }
done

for id in $(jq -r 'keys[]' "$desired"); do
  root=$(realpath "$(jq -r --arg id "$id" '.[$id]' "$desired")")
  current=$(herdr plugin list --plugin "$id" --json 2>/dev/null |
    jq -r '.result.plugins[0] | select(.enabled) | .plugin_root' 2>/dev/null || true)
  [ "$current" = "$root" ] && continue
  linked=$(herdr plugin link "$root" 2>&1) || {
    warn "could not link $id: $linked"
    continue
  }
  got=$(jq -r '.result.plugin.plugin_id // empty' <<<"$linked" 2>/dev/null || true)
  [ -z "$got" ] || [ "$got" = "$id" ] || warn "$root declares plugin id $got, not $id"
done

jq -c --args 'keys + $ARGS.positional | unique' "${pending[@]}" <"$desired" >"$state"
