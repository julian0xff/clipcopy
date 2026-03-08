.PHONY: build test lint

build:
	sh -n clipcopy
	sh -n install.sh

test:
	sh tests/run.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck clipcopy install.sh tests/run.sh; \
	else \
		echo "shellcheck not found; skipping lint"; \
	fi
