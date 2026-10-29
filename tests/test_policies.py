import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIVE = "--live" in sys.argv
if LIVE:
    sys.argv.remove("--live")


def container(name="app"):
    return {"name": name, "image": "example.invalid/app:v1.0.0",
            "resources": {"requests": {"cpu": "10m", "memory": "16Mi"},
                          "limits": {"cpu": "100m", "memory": "32Mi"}},
            "securityContext": {"privileged": False}}


def workload(kind="Pod", namespace="kubedeploy-demo"):
    labels = {"app": "policy-check"}
    pod = {"containers": [container()]}
    result = {"apiVersion": "v1", "kind": kind,
              "metadata": {"name": "kubedeploy-policy-check", "namespace": namespace}}
    if kind == "Pod":
        result["spec"] = pod
    elif kind in ("Job", "CronJob"):
        result["apiVersion"] = "batch/v1"
        pod["restartPolicy"] = "Never"
        job = {"template": {"metadata": {"labels": labels}, "spec": pod}}
        result["spec"] = job if kind == "Job" else {"schedule": "0 * * * *", "jobTemplate": {"spec": job}}
    else:
        result["apiVersion"] = "apps/v1"
        result["spec"] = {"selector": {"matchLabels": labels},
                          "template": {"metadata": {"labels": labels}, "spec": pod}}
        if kind == "StatefulSet":
            result["spec"]["serviceName"] = "policy-check"
    return result, pod


class PolicyTests(unittest.TestCase):
    def check(self, obj, expected=None):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "object.json"
            path.write_text(json.dumps(obj))
            if LIVE:
                command = ["kubectl", "--context", "k3d-kubedeploy", "create", "--dry-run=server", "-f", str(path)]
            else:
                command = [str(ROOT / ".tools/bin/gator"), "test", "-f", str(ROOT / "policies/templates"),
                           "-f", str(ROOT / "policies/constraints"), "-f", str(ROOT / "policies/expansion.yaml"), "-f", str(path)]
            result = subprocess.run(command, text=True, capture_output=True, timeout=30)
            output = result.stdout + result.stderr
            if expected is None:
                self.assertEqual(result.returncode, 0, output)
            else:
                self.assertNotEqual(result.returncode, 0, output)
                self.assertIn(expected, output)
                if LIVE:
                    self.assertIn('admission webhook "validation.gatekeeper.sh" denied the request', output)

    def test_workload_templates(self):
        for kind in ("Pod", "Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "Job", "CronJob"):
            with self.subTest(kind=kind, case="allowed"):
                self.check(workload(kind)[0])
            for field, expected in (("privileged", "demo-no-privileged"),
                                    ("resources", "demo-required-resources"), ("image", "demo-image-tags")):
                with self.subTest(kind=kind, case=field):
                    obj, pod = workload(kind)
                    c = pod["containers"][0]
                    if field == "privileged":
                        c["securityContext"]["privileged"] = True
                    elif field == "resources":
                        c.pop("resources")
                    else:
                        c["image"] = "example.invalid/app:latest"
                    self.check(obj, expected)

    def test_resource_keys(self):
        for section in ("requests", "limits"):
            for resource in ("cpu", "memory"):
                with self.subTest(section=section, resource=resource):
                    obj, pod = workload()
                    del pod["containers"][0]["resources"][section][resource]
                    if section == "requests":
                        del pod["containers"][0]["resources"]["limits"][resource]
                    self.check(obj, "demo-required-resources")

    def test_api_defaults_requests_from_limits(self):
        obj, pod = workload()
        del pod["containers"][0]["resources"]["requests"]
        self.check(obj, None if LIVE else "demo-required-resources")

    def test_null_resources(self):
        obj, pod = workload()
        pod["containers"][0]["resources"] = None
        self.check(obj, "demo-required-resources")

    def test_image_references(self):
        digest = "sha256:" + "a" * 64
        for image in ("example.invalid/app:latest", "example.invalid/app", "example.invalid:5000/app",
                      "example.invalid/app:latest@" + digest):
            with self.subTest(image=image):
                obj, pod = workload()
                pod["containers"][0]["image"] = image
                self.check(obj, "demo-image-tags")
        for image in ("example.invalid:5000/app:v1", "example.invalid/app@" + digest):
            with self.subTest(image=image):
                obj, pod = workload()
                pod["containers"][0]["image"] = image
                self.check(obj)

    def test_init_containers(self):
        for field, expected in (("privileged", "demo-no-privileged"), ("resources", "demo-required-resources"),
                                ("image", "demo-image-tags")):
            with self.subTest(field=field):
                obj, pod = workload("Deployment")
                init = container("init")
                if field == "privileged":
                    init["securityContext"]["privileged"] = True
                elif field == "resources":
                    init.pop("resources")
                else:
                    init["image"] = "example.invalid/init:latest"
                pod["initContainers"] = [init]
                self.check(obj, expected)

    @unittest.skipIf(LIVE, "Ephemeral containers require a separate subresource update")
    def test_ephemeral_containers(self):
        for field, expected in (("privileged", "demo-no-privileged"), ("image", "demo-image-tags")):
            with self.subTest(field=field):
                obj, pod = workload()
                ephemeral = container("debug")
                ephemeral.pop("resources")
                if field == "privileged":
                    ephemeral["securityContext"]["privileged"] = True
                else:
                    ephemeral["image"] = "example.invalid/debug:latest"
                pod["ephemeralContainers"] = [ephemeral]
                self.check(obj, expected)

    def test_other_namespaces(self):
        obj, pod = workload(namespace="default")
        c = pod["containers"][0]
        c["securityContext"]["privileged"] = True
        c["image"] = "example.invalid/app:latest"
        c.pop("resources")
        self.check(obj)

    def test_cluster_scoped_request(self):
        self.check({"apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRole",
                    "metadata": {"name": "kubedeploy-policy-check"}, "rules": []})


if __name__ == "__main__":
    unittest.main(verbosity=2)
