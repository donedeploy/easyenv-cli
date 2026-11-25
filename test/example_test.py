"""Validate the sample projects. Run from any directory; see examples/README.md."""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import re
import runpy
import shlex
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory
from unittest.mock import patch

import yaml
from flask import Flask
from jinja2 import Environment, StrictUndefined, TemplateError
from jsonschema import Draft7Validator
from yamllint import linter
from yamllint.config import YamlLintConfig


EXAMPLES = Path(__file__).resolve().parents[1] / "examples"
LINT = YamlLintConfig("""rules:
  key-duplicates: enable
  indentation: {spaces: 2, indent-sequences: consistent}
  trailing-spaces: enable
  new-line-at-end-of-file: enable
  new-lines: {type: unix}
""")
JINJA = Environment(trim_blocks=True, undefined=StrictUndefined)
# Guest ports used by the services in the quick starts. Local ports are configurable.
SERVICE_PORTS = {"flask": 5000, "git-repo": 5000, "docker-image": 80, "docker-compose": 8081,
                 "airflow": 8080, "argocd": 8080, "kubespray": 6443}
GREETINGS = {"flask": "hello easyenv", "git-repo": "hello from git-repo"}


def obj(properties, *required):
    return {"type": "object", "properties": properties, "required": list(required),
            "additionalProperties": False}


def array(items, **limits):
    return {"type": "array", "items": items, **limits}


# The public contract in docs/workspace-yml.md. Catalogue names are account-specific.
STRING = {"type": "string"}
NAME = {"type": "string", "pattern": r"\S"}
POSITIVE = {"type": "integer", "minimum": 1}
STACK = {"oneOf": [
    obj({"recipe": NAME, "vars": {"type": "object"}}, "recipe"),
    obj({"title": NAME, "runner": {"const": "bash"}, "script": NAME}, "title", "runner", "script"),
    obj({"title": NAME, "runner": {"const": "ansible"}, "playbook": NAME}, "title", "runner", "playbook"),
]}
MACHINE = obj({
    "title": NAME, "recipe": NAME, "description": STRING, "git_repo": NAME,
    "position": {"type": "integer"}, "stacks": array(STACK),
    "resources": obj(dict.fromkeys(("cpu", "ram_mb", "storage_gb"), POSITIVE)),
    "ports": array({"type": "string", "pattern": r"^[0-9]{1,5}(:[0-9]{1,5})?$"}),
}, "title", "recipe")
WORKSPACE = Draft7Validator(obj({
    "apiVersion": {"const": "easyenv.io/v1"}, "kind": {"const": "Workspace"},
    "metadata": obj({"title": NAME, "description": STRING}, "title"),
    "spec": obj({"duration": POSITIVE, "duration_unit": {"enum": ["minutes", "hours", "days"]},
                 "cross_connection": {"type": "boolean"}, "single_active_machine": {"type": "boolean"},
                 "virtualization_backend": NAME, "machines": array(MACHINE, minItems=1)}, "machines"),
}, "apiVersion", "kind", "metadata", "spec"))


def check(ok, message):
    if not ok:
        raise ValueError(message)


def run(args, *, cwd=None, stdin=None):
    result = subprocess.run(args, cwd=cwd, input=stdin, text=True,
                            capture_output=True, timeout=90, check=False)
    if result.returncode:
        raise ValueError(f"{args[0]} exited {result.returncode}: "
                         f"{(result.stderr or result.stdout).strip()[-1600:]}")
    return result.stdout


def read_yaml(source, label):
    problem = next(iter(linter.run(source, LINT)), None)
    check(problem is None, f"{label}: {problem}")
    return yaml.safe_load(source)


