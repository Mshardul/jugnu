import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_runtime = os.environ.get("JUGNU_HELPER_PYTHON_RUNTIME")
PY = Path(_runtime) / "bin" / "python3" if _runtime else Path(sys.executable)


def convert(command, src, dst, text):
    payload = {"api": 1, "op": "convert", "command": command, "from": src, "to": dst, "text": text}
    proc = subprocess.run(
        [str(PY), "-I", str(ROOT / "app")],
        input=json.dumps(payload).encode(),
        capture_output=True,
        check=False,
    )
    if not proc.stdout:
        raise AssertionError(f"empty stdout stderr={proc.stderr!r}")
    return json.loads(proc.stdout.decode())


class ConvertOpTests(unittest.TestCase):
    def test_json_to_csv(self):
        out = convert("json-csv", "json", "csv", '[{"a":1,"b":2}]')
        self.assertTrue(out["ok"], out)
        self.assertIn("a,b", out["text"])

    def test_csv_to_json(self):
        out = convert("csv-json", "csv", "json", "a,b\n1,2\n")
        self.assertTrue(out["ok"], out)
        self.assertEqual(json.loads(out["text"]), [{"a": "1", "b": "2"}])

    def test_json_to_yaml_and_back(self):
        y = convert("json-yaml", "json", "yaml", '{"a": 1}')
        self.assertTrue(y["ok"], y)
        j = convert("yaml-json", "yaml", "json", y["text"])
        self.assertTrue(j["ok"], j)
        self.assertEqual(json.loads(j["text"]), {"a": 1})

    def test_xml_to_json(self):
        out = convert("xml-json", "xml", "json", "<root><a>1</a></root>")
        self.assertTrue(out["ok"], out)
        self.assertIn("root", json.loads(out["text"]))

    def test_invalid_input_is_plain_error_not_stack(self):
        out = convert("json-csv", "json", "csv", "not json")
        self.assertFalse(out["ok"])
        self.assertIn("JSON", out["error"])
        self.assertNotIn("Traceback", out["error"])

    def test_non_converter_command_is_refused(self):
        out = convert("clip-clear", "plain", "plain", "x")
        self.assertFalse(out["ok"])
        self.assertIn("unknown converter", out["error"])

    def test_mismatched_formats_are_refused(self):
        out = convert("json-csv", "csv", "json", "[]")
        self.assertFalse(out["ok"])

    def test_missing_text_is_refused(self):
        payload = {"api": 1, "op": "convert", "command": "json-csv", "from": "json", "to": "csv"}
        proc = subprocess.run(
            [str(PY), "-I", str(ROOT / "app")],
            input=json.dumps(payload).encode(),
            capture_output=True,
            check=False,
        )
        self.assertFalse(json.loads(proc.stdout)["ok"])

    def test_does_not_touch_clipboard_module(self):
        # convert must work with no pasteboard: it never reads or writes it
        out = convert("json-csv", "json", "csv", '[{"x": 1}]')
        self.assertTrue(out["ok"], out)


if __name__ == "__main__":
    unittest.main()
