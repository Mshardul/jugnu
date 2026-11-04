import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_runtime = os.environ.get("JUGNU_HELPER_PYTHON_RUNTIME")
PY = Path(_runtime) / "bin" / "python3" if _runtime else Path(sys.executable)
HAS_SIPS = os.path.exists("/usr/bin/sips")


def make_png(path: Path) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    rows = b"".join(b"\x00" + b"\xff\x00\x00" * 4 for _ in range(4))
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows))
        + chunk(b"IEND", b"")
    )


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
    return call(
        {
            "api": 1,
            "op": "convert",
            "command": command,
            "from": src,
            "to": dst,
            "path": path,
            "out": out,
        }
    )


@unittest.skipUnless(HAS_SIPS, "sips is macOS only")
class ConvertOpTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.png = self.dir / "a.png"
        make_png(self.png)

    def tearDown(self):
        self.tmp.cleanup()

    def test_png_to_jpeg(self):
        out = self.dir / "a.jpg"
        out.touch()
        result = convert("png-jpeg", "png", "jpeg", str(self.png), str(out))
        self.assertTrue(result["ok"], result)
        self.assertEqual(out.read_bytes()[:3], b"\xff\xd8\xff")

    def test_png_to_tiff_and_back(self):
        tiff = self.dir / "a.tiff"
        tiff.touch()
        self.assertTrue(convert("png-tiff", "png", "tiff", str(self.png), str(tiff))["ok"])
        back = self.dir / "b.png"
        back.touch()
        self.assertTrue(convert("tiff-png", "tiff", "png", str(tiff), str(back))["ok"])
        self.assertEqual(back.read_bytes()[:4], b"\x89PNG")

    def test_png_to_heic(self):
        out = self.dir / "a.heic"
        out.touch()
        result = convert("png-heic", "png", "heic", str(self.png), str(out))
        self.assertTrue(result["ok"], result)
        self.assertIn(b"ftyp", out.read_bytes()[:16])

    def test_not_an_image_is_plain_error(self):
        junk = self.dir / "x.png"
        junk.write_text("not an image")
        out = self.dir / "x.jpg"
        out.touch()
        result = convert("png-jpeg", "png", "jpeg", str(junk), str(out))
        self.assertFalse(result["ok"])
        self.assertNotIn("Traceback", result["error"])

    def test_missing_input(self):
        result = convert(
            "png-jpeg", "png", "jpeg", str(self.dir / "nope.png"), str(self.dir / "o.jpg")
        )
        self.assertFalse(result["ok"])

    def test_relative_paths_are_refused(self):
        self.assertFalse(convert("png-jpeg", "png", "jpeg", "a.png", "a.jpg")["ok"])

    def test_option_like_filename_cannot_inject_flags(self):
        odd = self.dir / "-s"
        make_png(odd)
        out = self.dir / "o.jpg"
        out.touch()
        self.assertTrue(convert("png-jpeg", "png", "jpeg", str(odd), str(out))["ok"])

    def test_wrong_format_pair_refused(self):
        self.assertFalse(
            convert("png-jpeg", "heic", "jpeg", str(self.png), str(self.dir / "o"))["ok"]
        )

    def test_unknown_command_refused(self):
        self.assertFalse(convert("rm-rf", "png", "jpeg", str(self.png), str(self.dir / "o"))["ok"])


@unittest.skipUnless(HAS_SIPS, "sips is macOS only")
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

    def test_converts_copied_files_beside_originals_without_overwriting(self):
        png = self.dir / "a.png"
        make_png(png)
        (self.dir / "a.jpg").write_bytes(b"keep me")
        result = self.run_cmd("png-jpeg", [png])
        self.assertTrue(result["ok"], result)
        self.assertEqual((self.dir / "a.jpg").read_bytes(), b"keep me")
        self.assertEqual((self.dir / "a 2.jpg").read_bytes()[:3], b"\xff\xd8\xff")

    def test_nothing_copied(self):
        result = self.run_cmd("png-jpeg", [])
        self.assertFalse(result["ok"])
        self.assertIn("Finder", result["error"])

    def test_wrong_kind_of_file(self):
        png = self.dir / "a.png"
        make_png(png)
        result = self.run_cmd("heic-jpeg", [png])
        self.assertFalse(result["ok"])
        self.assertIn("HEIC", result["error"])

    def test_failure_leaves_no_empty_output(self):
        junk = self.dir / "x.png"
        junk.write_text("nope")
        self.assertFalse(self.run_cmd("png-jpeg", [junk])["ok"])
        self.assertEqual(sorted(p.name for p in self.dir.iterdir()), ["x.png"])


class ProtocolTests(unittest.TestCase):
    def test_bad_json(self):
        proc = subprocess.run(
            [str(PY), "-I", str(ROOT / "app")], input=b"{", capture_output=True, check=False
        )
        self.assertFalse(json.loads(proc.stdout)["ok"])

    def test_unsupported_api(self):
        self.assertFalse(call({"api": 2, "op": "run"})["ok"])


if __name__ == "__main__":
    unittest.main()
