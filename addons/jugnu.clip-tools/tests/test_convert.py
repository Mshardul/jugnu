import json
import os
import subprocess
import sys
import tempfile
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


def convert_file(command, src, dst, path, out):
    payload = {
        "api": 1,
        "op": "convert",
        "command": command,
        "from": src,
        "to": dst,
        "path": path,
        "out": out,
    }
    proc = subprocess.run(
        [str(PY), "-I", str(ROOT / "app")],
        input=json.dumps(payload).encode(),
        capture_output=True,
        check=False,
    )
    if not proc.stdout:
        raise AssertionError(f"empty stdout stderr={proc.stderr!r}")
    return json.loads(proc.stdout.decode())


class ConvertFileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_json_file_to_csv_file(self):
        src = self.dir / "data.json"
        src.write_text('[{"a":1,"b":2}]', encoding="utf-8")
        out = self.dir / "data.csv"
        out.touch()  # the shell reserves the output path before the call
        result = convert_file("json-csv", "json", "csv", str(src), str(out))
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["path"], str(out))
        self.assertIn("a,b", out.read_text(encoding="utf-8"))

    def test_invalid_file_is_plain_error_and_output_untouched(self):
        src = self.dir / "bad.json"
        src.write_text("not json", encoding="utf-8")
        out = self.dir / "bad.csv"
        out.touch()
        result = convert_file("json-csv", "json", "csv", str(src), str(out))
        self.assertFalse(result["ok"])
        self.assertNotIn("Traceback", result["error"])
        self.assertEqual(out.read_text(encoding="utf-8"), "")

    def test_missing_input_file(self):
        missing = str(self.dir / "nope.json")
        result = convert_file("json-csv", "json", "csv", missing, str(self.dir / "o.csv"))
        self.assertFalse(result["ok"])

    def test_binary_file_is_refused(self):
        src = self.dir / "blob.json"
        src.write_bytes(b"\xff\xfe\x00\x01")
        dst = str(self.dir / "o.csv")
        result = convert_file("json-csv", "json", "csv", str(src), dst)
        self.assertFalse(result["ok"])
        self.assertIn("UTF-8", result["error"])

    def test_non_converter_command_is_refused_in_file_mode(self):
        a, b = str(self.dir / "a"), str(self.dir / "b")
        result = convert_file("clip-clear", "plain", "plain", a, b)
        self.assertFalse(result["ok"])
        self.assertIn("unknown converter", result["error"])

    def test_missing_out_is_refused(self):
        payload = {
            "api": 1,
            "op": "convert",
            "command": "json-csv",
            "from": "json",
            "to": "csv",
            "path": "/x",
        }
        proc = subprocess.run(
            [str(PY), "-I", str(ROOT / "app")],
            input=json.dumps(payload).encode(),
            capture_output=True,
            check=False,
        )
        self.assertFalse(json.loads(proc.stdout)["ok"])


if __name__ == "__main__":
    unittest.main()