def check_kubespray(plays, machines, lab, tmp):
    template = next(t["copy"]["content"] for t in plays[0]["tasks"] if "content" in t.get("copy", {}))
    boxes = [{"host": m["title"].upper(), "ip_address": f"192.0.2.{i}"}
             for i, m in enumerate(machines, 1)]
    boxes[-1]["username"] = "workeruser"
    names = [m["title"].lower() for m in machines]
    inv = yaml.safe_load(JINJA.from_string(template).render(all_boxes=boxes, self_host=names[0]))["all"]
    check(set(inv["hosts"]) == set(names), "generated inventory hosts differ from the manifest")
    for name, box in zip(names, boxes):
        host = inv["hosts"][name]
        check((host["ansible_host"], host["ansible_user"]) ==
              (box["ip_address"], box.get("username", "easyenv")), f"wrong host variables for {name}")
    groups = inv["children"]
    for group, hosts in (("kube_node", names), ("etcd", names[:1]), ("kube_control_plane", names[:1])):
        check(set(groups[group]["hosts"]) == set(hosts), f"wrong {group} membership")
    check(set(groups["k8s_cluster"]["children"]) == {"kube_node", "kube_control_plane"}, "wrong cluster groups")

    wait = next(t["until"] for t in plays[0]["tasks"] if t.get("register") == "box_resp")
    ready = JINJA.compile_expression(wait)
    workers = [{"settings": {"ip_address": "192.0.2.4"}} for _ in machines[1:]]
    for peers, expected in ((workers[:-1], False), ([*workers[:-1], {"settings": {}}], False), (workers, True)):
        response = {"status": 200, "json": {"sibling_boxes": peers}}
        check(ready(box_resp=response, **plays[0]["vars"]) == expected, "incorrect sibling readiness check")

    # Fetch into a disposable directory. Interrupted or partial transfers must preserve the last good file.
    stub = tmp / "easyenv"
    stub.write_text('#!/bin/sh\nprintf "%s" "$REPLY_BODY"\nexit "$REPLY_STATUS"\n')
    stub.chmod(0o755)
    config = tmp / "kubeconfig"
    body = "===KUBECONFIG-BEGIN===\nclusters:\n- cluster:\n    server: https://master:6443\n"
    complete = body + "===KUBECONFIG-END===\n"
    comment = complete.replace("    server:", "    # server:")
    for reply, status in ((complete, 0), (body, 0), (complete, 1), (comment, 0), (complete * 2, 0)):
        succeeds = reply == complete and status == 0
        previous = config.read_bytes() if config.exists() else None
        env = dict(os.environ, PATH=f"{tmp}:{os.environ['PATH']}", REPLY_BODY=reply, REPLY_STATUS=str(status))
        proc = subprocess.run(["make", "-f", str(lab / "Makefile"), "kube"], cwd=tmp, env=env,
                              capture_output=True, timeout=10)
        check((proc.returncode == 0) == succeeds, "make kube returned the wrong fetch status")
        if succeeds:
            check(config.read_text() == "clusters:\n- cluster:\n    server: https://127.0.0.1:6443\n",
                  "make kube saved the wrong endpoint")
        else:
            check(config.read_bytes() == previous, "failed fetch overwrote the previous kubeconfig")
        check(config.stat().st_mode & 0o777 == 0o600, "kubeconfig must be private")


def check_postgres(plays, lab, machines):
    inventory = json.loads(run(["ansible-inventory", "-i", "inventory.ini", "--list"], cwd=lab))
    names = [m["title"] for m in machines]
    check(inventory["primary"]["hosts"] == names[:1] and set(inventory["replicas"]["hosts"]) ==
          set(names[1:]), "inventory groups differ from the manifest")
    block = next(t["blockinfile"]["block"] for t in plays[0]["tasks"] if "blockinfile" in t)
    addresses = ["192.0.2.7", "2001:db8::8"]
    results = [{"ansible_facts": {"getent_ahosts": {ip: []}}} for ip in addresses]
    hba = JINJA.from_string(block).render(replica_addresses={"results": results})
    rules = [line.split() for line in hba.splitlines() if line.strip() and not line.lstrip().startswith("#")]
    check(all(len(r) == 5 and r[:3] == ["host", "replication", "replicator"] for r in rules),
          "expected rules limited to the replication role")
    check(all(r[4] in {"md5", "scram-sha-256"} for r in rules), "replication rules must require a password")
    check({ipaddress.ip_network(r[3]) for r in rules} == {ipaddress.ip_network(ip) for ip in addresses},
          "replication rules must match the resolved replica addresses")


