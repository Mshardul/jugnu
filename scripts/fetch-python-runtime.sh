#!/usr/bin/env bash
set -euo pipefail
# Fetch pinned python-build-standalone builds into helpers/python-runtime/.
# Dev/CI only — consumers get the helper via registry install.

repo_root=$(cd "$(dirname "$0")/.." && pwd)
helper_dir="$repo_root/helpers/python-runtime"
lock="$helper_dir/lock.json"
marker="$helper_dir/.stage-marker"

if [[ ! -f "$lock" ]]; then
  echo "missing $lock" >&2
  exit 1
fi

expected_marker=$(
  /usr/bin/python3 - <<'PY' "$lock"
import json, sys
lock = json.load(open(sys.argv[1]))
parts = [lock["cpython"], lock.get("release", "")]
for a in lock["artifacts"]:
    parts.append(a["arch"])
    parts.append(a["sha256"])
print("|".join(parts))
PY
)

if [[ -f "$marker" && -x "$helper_dir/bin/python3" ]] && [[ "$(cat "$marker")" == "$expected_marker" ]]; then
  echo "python-runtime already staged (marker match)" >&2
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

rm -rf "$helper_dir/arch" "$helper_dir/bin"
mkdir -p "$helper_dir/arch" "$helper_dir/bin"

/usr/bin/python3 - <<'PY' "$lock" "$tmp" "$helper_dir"
import hashlib, json, os, sys, tarfile, urllib.request

lock_path, tmp, helper_dir = sys.argv[1], sys.argv[2], sys.argv[3]
lock = json.load(open(lock_path))

for art in lock["artifacts"]:
    arch = art["arch"]
    url = art["url"]
    want = art["sha256"]
    name = os.path.basename(url.split("?")[0]).replace("%2B", "+")
    dest = os.path.join(tmp, name)
    print(f"downloading {arch}…", file=sys.stderr)
    urllib.request.urlretrieve(url, dest)
    h = hashlib.sha256()
    with open(dest, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    got = h.hexdigest()
    if got != want:
        raise SystemExit(f"sha256 mismatch for {arch}: got {got}, want {want}")

    extract_root = os.path.join(tmp, f"extract-{arch}")
    os.makedirs(extract_root, exist_ok=True)
    with tarfile.open(dest, "r:gz") as tf:
        tf.extractall(extract_root)

    # install_only(_stripped) layout: python/bin/python3
    python_home = os.path.join(extract_root, "python")
    if not os.path.isdir(python_home):
        # some builds nest one level
        candidates = [
            os.path.join(extract_root, d, "python")
            for d in os.listdir(extract_root)
            if os.path.isdir(os.path.join(extract_root, d))
        ]
        python_home = next((c for c in candidates if os.path.isdir(c)), "")
    if not python_home or not os.path.isfile(os.path.join(python_home, "bin", "python3")):
        raise SystemExit(f"could not find python/bin/python3 in archive for {arch}")

    target = os.path.join(helper_dir, "arch", arch)
    if os.path.exists(target):
        import shutil
        shutil.rmtree(target)
    import shutil
    shutil.move(python_home, target)
    print(f"staged {arch} → arch/{arch}", file=sys.stderr)
PY

cat >"$helper_dir/bin/python3" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
case "$(uname -m)" in
  arm64) triple=aarch64-apple-darwin ;;
  x86_64) triple=x86_64-apple-darwin ;;
  *)
    echo "python-runtime: unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac
exec "$root/arch/$triple/bin/python3" "$@"
WRAP
chmod +x "$helper_dir/bin/python3"

printf '%s\n' "$expected_marker" >"$marker"
echo "python-runtime staged at $helper_dir" >&2
