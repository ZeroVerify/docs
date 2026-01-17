# Makefile for compiling Typst documents

# Output directory
OUTPUT_DIR := output

# Typst compiler
TYPST := typst

# Auto-discover all document directories (those containing main.typ)
DOC_SOURCES := $(wildcard */main.typ)
DOC_DIRS := $(patsubst %/main.typ,%,$(DOC_SOURCES))
DOC_PDFS := $(patsubst %/main.typ,$(OUTPUT_DIR)/%.pdf,$(DOC_SOURCES))

# Default target: build all documents
.PHONY: all
all: $(DOC_PDFS)

# Create output directory
$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

# Pattern rule: compile any document from its main.typ
$(OUTPUT_DIR)/%.pdf: %/main.typ | $(OUTPUT_DIR)
	$(TYPST) compile $< $@

# Dynamic targets for individual documents
.PHONY: $(DOC_DIRS)
$(DOC_DIRS): %: $(OUTPUT_DIR)/%.pdf

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
	@echo "  all      - Compile all documents (default)"
	@echo "  list     - List all discovered documents"
	@echo "  clean    - Remove output directory"
	@echo "  help     - Display this help message"
	@echo ""
	@echo "Document-specific targets (auto-generated):"
	@$(foreach doc,$(DOC_DIRS),echo "  $(doc)";)
	@echo ""
	@echo "Watch targets (auto-recompile on changes):"
	@$(foreach doc,$(DOC_DIRS),echo "  watch-$(doc)";)
	@echo ""
	@echo "Output directory: $(OUTPUT_DIR)/"
	@echo ""
	@echo "To add a new document: create a directory with main.typ inside"
