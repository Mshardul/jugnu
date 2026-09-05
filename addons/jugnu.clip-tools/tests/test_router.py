import json
import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PY = Path(os.environ["JUGNU_HELPER_PYTHON_RUNTIME"]) / "bin" / "python3"


def run_cmd(command: str, clipboard: str, args=None):
    payload = {
        "api": 1,
        "op": "run",
        "command": command,
        "args": {"_text": clipboard, **(args or {})},
    }
    proc = subprocess.run(
        [str(PY), "-I", str(ROOT / "app")],
        input=json.dumps(payload).encode(),
        capture_output=True,
        env={**os.environ, "JUGNU_CLIP_TOOLS_INJECT": "1"},
        check=False,
    )
    if not proc.stdout:
        raise AssertionError(f"empty stdout stderr={proc.stderr!r}")
    return json.loads(proc.stdout.decode())


class RouterTests(unittest.TestCase):
    def test_unknown_command(self):
        out = run_cmd("nope", "hi")
        self.assertFalse(out["ok"])
        self.assertIn("unknown", out["error"].lower())

    def test_json_pretty(self):
        out = run_cmd("json-pretty", '{"a":1}')
        self.assertTrue(out["ok"], out)
        self.assertIn('\n', out["result"])
        self.assertIn('"a"', out["result"])

    def test_invalid_json(self):
        out = run_cmd("json-pretty", "not-json")
        self.assertFalse(out["ok"])
        self.assertIn("JSON", out["error"])

    def test_dedupe_lines(self):
        out = run_cmd("dedupe-lines", "a\nb\na\n")
        self.assertTrue(out["ok"], out)
        self.assertEqual(out["result"], "a\nb\n")

    def test_case_snake(self):
        out = run_cmd("case-snake", "Hello World")
        self.assertTrue(out["ok"], out)
        self.assertEqual(out["result"], "hello_world")

    def test_base64_roundtrip(self):
        enc = run_cmd("base64-encode", "hi")
        self.assertTrue(enc["ok"], enc)
        dec = run_cmd("base64-decode", enc["result"])
        self.assertTrue(dec["ok"], dec)
        self.assertEqual(dec["result"], "hi")

    def test_csv_json(self):
        out = run_cmd("csv-json", "a,b\n1,2\n")
        self.assertTrue(out["ok"], out)
        data = json.loads(out["result"])
        self.assertEqual(data, [{"a": "1", "b": "2"}])

    def test_yaml_json(self):
        out = run_cmd("yaml-json", "a: 1\nb: two\n")
        self.assertTrue(out["ok"], out)
        self.assertEqual(json.loads(out["result"]), {"a": 1, "b": "two"})

    def test_jwt_decode(self):
        # header {"alg":"none"} payload {"sub":"1"}
        import base64

        def b64(obj):
            raw = json.dumps(obj, separators=(",", ":")).encode()
            return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

        token = f"{b64({'alg': 'none'})}.{b64({'sub': '1'})}."
        out = run_cmd("jwt-decode", token)
        self.assertTrue(out["ok"], out)
        data = json.loads(out["result"])
        self.assertEqual(data["payload"]["sub"], "1")

    def test_slugify(self):
        out = run_cmd("slugify", "Hello, World!")
        self.assertTrue(out["ok"], out)
        self.assertEqual(out["result"], "hello-world")

    def test_xml_rejects_doctype(self):
        out = run_cmd("xml-pretty", '<!DOCTYPE foo [<!ENTITY x "y">]><a/>')
        self.assertFalse(out["ok"])
        self.assertIn("DOCTYPE", out["error"])


if __name__ == "__main__":
    unittest.main()
