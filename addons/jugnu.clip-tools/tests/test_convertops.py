import json
import unittest

from test_convert import convert


def ok(command, src, dst, text):
    out = convert(command, src, dst, text)
    assert out["ok"], out
    return out["text"]


class TabularTests(unittest.TestCase):
    def test_json_to_tsv_and_back(self):
        tsv = ok("json-tsv", "json", "tsv", '[{"a":1,"b":"x y"}]')
        self.assertEqual(tsv, "a\tb\n1\tx y\n")
        back = json.loads(ok("tsv-json", "tsv", "json", tsv))
        self.assertEqual(back, [{"a": "1", "b": "x y"}])

    def test_csv_tsv_roundtrip_keeps_quoted_commas(self):
        tsv = ok("csv-tsv", "csv", "tsv", 'a,b\n"1,5",2\n')
        self.assertEqual(tsv, "a\tb\n1,5\t2\n")
        self.assertEqual(ok("tsv-csv", "tsv", "csv", tsv), 'a,b\n"1,5",2\n')

    def test_empty_input_is_plain_error(self):
        out = convert("csv-tsv", "csv", "tsv", "")
        self.assertFalse(out["ok"])


class MarkdownTableTests(unittest.TestCase):
    def test_csv_to_markdown_table(self):
        md = ok("csv-markdown-table", "csv", "markdown-table", "a,b\n1,2\n")
        self.assertEqual(md, "| a | b |\n| --- | --- |\n| 1 | 2 |\n")

    def test_pipe_in_cell_is_escaped_and_restored(self):
        md = ok("json-markdown-table", "json", "markdown-table", '[{"a":"x|y"}]')
        self.assertIn("x\\|y", md)
        rows = json.loads(ok("markdown-table-json", "markdown-table", "json", md))
        self.assertEqual(rows, [{"a": "x|y"}])

    def test_markdown_table_to_csv(self):
        csv_text = ok(
            "markdown-table-csv", "markdown-table", "csv", "| a | b |\n|---|:--:|\n| 1 | 2 |\n"
        )
        self.assertEqual(csv_text, "a,b\n1,2\n")

    def test_no_table_is_error(self):
        self.assertFalse(convert("markdown-table-csv", "markdown-table", "csv", "just words")["ok"])


class JsonXmlTests(unittest.TestCase):
    def test_object_with_list(self):
        xml = ok("json-xml", "json", "xml", '{"cart":{"item":["a","b"],"n":2,"ok":true}}')
        self.assertIn("<cart>", xml)
        self.assertEqual(xml.count("<item>"), 2)
        self.assertIn("<ok>true</ok>", xml)

    def test_array_gets_root_wrapper(self):
        xml = ok("json-xml", "json", "xml", "[1,2]")
        self.assertTrue(xml.startswith("<root>"))
        self.assertEqual(xml.count("<item>"), 2)

    def test_text_is_escaped(self):
        xml = ok("json-xml", "json", "xml", '{"a":"<b>&"}')
        self.assertIn("&lt;b&gt;&amp;", xml)

    def test_bad_element_name_is_refused(self):
        self.assertFalse(convert("json-xml", "json", "xml", '{"1bad":1}')["ok"])
        self.assertFalse(convert("json-xml", "json", "xml", '{"xmlfoo":1}')["ok"])


class MarkdownHtmlTests(unittest.TestCase):
    def test_common_blocks(self):
        html = ok(
            "markdown-html",
            "markdown",
            "html",
            "# Title\n\nHello **bold** and *it* `c`.\n\n- a\n- b\n\n1. x\n",
        )
        self.assertIn("<h1>Title</h1>", html)
        self.assertIn("<strong>bold</strong>", html)
        self.assertIn("<em>it</em>", html)
        self.assertIn("<code>c</code>", html)
        self.assertIn("<ul>", html)
        self.assertIn("<ol>", html)

    def test_raw_html_is_escaped(self):
        html = ok("markdown-html", "markdown", "html", "<script>alert(1)</script>")
        self.assertNotIn("<script>", html)
        self.assertIn("&lt;script&gt;", html)

    def test_javascript_links_are_dropped(self):
        html = ok(
            "markdown-html", "markdown", "html", "[x](javascript:alert(1)) [ok](https://a.dev/p)"
        )
        self.assertNotIn("javascript:", html)
        self.assertIn('<a href="https://a.dev/p">ok</a>', html)

    def test_fenced_code_is_literal(self):
        html = ok("markdown-html", "markdown", "html", "```\n# not a heading\n```\n")
        self.assertIn("<pre><code># not a heading</code></pre>", html)


class HtmlTextTests(unittest.TestCase):
    PAGE = (
        "<html><head><title>t</title><style>p{}</style></head><body><h2>Hi</h2>"
        "<p>A <b>bold</b> <a href='https://a.dev'>link</a>.</p><script>x()</script>"
        "<ul><li>one</li><li>two</li></ul></body></html>"
    )

    def test_html_to_markdown(self):
        md = ok("html-markdown", "html", "markdown", self.PAGE)
        self.assertIn("## Hi", md)
        self.assertIn("**bold**", md)
        self.assertIn("[link](https://a.dev)", md)
        self.assertIn("- one", md)
        self.assertNotIn("x()", md)
        self.assertNotIn("p{}", md)

    def test_html_to_plain_drops_markup_and_scripts(self):
        text = ok("html-plain", "html", "plain", self.PAGE)
        self.assertIn("Hi", text)
        self.assertIn("A bold link.", text)
        self.assertNotIn("<", text)
        self.assertNotIn("x()", text)

    def test_unsafe_href_loses_its_target(self):
        md = ok("html-markdown", "html", "markdown", "<a href='javascript:alert(1)'>x</a>")
        self.assertNotIn("javascript", md)


if __name__ == "__main__":
    unittest.main()
