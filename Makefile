# Makefile for compiling Typst documents

# Output directory
OUTPUT_DIR := output

# Typst compiler
TYPST := typst

# Auto-discover all document directories (those containing main.typ)
DOC_SOURCES := $(wildcard */main.typ)
DOC_DIRS := $(patsubst %/main.typ,%,$(DOC_SOURCES))
DOC_PDFS := $(patsubst %/main.typ,$(OUTPUT_DIR)/%.pdf,$(DOC_SOURCES))
DOC_HTMLS := $(patsubst %/main.typ,$(OUTPUT_DIR)/%.html,$(DOC_SOURCES))
DOC_MDS := $(patsubst %/main.typ,$(OUTPUT_DIR)/%.md,$(DOC_SOURCES))

# Default target: build all documents
.PHONY: all
all: $(DOC_PDFS)

.PHONY: html
html: $(DOC_HTMLS)

.PHONY: markdown
markdown: $(DOC_MDS)

# Create output directory
$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

# Pattern rule: compile any document from its main.typ
$(OUTPUT_DIR)/%.pdf: %/main.typ | $(OUTPUT_DIR)
	$(TYPST) compile $< $@

$(OUTPUT_DIR)/%.html: %/main.typ | $(OUTPUT_DIR)
	$(TYPST) compile --features html --format html $< $@

$(OUTPUT_DIR)/%.md: %/main.typ | $(OUTPUT_DIR)
	pandoc -f typst -t markdown $< -o $@

.PHONY: $(DOC_DIRS)
$(DOC_DIRS): %: $(OUTPUT_DIR)/%.pdf

.PHONY: $(addprefix html-,$(DOC_DIRS))
$(addprefix html-,$(DOC_DIRS)): html-%: $(OUTPUT_DIR)/%.html

# Dynamic watch targets
.PHONY: $(addprefix watch-,$(DOC_DIRS))
$(addprefix watch-,$(DOC_DIRS)): watch-%: | $(OUTPUT_DIR)
	$(TYPST) watch $*/main.typ $(OUTPUT_DIR)/$*.pdf

# Clean output directory
.PHONY: clean
clean:
	rm -rf $(OUTPUT_DIR)

# List all discovered documents
.PHONY: list
list:
	@echo "Discovered documents:"
	@$(foreach doc,$(DOC_DIRS),echo "  - $(doc)";)

# Display help
.PHONY: help
help:
	@echo "Typst Document Compilation Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make [target]"
	@echo ""
	@echo "General targets:"
	@echo "  all      - Compile all documents to PDF (default)"
	@echo "  html     - Compile all documents to HTML"
	@echo "  list     - List all discovered documents"
	@echo "  clean    - Remove output directory"
	@echo "  help     - Display this help message"
	@echo ""
	@echo "Document-specific PDF targets (auto-generated):"
	@$(foreach doc,$(DOC_DIRS),echo "  $(doc)";)
	@echo ""
	@echo "Document-specific HTML targets (auto-generated):"
	@$(foreach doc,$(DOC_DIRS),echo "  html-$(doc)";)
	@echo ""
	@echo "Watch targets (auto-recompile on changes):"
	@$(foreach doc,$(DOC_DIRS),echo "  watch-$(doc)";)
	@echo ""
	@echo "Output directory: $(OUTPUT_DIR)/"
	@echo ""
	@echo "To add a new document: create a directory with main.typ inside"