def check_airflow_init(service, tmp):
    # Run the actual init command with controlled outcomes for both Airflow CLI calls.
    stub = tmp / "airflow"
    stub.write_text('#!/bin/sh\necho "$1" >> "$TRACE"\n[ "$1" != "$FAIL_STEP" ]\n')
    stub.chmod(0o755)
    trace = tmp / "calls"
    for fail, calls in (("db", ["db"]), ("users", ["db", "users"]), ("", ["db", "users"])):
        trace.write_text("")
        env = dict(os.environ, PATH=f"{tmp}:{os.environ['PATH']}", TRACE=str(trace), FAIL_STEP=fail)
        result = subprocess.run([*service["entrypoint"], *service["command"]], env=env,
                                capture_output=True, timeout=10)
        check((result.returncode == 0) == (not fail) and trace.read_text().splitlines() == calls,
              f"airflow-init did not handle {fail or 'success'} correctly")


def check_compose(source, ports, lab, tmp):
    read_yaml(source, "embedded Compose file")
    cli = ["docker", "compose"]
    if not shutil.which("docker") or subprocess.run([*cli, "version"], capture_output=True, timeout=10).returncode:
        check(shutil.which("docker-compose"), "install Docker Compose v2 or newer")
        cli = ["docker-compose"]
    model = json.loads(run([*cli, "-p", "example-test", "-f", "-", "config", "--format", "json"],
                           stdin=source, cwd=lab))
    services = model["services"]
    published = {int(p["published"]) for svc in services.values() for p in svc.get("ports", [])
                 if p.get("published") and p.get("protocol", "tcp") == "tcp"}
    check(ports <= published, "workspace forwards a TCP port that Compose does not publish")
    if lab.name == "airflow":
        check_airflow_init(services["airflow-init"], tmp)


def check_links(readme):
    text = readme.read_text()
    for target in re.findall(r"\[[^\]]+\]\(([^) ]+)\)", text):
        path = target.partition("#")[0]
        if path and "://" not in path:
            check((readme.parent / path).exists(), f"{readme.name}: missing link target {path}")
    return text


