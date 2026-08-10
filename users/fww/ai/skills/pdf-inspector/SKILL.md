---
name: pdf-inspector
description: Fast local PDF text extraction and classification via the pdf-inspector Rust CLI (pdf2md / detect-pdf). Converts text-based PDFs to clean Markdown in milliseconds with NO OCR, NO model downloads, NO network, and NO cache writes. Use this skill whenever the user asks to read, parse, extract text from, summarize, convert, inspect, or ask about the contents of ANY .pdf file — trigger even when they don't name a tool ("what's in this PDF", "read this", "turn this into markdown", "is this scanned"). Classifies a PDF as text-based / scanned / image-based / mixed, extracts text instantly from text-based pages, and reports exactly which pages need OCR for scanned documents (does not perform OCR itself). Handles multi-column layouts, tables, and position-aware extraction. For pure speed on text-based PDFs this beats any OCR pipeline; for scanned/image-only PDFs it reports and stops rather than pretending to extract.
---

# pdf-inspector

A fast, local-first PDF tool for extracting text and classifying documents. Two binaries back this skill: `detect-pdf` (classify + route) and `pdf2md` (extract to Markdown). Both are pure-Rust, stateless, and leave the filesystem untouched unless you explicitly ask to write a file.

The reason this skill exists over heavier OCR pipelines (MinerU, Marker, jztan/pdf-mcp): roughly half of all PDFs are born-digital with a real text layer, and running a multi-GB VLM over them is pure waste. pdf-inspector reads the text layer directly in tens of milliseconds and tells you which pages genuinely need OCR, so you only pay the OCR cost where it's actually needed.

## Getting the PDF into reach — local vs remote

pdf-inspector operates on a **local file path**. How you obtain that path depends on where the PDF is:

- **Already a local file** the user pointed at — use the path directly.
- **A URL the user gave you** (e.g. an arxiv paper, a report link) — download it with `curl`, not with a web-fetch tool:
  ```bash
  curl -sL -o /tmp/<name>.pdf "<url>"     # then run detect-pdf / pdf2md on /tmp/<name>.pdf
  ```
  The reason is structural: pdf-inspector reads a **file path**, and `curl` gives you one on disk. A web-fetch tool returns a content stream, not a file — so even if it handled PDF cleanly, you'd still have nothing to point `detect-pdf` at. Use `curl`; keep the file.

If `curl` fails or the result isn't a valid PDF (detect-pdf exits 1), the URL may point to an HTML landing page rather than the PDF itself — resolve the real PDF URL and retry.

## The decision flow — always start here

Run `detect-pdf` first. It is cheap (10–50 ms) and tells you what kind of document you're holding. Never blindly run `pdf2md` on an unknown PDF — a scanned document will exit with code 2 and you'll have wasted the call.

```
1. detect-pdf <file> --json        → read pdf_type from the JSON
2. branch on pdf_type:
   text_based   → pdf2md <file> --raw              (full clean Markdown to stdout)
   mixed        → pdf2md <file> --raw              (partial text) + report pages_needing_ocr
   scanned      → DO NOT extract. Report pages_needing_ocr to the user, stop.
   image_based  → same as scanned
```

The `pdf_type` field is the single source of truth. `ocr_recommended: true` means stop extracting and surface `pages_needing_ocr` instead — those pages have no text layer and pdf-inspector cannot help with them.

## Commands

`detect-pdf` — classification and routing. Always `--json` for parsing.

```bash
detect-pdf <file> --json               # type, confidence, pages_needing_ocr, ocr_reasons_by_page
detect-pdf <file> --analyze --json     # adds is_complex, pages_with_tables, pages_with_columns
```

