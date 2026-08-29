#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rendered="$(mktemp)"
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -f "$rendered"
}
trap cleanup EXIT

helm template service-registry-github-web "$repo_root" >"$rendered"

server="$(python3 - "$rendered" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as stream:
    resources = list(yaml.safe_load_all(stream))

by_kind = {resource["kind"]: resource for resource in resources}
assert set(by_kind) == {"Deployment", "Service"}, set(by_kind)

deployment = by_kind["Deployment"]
service = by_kind["Service"]
assert deployment["metadata"]["name"] == "github-web"
assert deployment["spec"]["template"]["metadata"]["labels"]["app"] == "github-web"
assert "nodeSelector" not in deployment["spec"]["template"]["spec"]
assert "tolerations" not in deployment["spec"]["template"]["spec"]
container = deployment["spec"]["template"]["spec"]["containers"][0]
assert container["image"] == "public.ecr.aws/docker/library/node:22-alpine@sha256:76789712cd1ae89a1225eac9077010d68987a423588042dac30446f502f1858c"
assert deployment["spec"]["template"]["spec"]["securityContext"]["runAsUser"] == 1000
assert deployment["spec"]["template"]["spec"]["securityContext"]["runAsGroup"] == 1000
assert container["command"] == ["node"]
assert container["args"][0] == "-e"
server = container["args"][1]
assert "Nalej Service Registry GitHub fixture" in server
assert "source-proof" in server
assert "src=" not in server
assert "href=" not in server
assert service["metadata"]["name"] == "github-web"
assert service["spec"]["selector"] == {"app": "github-web"}
assert service["spec"]["ports"][0]["port"] == 3000
print(server)
PY
)"

printf '%s\n' "$server" | node --check -
PORT=19898 node -e "$server" >/dev/null 2>&1 &
server_pid=$!
for _ in {1..30}; do
  if curl -fsS http://127.0.0.1:19898/api/ready >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
curl -fsS http://127.0.0.1:19898/ | grep -q 'id="source-proof"'
curl -fsS http://127.0.0.1:19898/api/health | grep -q '"status":"ok"'

second_render="$(helm template service-registry-second-entry "$repo_root")"
grep -q '^  name: second-entry$' <<<"$second_render"

if helm template github-web "$repo_root" >/dev/null 2>&1; then
  echo "Helm release name without the service-registry- prefix unexpectedly rendered" >&2
  exit 1
fi

echo "fixture render contract verified"
