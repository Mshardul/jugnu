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
HAS_TEXTUTIL = os.path.exists("/usr/bin/textutil")

HTML = "<html><body><h1>Title</h1><p>Hello <b>world</b>.</p></body></html>"


def call(payload: dict, env: dict | None = None) -> dict:
    proc = subprocess.run(
        [str(PY), "-I", str(ROOT / "app")],
        input=json.dumps(payload).encode(),
        capture_output=True,
        check=False,
        env={**os.environ, **(env or {})},
    )
    if not proc.stdout:
        raise AssertionError(f"empty stdout stderr={proc.stderr!r}")
    return json.loads(proc.stdout.decode())


def convert(command, src, dst, path, out):
    payload = {"api": 1, "op": "convert", "command": command, "from": src, "to": dst}
    return call({**payload, "path": path, "out": out})


@unittest.skipUnless(HAS_TEXTUTIL, "textutil is macOS only")
class ConvertOpTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.html = self.dir / "a.html"
        self.html.write_text(HTML, encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def to(self, command, src, dst, source: Path, name: str) -> Path:
        out = self.dir / name
        out.touch()
        result = convert(command, src, dst, str(source), str(out))
        self.assertTrue(result["ok"], result)
        self.assertGreater(out.stat().st_size, 0)
        return out

    def test_html_to_docx_and_back_to_plain(self):
        docx = self.to("html-docx", "html", "docx", self.html, "a.docx")
        self.assertEqual(docx.read_bytes()[:2], b"PK")
        txt = self.to("docx-plain", "docx", "plain", docx, "a.txt")
        text = txt.read_text(encoding="utf-8")
        self.assertIn("Title", text)
        self.assertIn("Hello world.", text)

    def test_html_to_rtf_and_rtf_to_docx(self):
        rtf = self.to("html-rtf", "html", "rtf", self.html, "a.rtf")
        self.assertTrue(rtf.read_bytes().startswith(b"{\\rtf"))
        docx = self.to("rtf-docx", "rtf", "docx", rtf, "b.docx")
        self.assertEqual(docx.read_bytes()[:2], b"PK")

    def test_docx_to_odt_and_back(self):
        docx = self.to("html-docx", "html", "docx", self.html, "a.docx")
        odt = self.to("docx-odt", "docx", "odt", docx, "a.odt")
        self.assertEqual(odt.read_bytes()[:2], b"PK")
        self.to("odt-docx", "odt", "docx", odt, "c.docx")
        txt = self.to("odt-plain", "odt", "plain", odt, "c.txt")
        self.assertIn("Hello world.", txt.read_text(encoding="utf-8"))

    def test_docx_to_html_and_rtf(self):
        docx = self.to("html-docx", "html", "docx", self.html, "a.docx")
        html = self.to("docx-html", "docx", "html", docx, "d.html")
        self.assertIn("Hello", html.read_text(encoding="utf-8"))
        self.to("docx-rtf", "docx", "rtf", docx, "d.rtf")

    def test_plain_to_docx_rtf_html_keeps_unicode(self):
        plain = self.dir / "p.txt"
        plain.write_text("naïve café — ✓\n", encoding="utf-8")
        for command, dst, name in (
            ("plain-docx", "docx", "p.docx"),
            ("plain-rtf", "rtf", "p.rtf"),
            ("plain-html", "html", "p.html"),
        ):
            self.to(command, "plain", dst, plain, name)
        back = self.to("docx-plain", "docx", "plain", self.dir / "p.docx", "back.txt")
        self.assertIn("café", back.read_text(encoding="utf-8"))

    def test_rtf_and_html_to_plain(self):
        rtf = self.to("html-rtf", "html", "rtf", self.html, "a.rtf")
        self.assertIn("world", self.to("rtf-plain", "rtf", "plain", rtf, "r.txt").read_text())
        self.assertIn(
            "world", self.to("html-plain", "html", "plain", self.html, "h.txt").read_text()
        )
        self.to("rtf-html", "rtf", "html", rtf, "r.html")

    def test_remote_resources_are_not_fetched(self):
        # -noload: an unreachable http:// image must not stall or fail the conversion.
        page = self.dir / "img.html"
        page.write_text('<p>hi</p><img src="http://127.0.0.1:9/x.png">', encoding="utf-8")
        self.to("html-docx", "html", "docx", page, "img.docx")

    def test_garbage_docx_is_plain_error(self):
        junk = self.dir / "x.docx"
        junk.write_text("not a document")
        out = self.dir / "x.txt"
        out.touch()
        result = convert("docx-plain", "docx", "plain", str(junk), str(out))
        self.assertFalse(result["ok"])
        self.assertNotIn("Traceback", result["error"])

    def test_relative_paths_wrong_pair_and_unknown_command_refused(self):
        self.assertFalse(convert("html-docx", "html", "docx", "a.html", "a.docx")["ok"])
        self.assertFalse(
            convert("html-docx", "docx", "html", str(self.html), str(self.dir / "o"))["ok"]
        )
        self.assertFalse(
            convert("rm-rf", "html", "docx", str(self.html), str(self.dir / "o"))["ok"]
        )


@unittest.skipUnless(HAS_TEXTUTIL, "textutil is macOS only")
class RunOpTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def run_cmd(self, command, files):
        return call(
            {"api": 1, "op": "run", "command": command, "args": {}},
            {"JUGNU_CONVERT_INJECT_PATHS": json.dumps([str(f) for f in files])},
        )

    def test_converts_copied_file_beside_original_without_overwriting(self):
        html = self.dir / "a.html"
        html.write_text(HTML, encoding="utf-8")
        (self.dir / "a.docx").write_bytes(b"keep me")
        result = self.run_cmd("html-docx", [html])
        self.assertTrue(result["ok"], result)
        self.assertEqual((self.dir / "a.docx").read_bytes(), b"keep me")
        self.assertEqual((self.dir / "a 2.docx").read_bytes()[:2], b"PK")

    def test_nothing_copied_and_wrong_kind(self):
        self.assertIn("Finder", self.run_cmd("html-docx", [])["error"])
        html = self.dir / "a.html"
        html.write_text(HTML, encoding="utf-8")
        self.assertIn("RTF", self.run_cmd("rtf-docx", [html])["error"])


class ProtocolTests(unittest.TestCase):
    def test_bad_json_and_api(self):
        proc = subprocess.run(
            [str(PY), "-I", str(ROOT / "app")], input=b"{", capture_output=True, check=False
        )
        self.assertFalse(json.loads(proc.stdout)["ok"])
        self.assertFalse(call({"api": 2, "op": "run"})["ok"])


if __name__ == "__main__":
    unittest.main()