Real output shape (15-page arxiv paper, measured):
```json
{"pdf_type":"text_based","page_count":15,"pages_sampled":8,"pages_with_text":8,"confidence":1.00,"ocr_recommended":false,"pages_needing_ocr":[],"detection_time_ms":35}
```
Scanned document:
```json
{"pdf_type":"scanned","page_count":1,"confidence":0.90,"ocr_recommended":true,"pages_needing_ocr":[1],"ocr_reasons_by_page":[{"page":1,"reasons":["no_text"]}]}
```
`ocr_reasons_by_page` gives machine-readable reason codes (`no_text`, etc.) — surface these to the user so they know why OCR is needed.

`pdf2md` — extraction to Markdown.

```bash
pdf2md <file> --raw                   # pure Markdown to stdout, no header — DEFAULT for feeding the model
pdf2md <file> --raw --select-pages 1,3,5-10   # only specific pages (commas + ranges, 1-indexed)
pdf2md <file> --raw --pages          # insert <!-- Page N --> markers between pages
pdf2md <file> --json                 # structured: markdown + markdown_length + layout metadata
pdf2md <file> out.md                 # write to a file instead of stdout
```

`--raw` is the right default for agent consumption: it prints only the Markdown to stdout with no banner, which keeps token usage minimal and avoids escaping noise. Use `--json` only when you need the metadata fields (layout, encoding issues, page counts) alongside the text.

## Exit codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Read stdout |
| 2 | PDF requires OCR (scanned / image-based) | Do not retry extraction; report `pages_needing_ocr` |
| 1 | Error (corrupt, encrypted without password, etc.) | Read stderr; offer `--password` if encrypted |

## Large documents — protect your context window

`detect-pdf --json` tells you `page_count` up front. A 200-page spec dumped via `pdf2md --raw` can be 80 KB+ of Markdown — flooding your own context, crowding out the actual task, and likely triggering a compaction that loses detail. Two ways to keep that out of your context:

**Prefer a subagent.** When the user asks a specific question about a large PDF ("does this contract have a termination clause?", "summarize the methodology"), spawn a subagent (e.g. the `Task` tool with a `general` agent) to run the extraction in *its* context and return only the answer. Tell the subagent the file path and the question; let it call `pdf2md` / `detect-pdf` itself. The subagent's context absorbs the full document; yours receives a few sentences. This is the right move whenever the document is long and the user's need is narrow — isolate the bulk, pass back the distillate.

**Fall back to `--select-pages`** when you can't spawn a subagent, or the user wants specific pages. `detect-pdf --analyze --json` flags `pages_with_tables` and `pages_with_columns` so you can target the pages that matter instead of pulling all of them:

```bash
pdf2md <file> --raw --select-pages 5,8-10     # only the pages that bear on the question
```

The principle behind both: a PDF is a haystack, the user's question is the needle — don't load the haystack into your working memory when you can have a subagent search it, or scope the extraction to where the needle is.

## Constraints — important

- **Default to stdout.** `pdf2md <file> --raw` prints to stdout. Only write a file when the user gives you a path — never invent output locations.
- **This skill does not perform OCR.** When `pdf_type` is `scanned` or `image_based`, report `pages_needing_ocr` and stop. Tell the user an OCR tool (MinerU, Marker, Tesseract) is needed for those pages. Do not claim to have extracted text you don't have.
- **No environment side effects.** pdf-inspector writes no cache, downloads no model, and makes no network calls. The only disk write happens when you explicitly pass an output filename. Respect that — don't wrap it in scripts that scatter temp files.
- **Encrypted PDFs** need `--password <pw>`. If `detect-pdf` or `pdf2md` exits 1 with an encryption error, ask the user for the password rather than guessing.

## When NOT to use this skill

- The PDF is scanned or image-only and the user wants the actual text → they need an OCR tool, not this skill. Detect, report, stop.
- The user wants to edit, sign, merge, or split a PDF → pdf-inspector is read-only; use a different tool.
- The user wants layout-perfect reproduction (exact fonts, images) → pdf-inspector gives clean Markdown, not a pixel-faithful render.
