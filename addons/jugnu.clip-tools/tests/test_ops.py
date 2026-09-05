import unittest

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app"))

from ops.lines import dedupe_lines, sort_lines  # noqa: E402
from ops.caseops import case_camel, case_snake  # noqa: E402
from ops.structured import json_minify, json_path  # noqa: E402


class OpsUnitTests(unittest.TestCase):
    def test_dedupe(self):
        out, _ = dedupe_lines("a\nb\na\n", {})
        self.assertEqual(out, "a\nb\n")

    def test_sort(self):
        out, _ = sort_lines("b\na\n", {})
        self.assertEqual(out, "a\nb\n")

    def test_camel(self):
        out, _ = case_camel("hello world", {})
        self.assertEqual(out, "helloWorld")

    def test_snake(self):
        out, _ = case_snake("Hello World", {})
        self.assertEqual(out, "hello_world")

    def test_json_minify(self):
        out, _ = json_minify('{\n  "a": 1\n}', {})
        self.assertEqual(out, '{"a":1}')

    def test_json_path(self):
        out, _ = json_path('{"items":[{"name":"x"}]}', {"path": "items.0.name"})
        self.assertEqual(out, "x")


if __name__ == "__main__":
    unittest.main()