def check_local(lab, tmp):
    spec = lab / ".easyenv/workspace.yml"
    # Read bytes so the newline lint rule can see CRLF in the checked-out file.
    doc = read_yaml(spec.read_bytes().decode(), spec.relative_to(lab))
    error = next(WORKSPACE.iter_errors(doc), None)
    if error:
        raise ValueError(f"{error.json_path}: {error.message}")
    machines = doc["spec"]["machines"]
    targets = re.findall(r"^\.PHONY:\s*(.+)$", (lab / "Makefile").read_text(), re.M)
    targets = set(" ".join(targets).split())
    readme = check_links(lab / "README.md")
    urls = re.findall(r"https?://(?:localhost|127\.0\.0\.1):(\d+)", readme)
    forwards = {p.split(":")[0]: int(p.split(":")[-1]) for p in machines[0].get("ports", [])}
    check(set(urls) <= forwards.keys(), "a README URL uses a port the first machine does not forward")
    if lab.name in SERVICE_PORTS:
        check(any(forwards[port] == SERVICE_PORTS[lab.name] for port in urls),
              f"no README URL forwards to the guest service on port {SERVICE_PORTS[lab.name]}")
    documented = set(re.findall(r"^\|\s*`make ([\w-]+)", readme, re.M))
    check({"up", "down", "ssh"} <= targets and documented <= targets, "missing documented Make target")
    for target in sorted(targets):
        recipe = run(["make", "-Bsn", "--", target], cwd=lab)
        check(recipe.strip(), f"make {target} has no recipe or prerequisite that runs")
        run(["bash", "-n"], stdin=recipe)
    check("expose" not in targets or machines[0].get("ports"), "make expose needs ports on the first machine")
    check(len({m["title"].casefold() for m in machines}) == len(machines), "duplicate machine title")
    # Keep each lab tied to the feature its quick start promises.
    first = machines[0]
    stacks = first.get("stacks", [])
    feature = {"airflow": "docker-compose", "docker-compose": "docker-compose", "argocd": "argocd",
               "docker-image": "docker-run", "kubespray": "install-kubespray"}
    if lab.name in feature:
        check(any(s.get("recipe", s.get("title")) == feature[lab.name] for s in stacks),
              f"missing {feature[lab.name]} stack")
    if lab.name == "airflow":
        check((lab / "dags/hello_dag.py").is_file(), "sample DAG is missing")
    if lab.name == "git-repo":
        check(first.get("git_repo"), "first-boot clone needs git_repo")
    if lab.name == "postgres-cluster":
        check((lab / "playbooks/configure-replication.yml").is_file(), "missing replication playbook")
    for machine in machines:
        ports = [p.split(":") for p in machine.get("ports", [])]
        check(all(0 < int(n) <= 65535 for p in ports for n in p), "port outside 1..65535")
        check(len({int(p[0]) for p in ports}) == len(ports), "duplicate local port")
        for stack in machine.get("stacks", []):
            if stack.get("runner") == "bash":
                run(["bash", "-n"], stdin=stack["script"])
            elif stack.get("runner") == "ansible":
                plays = read_yaml(stack["playbook"], stack["title"])
                play = tmp / "play.yml"
                play.write_text(stack["playbook"])
                run(["ansible-playbook", "--syntax-check", "-i", "localhost,", str(play)])
                if lab.name == "kubespray" and stack["title"] == "install-kubespray":
                    check_kubespray(plays, machines, lab, tmp)
            elif stack.get("recipe") == "docker-run":
                image = stack.get("vars", {}).get("image")
                check(isinstance(image, str) and image.strip(), "docker-run needs a nonempty vars.image")
            elif stack.get("recipe") == "docker-compose":
                check_compose(stack["vars"]["script"], {int(p[-1]) for p in ports}, lab, tmp)
    for path in sorted((lab / "playbooks").glob("*.y*ml")):
        plays = read_yaml(path.read_bytes().decode(), path.name)
        run(["ansible-playbook", "--syntax-check", "-i", "inventory.ini", str(path)], cwd=lab)
        if path.name == "configure-replication.yml":
            check_postgres(plays, lab, machines)
    for path in lab.rglob("*.py"):
        if not any(p.startswith(".") or p in {"venv", "__pycache__"} for p in path.relative_to(lab).parts):
            compile(path.read_bytes(), str(path), "exec")
    if lab.name in GREETINGS:
        with patch.object(Flask, "run", autospec=True) as server:
            app = runpy.run_path(str(lab / "app.py"), run_name="__main__")["app"]
        check(server.call_count == 1 and server.call_args.kwargs.get("port", 5000) == SERVICE_PORTS[lab.name],
              "app.py must start Flask on the forwarded guest port")
        result = app.test_client().get("/")
        check(result.status_code == 200 and result.data.decode() == GREETINGS[lab.name] + "\n",
              "GET / returned the wrong status or greeting")
    return doc


