import json
import os
import subprocess
import sys
import tempfile
import unittest
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_runtime = os.environ.get("JUGNU_HELPER_PYTHON_RUNTIME")
PY = Path(_runtime) / "bin" / "python3" if _runtime else Path(sys.executable)
HAS_AFCONVERT = os.path.exists("/usr/bin/afconvert")


def make_wav(path: Path) -> None:
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(44100)
        handle.writeframes(b"\x00\x10" * 4410)


def make_mp3(path: Path) -> None:
    """Silent MPEG-1 Layer III frames: 128 kbps, 44.1 kHz, 417-byte frames."""
    frame = b"\xff\xfb\x90\x00" + b"\x00" * 413
    path.write_bytes(frame * 40)


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


@unittest.skipUnless(HAS_AFCONVERT, "afconvert is macOS only")
class ConvertOpTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.wav = self.dir / "a.wav"
        make_wav(self.wav)

    def tearDown(self):
        self.tmp.cleanup()

    def to(self, command, src, dst, source: Path, name: str) -> Path:
        out = self.dir / name
        out.touch()
        result = convert(command, src, dst, str(source), str(out))
        self.assertTrue(result["ok"], result)
        self.assertGreater(out.stat().st_size, 0)
        return out

    def test_wav_to_aiff_and_back(self):
        aiff = self.to("wav-aiff", "wav", "aiff", self.wav, "a.aiff")
        self.assertEqual(aiff.read_bytes()[:4], b"FORM")
        back = self.to("aiff-wav", "aiff", "wav", aiff, "b.wav")
        self.assertEqual(back.read_bytes()[:4], b"RIFF")

    def test_wav_to_m4a_and_back(self):
        m4a = self.to("wav-m4a", "wav", "m4a", self.wav, "a.m4a")
        self.assertIn(b"ftyp", m4a.read_bytes()[:16])
        self.to("m4a-wav", "m4a", "wav", m4a, "c.wav")
        self.to("m4a-aiff", "m4a", "aiff", m4a, "c.aiff")

    def test_wav_to_caf_and_back(self):
        caf = self.to("wav-caf", "wav", "caf", self.wav, "a.caf")
        self.assertEqual(caf.read_bytes()[:4], b"caff")
        self.to("caf-wav", "caf", "wav", caf, "d.wav")

    def test_aiff_to_m4a(self):
        aiff = self.to("wav-aiff", "wav", "aiff", self.wav, "a.aiff")
        self.to("aiff-m4a", "aiff", "m4a", aiff, "e.m4a")

    def test_mp3_is_readable_as_a_source(self):
        mp3 = self.dir / "a.mp3"
        make_mp3(mp3)
        self.to("mp3-wav", "mp3", "wav", mp3, "m.wav")
        self.to("mp3-m4a", "mp3", "m4a", mp3, "m.m4a")

    def test_garbage_is_plain_error(self):
        junk = self.dir / "x.wav"
        junk.write_text("not audio")
        out = self.dir / "x.aiff"
        out.touch()
        result = convert("wav-aiff", "wav", "aiff", str(junk), str(out))
        self.assertFalse(result["ok"])
        self.assertNotIn("Traceback", result["error"])

    def test_relative_paths_refused(self):
        self.assertFalse(convert("wav-aiff", "wav", "aiff", "a.wav", "a.aiff")["ok"])

    def test_wrong_pair_and_unknown_command_refused(self):
        self.assertFalse(
            convert("wav-aiff", "aiff", "wav", str(self.wav), str(self.dir / "o"))["ok"]
        )
        self.assertFalse(convert("rm-rf", "wav", "aiff", str(self.wav), str(self.dir / "o"))["ok"])


@unittest.skipUnless(HAS_AFCONVERT, "afconvert is macOS only")
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
        wav = self.dir / "a.wav"
        make_wav(wav)
        (self.dir / "a.aiff").write_bytes(b"keep me")
        result = self.run_cmd("wav-aiff", [wav])
        self.assertTrue(result["ok"], result)
        self.assertEqual((self.dir / "a.aiff").read_bytes(), b"keep me")
        self.assertEqual((self.dir / "a 2.aiff").read_bytes()[:4], b"FORM")

    def test_nothing_copied_and_wrong_kind(self):
        self.assertIn("Finder", self.run_cmd("wav-aiff", [])["error"])
        wav = self.dir / "a.wav"
        make_wav(wav)
        self.assertIn("AIFF", self.run_cmd("aiff-wav", [wav])["error"])

    def test_failure_leaves_no_empty_output(self):
        junk = self.dir / "x.wav"
        junk.write_text("nope")
        self.assertFalse(self.run_cmd("wav-aiff", [junk])["ok"])
        self.assertEqual(sorted(p.name for p in self.dir.iterdir()), ["x.wav"])


class ProtocolTests(unittest.TestCase):
    def test_bad_json_and_api(self):
        proc = subprocess.run(
            [str(PY), "-I", str(ROOT / "app")], input=b"{", capture_output=True, check=False
        )
        self.assertFalse(json.loads(proc.stdout)["ok"])
        self.assertFalse(call({"api": 2, "op": "run"})["ok"])


if __name__ == "__main__":
    unittest.main()
