SHELL := /bin/bash

.PHONY: help setup-signing test build build-debug build-release package run run-debug run-release clean

help:
	@printf "%s\n" \
		"Targets:" \
		"  make setup-signing Create/use opt-in local self-signed identity" \
		"  make test          Run unit tests" \
		"  make build         Build Release app into build/Release" \
		"  make build-debug   Build Debug app into build/Debug" \
		"  make build-release Build Release app into build/Release" \
		"  make package       Build Release app and create dist DMG/ZIP" \
		"  make run           Build if needed, then open Debug app" \
		"  make run-debug     Build if needed, then open Debug app" \
		"  make run-release   Build if needed, then open Release app" \
		"  make clean         Remove build outputs"

setup-signing:
	@./scripts/setup-local-signing.sh

test:
	@./scripts/test.sh

build: build-release

build-debug:
	@./scripts/build-debug.sh

build-release:
	@./scripts/build-release.sh

package:
	@./scripts/package-release.sh

run: run-debug

run-debug:
	@./scripts/run-debug.sh

run-release:
	@./scripts/run-release.sh

clean:
	@./scripts/clean.sh
