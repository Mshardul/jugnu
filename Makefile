# Local overrides: copy `.env.example` to `.env` (gitignored).
-include .env
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

.PHONY: sync hooks precommit lint lint-swift format format-swift spell test test-extended tools-swift stop run ci window-layouts helper-clock screenshots

sync:
	uv sync

hooks:
	uv run pre-commit install

tools-swift:
	./scripts/ensure-swift-tools.sh

lint-swift: tools-swift
	./scripts/run-swiftlint.sh

format-swift: tools-swift
	./scripts/run-swiftformat.sh

precommit:
	uv run pre-commit run --all-files

lint:
	uv run ruff check addons conftest.py

format:
	uv run ruff format addons conftest.py

spell:
	uv run codespell addons docs config README.md LICENSE Makefile

test:
	uv run pytest

test-extended:
	cd shell/TestsExtended && swift test

window-layouts:
	cd addons/window-layouts && swift build -c release
	mkdir -p addons/window-layouts/bin
	cp addons/window-layouts/.build/release/window-layouts addons/window-layouts/bin/helper

helper-clock:
	./scripts/package-helper-clock.sh dist

# Quit every Jugnu binary (menu-bar .app and `swift run`), not Cursor helpers.
stop:
	@printf 'Stopping old Jugnu processes...\n'
	@-killall -TERM Jugnu >/dev/null 2>&1
	@-pkill -TERM -f '/Jugnu.app/Contents/MacOS/Jugnu' >/dev/null 2>&1
	@n=0; \
	while pgrep -x Jugnu >/dev/null 2>&1; do \
		n=$$((n+1)); \
		if [ $$n -ge 20 ]; then \
			killall -KILL Jugnu >/dev/null 2>&1 || true; \
			break; \
		fi; \
		sleep 0.15; \
	done

# Drive the real app through every page (XCUITest) and dump PNGs to screenshots/.
screenshots:
	./scripts/screenshots.sh

run: stop
	cd shell && \
	xcodebuild -project Jugnu.xcodeproj -scheme Jugnu -configuration Debug \
	  -derivedDataPath DerivedData \
	  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build && \
	open -n DerivedData/Build/Products/Debug/Jugnu.app
	@echo ""
	@echo "Jugnu is a menu-bar app — it does not appear in the Dock or as a window."
	@echo "Look on the right of the menu bar for a firefly (or the word Jugnu), then Option+Space."

# Match CI check job (no semgrep locally).
ci: lint
	uv run ruff format --check addons conftest.py
	$(MAKE) spell
	$(MAKE) test
