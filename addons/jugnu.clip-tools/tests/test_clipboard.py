import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app"))

import clipboard  # noqa: E402


def _completed(stdout: bytes, returncode: int = 0) -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(args=[], returncode=returncode, stdout=stdout, stderr=b"")


class ReadAsPlainTextTests(unittest.TestCase):
    def test_rtf_source_is_converted(self):
        rtf = b"{\\rtf1\\ansi Bold text test}"
        with patch("clipboard.subprocess.run") as run:
            run.side_effect = [_completed(rtf), _completed(b"Bold text test")]
            out = clipboard.read_as_plain_text()
        self.assertEqual(out, "Bold text test")
        textutil_call = run.call_args_list[1]
        self.assertEqual(textutil_call.args[0][0], "textutil")
        self.assertEqual(textutil_call.kwargs["input"], rtf)

    def test_plain_source_passes_through(self):
        plain = b"already plain"
        with patch("clipboard.subprocess.run") as run:
            run.side_effect = [_completed(plain), _completed(plain)]
            out = clipboard.read_as_plain_text()
        self.assertEqual(out, "already plain")

    def test_textutil_missing_falls_back_to_raw(self):
        raw = b"{\\rtf1 whatever}"
        with patch("clipboard.subprocess.run") as run:
            run.side_effect = [_completed(raw), OSError("no textutil")]
            out = clipboard.read_as_plain_text()
        self.assertEqual(out, raw.decode("utf-8"))

    def test_textutil_failure_falls_back_to_raw(self):
        raw = b"not rtf at all"
        with patch("clipboard.subprocess.run") as run:
            run.side_effect = [_completed(raw), _completed(b"", returncode=1)]
            out = clipboard.read_as_plain_text()
        self.assertEqual(out, raw.decode("utf-8"))

    def test_pbpaste_failure_raises(self):
        with patch("clipboard.subprocess.run") as run:
            run.side_effect = [_completed(b"", returncode=1)]
            with self.assertRaises(clipboard.ClipboardError):
                clipboard.read_as_plain_text()


if __name__ == "__main__":
    unittest.main()
