# Copyright (c) 2026 RedStone. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Build, validate and test the CAPS packages. CI runs `make ci`; the same
# targets are meant to be run locally. The packages pin Daml SDK 3.5.12 and
# build with dpm, the Daml Package Manager (`dpm install 3.5.12`).

# The DARs the repository ships in dars/, and the packages lint runs over.
DAR_GLOB := interfaces/*/.daml/dist/*.dar caps-core/.daml/dist/*.dar extensions/*/.daml/dist/*.dar caps-capsule-archiver/.daml/dist/*.dar caps-round-archiver/.daml/dist/*.dar
DAML_PKGS := $(shell find interfaces caps-core extensions caps-capsule-archiver caps-round-archiver tests-fixtures tests -name daml.yaml -not -path '*/.daml/*' -exec dirname {} \;)

# Where `make test` keeps the transactions of each test for `make visibility`.
TX_LISTINGS := tests/.daml/transactions
TEST_MODULES := $(basename $(notdir $(wildcard tests/daml/Test/*Test.daml)))

.PHONY: build test visibility validate lint headers-check clean ci dars dars-check

build:
	@if [ -f multi-package.yaml ]; then dpm build --all; else echo "build: no packages yet"; fi

# Run the Daml Script test suite in-memory, a module at a time, so tests of
# the same name in two modules keep their own transaction listings.
test:
	@if [ -d tests ]; then rm -rf $(TX_LISTINGS) && cd tests && for m in $(TEST_MODULES); do dpm test --files daml/Test/$$m.daml --transactions-output ../$(TX_LISTINGS)/$$m || exit 1; done; else echo "test: no tests/ package yet"; fi

# Check who each test transaction is disclosed to, witnesses included, against
# the privacy rules in tests/daml/Test/Visibility.daml.
visibility: test
	@./scripts/visibility-json.sh $(TX_LISTINGS) > $(TX_LISTINGS)/nodes.json
	@dpm script --dar tests/.daml/dist/caps-tests-0.1.0.dar --script-name Test.Visibility:check --ide-ledger --input-file $(TX_LISTINGS)/nodes.json

validate:
	@for dar in $(DAR_GLOB); do dpm damlc validate-dar "$$dar"; done

# Lint each package from its own directory, so cross-package imports resolve
# through that package's built database.
lint:
	@set -e; for pkg in $(DAML_PKGS); do \
	  echo "lint $$pkg"; \
	  ( cd "$$pkg" && dpm damlc lint $$(find daml -name '*.daml') ); \
	done

headers-check:
	@./scripts/check-headers.sh

# Refresh the committed DARs from a clean build. dars/ is the distribution
# channel: consumers take the DARs straight from the repository. The build
# is cleaned first: dpm's incremental build can judge a package unchanged
# after an edit that does change its package id, and a stale DAR would then
# be committed and fail dars-check in CI.
dars: clean build
	@mkdir -p dars
	@cp $(DAR_GLOB) dars/
	@ls -1 dars/*.dar

# Prove the committed DARs are in sync with the source: rebuild and compare
# package ids (the package id is the content hash, so any drift flips it).
dars-check:
	@set -e; \
	found=0; \
	for dar in $(DAR_GLOB); do \
	  found=1; \
	  name=$$(basename "$$dar"); \
	  if [ ! -f "dars/$$name" ]; then echo "dars-check: missing committed DAR dars/$$name"; exit 1; fi; \
	  built=$$(dpm damlc inspect-dar "$$dar" --json | jq -r .main_package_id); \
	  committed=$$(dpm damlc inspect-dar "dars/$$name" --json | jq -r .main_package_id); \
	  if [ "$$built" != "$$committed" ]; then \
	    echo "dars-check: $$name diverged (committed $$committed != built $$built)"; exit 1; \
	  fi; \
	  echo "dars-check: $$name OK ($$built)"; \
	done; \
	if [ "$$found" = "0" ]; then \
	  if [ -n "$(DAR_GLOB)" ]; then echo "dars-check: no built DAR found, run make build"; exit 1; \
	  else echo "dars-check: no DARs listed yet, nothing to check"; fi; \
	fi

clean:
	@if [ -f multi-package.yaml ]; then dpm clean --all; fi

ci: headers-check build validate test visibility dars-check
