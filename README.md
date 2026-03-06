# ZeroVerify Documentation

Documentation source files written in [Typst](https://typst.app/).

## Prerequisites

- `typst` - for PDF/HTML compilation
- `pandoc` - for markdown conversion

## Usage

```bash
# Build all documents to PDF
make

# Build all documents to HTML
make html

# Build all documents to markdown
make markdown

# Build a specific document
make <doc-name>

# Watch for changes and auto-rebuild
make watch-<doc-name>

# Clean output
make clean

# List all documents
make list
```

## Adding Documents

Create a directory with a `main.typ` file inside. It will be auto-discovered by the Makefile.
