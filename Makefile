.PHONY: sync precommit lint format typecheck spell test ci hooks

sync:
	uv sync

hooks:
	uv run pre-commit install

precommit:
	uv run pre-commit run --all-files

lint:
	uv run ruff check apps extensions conftest.py

format:
	uv run ruff format apps extensions conftest.py

typecheck:
	uv run mypy

spell:
	uv run codespell apps extensions docs config README.md LICENSE *.md

test:
	uv run pytest

# Match CI check job (no semgrep locally).
ci: lint
	uv run ruff format --check apps extensions conftest.py
	$(MAKE) typecheck
	$(MAKE) spell
	$(MAKE) test
