# PDF Tools

Page tools for one PDF, or a few of them. Every command that changes a file writes a new file next to the original. The original stays as it is.

A locked PDF has to be opened with **Remove PDF password** first. That command asks for the password when the file will not open. It does not guess passwords. A PDF that already opens, including one with only an owner restriction, is copied without asking.

| Command | What it does |
|---|---|
| Remove PDF password | Unlocked copy beside the original |
| Merge PDFs | One PDF, in the order you choose |
| Split PDF | Each page, or ranges such as `1-3, 4-6` |
| Extract pages | The pages you list, such as `1, 3-5` |
| Reorder PDF pages | Every page once, such as `3, 1, 2` |
| Rotate PDF pages | 90, 180, or 270 degrees |
| Page count | How many pages |
| Add page numbers | A number at the bottom of each page |
| Add / edit bookmarks | A copy with one bookmark added or renamed |
| PDF info | Pages, size, encryption, version |
| Extract PDF text | The embedded text, not a scan |
| Compress PDF | A smaller copy when the images inside can shrink |
| JPG to PDF | One page per JPEG |
| PDF to JPG / PNG | One image per page |
| Flatten PDF forms | Form fields baked into the page |
| Grayscale PDF | A black and white copy, as images of the pages |

Finder can show **Remove PDF Password** when you right-click a PDF. That item is off until you add it during install, or turn on **Show In Finder Menu** in the addon’s Settings. Turning the addon off, uninstalling it, or switching the setting off removes the item.

Build the helper before a command can run:

```bash
make pdf-tools
```