def check_live(lab, machine_id, machines):
    def remote(command):
        return run(["easyenv", "machine", "exec", machine_id, "--", command]).strip()

    def http(path="/"):
        return remote(f"curl -fsS --max-time 10 http://127.0.0.1:{SERVICE_PORTS[lab]}{path}")

    if lab in GREETINGS:
        check(http() == GREETINGS[lab], "unexpected Flask greeting")
    elif lab == "ubuntu":
        remote('. /etc/os-release && test "$ID:$VERSION_ID" = ubuntu:24.04')
    elif lab == "docker-image":
        check("welcome to nginx" in http().lower(), "missing nginx welcome page")
    elif lab == "docker-compose":
        output = remote('docker exec "$(docker ps -q --filter label=com.docker.compose.service=redis)" redis-cli PING')
        check(output == "PONG" and "redis commander" in http().lower(), "Redis or Commander is unavailable")
    elif lab == "airflow":
        health = json.loads(http("/health"))
        check(all(health[key]["status"] == "healthy" for key in ("scheduler", "metadatabase")), "unhealthy Airflow")
        dags = json.loads(remote('docker exec "$(docker ps -q --filter label=com.docker.compose.service=airflow-scheduler)" airflow dags list -o json'))
        check(any(d["dag_id"] == "hello_easyenv" for d in dags), "missing hello_easyenv DAG")
    elif lab in ("kubespray", "argocd"):
        nodes = json.loads(remote("sudo kubectl get nodes -o json"))["items"]
        ready = {n["metadata"]["name"] for n in nodes if any(
            c["type"] == "Ready" and c["status"] == "True" for c in n["status"]["conditions"])}
        check(ready == {m["title"].lower() for m in machines}, "unexpected set of Ready nodes")
        if lab == "argocd":
            remote("sudo kubectl -n argocd rollout status deployment/argocd-server --timeout=15s")
    elif lab == "postgres-cluster":
        sql = "SELECT count(*) FROM pg_stat_replication WHERE state = 'streaming'"
        count = remote("sudo -u postgres psql -XAt -v ON_ERROR_STOP=1 -c " + shlex.quote(sql))
        check(count == str(len(machines) - 1), f"expected {len(machines) - 1} streaming standbys, got {count}")
    else:
        raise ValueError(f"no live check defined for {lab}")


def main():
    labs = sorted(p for p in EXAMPLES.iterdir() if p.is_dir() and not p.name.startswith("."))
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--catalog", action="store_true", help="also resolve each manifest with the signed-in CLI")
    mode.add_argument("--live", nargs=2, metavar=("EXAMPLE", "MACHINE_ID"),
                      help="also probe this deployed lab through its first machine")
    args = parser.parse_args()
    all_names = {p.name for p in labs}
    if args.live:
        name, machine_id = args.live
        labs = [lab for lab in labs if lab.name == name]
        if not labs or not machine_id or machine_id.startswith("-"):
            parser.error("--live needs an example directory name and an EasyEnv machine ID")
    try:
        index = check_links(EXAMPLES / "README.md")
        listed = set(re.findall(r"^\|\s*\[.*?\]\(([\w-]+)/\)", index, re.M))
        check(listed == all_names,
              "example directories and the examples/README.md table differ")
    except (ValueError, OSError) as exc:
        parser.exit(1, f"FAIL examples/README.md: {exc}\n")
    failures = 0
    titles = set()
    for lab in labs:
        try:
            with TemporaryDirectory() as tmp:
                doc = check_local(lab, Path(tmp))
            title = doc["metadata"]["title"]
            check(title not in titles, "another example uses this workspace title")
            titles.add(title)
            if args.catalog:
                run(["easyenv", "ws", "create", "-f", ".easyenv/workspace.yml", "--dry-run"], cwd=lab)
            if args.live:
                check_live(lab.name, machine_id, doc["spec"]["machines"])
        except (ValueError, OSError, KeyError, IndexError, TypeError, StopIteration, ImportError,
                TemplateError, yaml.YAMLError, subprocess.TimeoutExpired) as exc:
            print(f"FAIL {lab.name}: {exc or type(exc).__name__}", file=sys.stderr)
            failures += 1
        else:
            print(f"PASS {lab.name}", flush=True)
    scope = "local + catalogue" if args.catalog else "local + live" if args.live else "local"
    print(f"{scope}: {len(labs) - failures}/{len(labs)} examples passed")
    return int(bool(failures) or not labs)


if __name__ == "__main__":
    sys.exit(main())
