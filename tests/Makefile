# Local equivalents of the CI jobs.
#
# Run from anywhere, e.g.
#   make -C tests            # everything
#   make -C tests unit       # just the helm unit tests
#   make -C tests help       # list targets
#
# CI (.github/workflows/lint.yml) runs the same checks against a Helm 3.22 /
# 4.3 matrix. The yamllint rules and the all-features values file are shared with
# CI rather than duplicated here, so the two cannot drift apart.
#
# See tests/README.md for details.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# Repo root, so targets work regardless of the caller's working directory.
TESTS_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT     := $(abspath $(TESTS_DIR)/..)
TOOLS    := $(ROOT)/bin

CHART          := $(ROOT)/helm/jupyter-template
ALL_FEATURES   := $(TESTS_DIR)/values-all-features.yaml
YAMLLINT_CONF  := $(ROOT)/.yamllint

# Pinned to the versions CI uses. hadolint floats in CI (hadolint-action does
# not pin it) and yamllint floats via pip, so these are a known-good floor.
HELM3_VERSION       := v3.22.0
HELM4_VERSION       := v4.3.0
HADOLINT_VERSION    := v2.14.0
ACTIONLINT_VERSION  := v1.7.12
UNITTEST_REPO       := https://github.com/helm-unittest/helm-unittest.git

# Prefer a binary fetched by `make tools`, else fall back to PATH.
HELM3      := $(firstword $(wildcard $(TOOLS)/helm-$(HELM3_VERSION)) helm)
HELM4      := $(firstword $(wildcard $(TOOLS)/helm-$(HELM4_VERSION)) helm)
HADOLINT   := $(firstword $(wildcard $(TOOLS)/hadolint) hadolint)
ACTIONLINT := $(firstword $(wildcard $(TOOLS)/actionlint) actionlint)
# yamllint is a Python package; prefer a venv created by `make tools`.
YAMLLINT   := $(firstword $(wildcard $(TOOLS)/yamllint/bin/yamllint) yamllint)

# The Helm binary the chart targets use. Defaults to the 3.x resolution so the
# standalone targets match CI's primary version; `make helm4` overrides it.
HELM ?= $(HELM3)

# helm and actionlint name their assets with Go's GOARCH, hadolint does not.
GOARCH := $(shell uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
ARCH   := $(shell uname -m | sed 's/x86_64/x86_64/; s/aarch64/arm64/')

# Values overrides that switch on every optional feature, mirroring the CI step.
HELM_TEMPLATE_FLAGS := --namespace ci

.PHONY: help all check lint unit test chart-lint render render-all \
        lint-docker lint-yaml lint-workflows lint-ci \
        helm3 helm4 unit3 unit4 doctor plugin tools clean

## help: List the available targets
help:
	@echo "jupyter-template — local CI jobs"
	@echo
	@echo "Usage: make -C tests <target>"
	@echo
	@echo "Full runs"
	@echo "  make check          everything below, in order"
	@echo "  make lint           linters only (hadolint, yamllint, actionlint, helm lint)"
	@echo "  make lint-ci        hadolint + yamllint + actionlint (the CI jobs that are"
	@echo "                      not Helm-version specific)"
	@echo
	@echo "Tests"
	@echo "  make unit           helm unittest against the default helm (148 assertions)"
	@echo "  make chart-lint     helm lint --strict"
	@echo "  make render         helm template with default values"
	@echo "  make render-all     helm template with every optional feature enabled"
	@echo "  make helm3          chart-lint + render + render-all + unit on Helm $(HELM3_VERSION)"
	@echo "  make helm4          the same on Helm $(HELM4_VERSION)"
	@echo
	@echo "Single linters"
	@echo "  make lint-docker    hadolint on Dockerfile"
	@echo "  make lint-yaml      yamllint using the repo-root .yamllint"
	@echo "  make lint-workflows actionlint on .github/workflows"
	@echo
	@echo "Environment"
	@echo "  make doctor         show which binaries each target will use"
	@echo "  make plugin         install the helm-unittest plugin for the current helm"
	@echo "  make tools          download pinned helm/hadolint/actionlint into $(TOOLS)"
	@echo "  make clean          remove downloaded tools and generated reports"
	@echo
	@echo "Extra options (append to any target, e.g. 'make unit SUITE=ingress'):"
	@echo "  SUITE=<glob>        limit unit tests. The glob is chart-relative, so keep"
	@echo "                      the tests/ prefix: SUITE='tests/*ingress*'"
	@echo "  JUNIT=<file>        also write a JUnit report (make unit JUNIT=report.xml)"
	@echo "  COLOR=always|never  force or suppress coloured output"

## check: Run every check, in the same order CI does
check: lint-ci chart-lint render render-all unit
	@echo
	@echo "all checks passed"

## lint: All linters, including the chart
lint: lint-ci chart-lint

## unit: Run the helm unittest suites
unit:
	@$(MAKE) --no-print-directory _unit HELM="$(HELM)"

## chart-lint: helm lint --strict
chart-lint:
	@echo "==> helm lint --strict ($(HELM))"
	@$(HELM) lint "$(CHART)" --strict

## render: helm template with default values
render:
	@echo "==> helm template, default values ($(HELM))"
	@$(HELM) template ci "$(CHART)" $(HELM_TEMPLATE_FLAGS) > /dev/null
	@echo "    ok"

## render-all: helm template with every optional feature enabled
render-all:
	@echo "==> helm template, all features ($(HELM))"
	@$(HELM) template ci "$(CHART)" $(HELM_TEMPLATE_FLAGS) -f "$(ALL_FEATURES)" > /dev/null
	@echo "    ok"

## lint-docker: hadolint on the Dockerfile
lint-docker:
	@$(MAKE) --no-print-directory _require TOOL="$(HADOLINT)" HINT="make tools"
	@echo "==> hadolint Dockerfile"
	@$(HADOLINT) "$(ROOT)/Dockerfile"

## lint-yaml: yamllint with the config shared with CI
lint-yaml:
	@$(MAKE) --no-print-directory _require TOOL="$(YAMLLINT)" HINT="make tools"
	@echo "==> yamllint -c .yamllint --strict"
	@cd "$(ROOT)" && $(YAMLLINT) -c "$(YAMLLINT_CONF)" --strict .

## lint-workflows: actionlint on the GitHub Actions workflows
lint-workflows:
	@$(MAKE) --no-print-directory _require TOOL="$(ACTIONLINT)" HINT="make tools"
	@echo "==> actionlint .github/workflows"
	@cd "$(ROOT)" && $(ACTIONLINT)

## lint-ci: The linters that CI runs outside the Helm matrix
lint-ci: lint-docker lint-yaml lint-workflows

## helm3: Run every Helm check on Helm $(HELM3_VERSION)
helm3:
	@$(MAKE) --no-print-directory _helm-version HELM="$(HELM3)" WANT="$(HELM3_VERSION)"
	@$(MAKE) --no-print-directory _helm-suite HELM="$(HELM3)"

## helm4: Run every Helm check on Helm $(HELM4_VERSION)
helm4:
	@$(MAKE) --no-print-directory _helm-version HELM="$(HELM4)" WANT="$(HELM4_VERSION)"
	@$(MAKE) --no-print-directory _helm-suite HELM="$(HELM4)"

## test: Alias for check
test: check

## doctor: Show which binaries each target resolves to
doctor:
	@printf '%-12s %-34s ' "helm (3.x)" "$(HELM3)"
	@$(HELM3) version --short 2>/dev/null || echo "not found"
	@printf '%-12s %-34s ' "helm (4.x)" "$(HELM4)"
	@$(HELM4) version --short 2>/dev/null || echo "not found"
	@printf '%-12s %-34s ' "hadolint" "$(HADOLINT)"
	@$(HADOLINT) --version 2>/dev/null || echo "not found"
	@printf '%-12s %-34s ' "yamllint" "$(YAMLLINT)"
	@$(YAMLLINT) --version 2>/dev/null || echo "not found"
	@printf '%-12s %-34s ' "actionlint" "$(ACTIONLINT)"
	@$(ACTIONLINT) --version 2>/dev/null || echo "not found"
	@echo
	@$(MAKE) --no-print-directory _plugin-status HELM="$(HELM3)"

## plugin: Install the helm-unittest plugin for the current helm
plugin:
	@$(MAKE) --no-print-directory _plugin HELM="$(HELM3)"

## tools: Download pinned helm, hadolint, actionlint and yamllint into $(TOOLS)
tools:
	@mkdir -p "$(TOOLS)"
	@$(MAKE) --no-print-directory _fetch-helm VERSION="$(HELM3_VERSION)"
	@$(MAKE) --no-print-directory _fetch-helm VERSION="$(HELM4_VERSION)"
	@$(MAKE) --no-print-directory _fetch-binary REPO=hadolint/hadolint \
		VERSION="$(HADOLINT_VERSION)" FILE="hadolint-linux-$(ARCH)" BIN=hadolint
	@$(MAKE) --no-print-directory _fetch-tarball REPO=rhysd/actionlint \
		VERSION="$(ACTIONLINT_VERSION)" FILE="actionlint_$(subst v,,$(ACTIONLINT_VERSION))_linux_$(GOARCH).tar.gz" \
		BIN=actionlint
	@$(MAKE) --no-print-directory _fetch-yamllint
	@echo
	@$(MAKE) --no-print-directory doctor

## clean: Remove downloaded tools and generated reports
clean:
	@rm -rf "$(TOOLS)"
	@rm -f "$(TESTS_DIR)"/*.xml
	@echo "removed $(TOOLS) and any JUnit reports"

# --- internals ---------------------------------------------------------------

.PHONY: _unit _helm-suite _helm-version _require _plugin _plugin-status \
        _fetch-helm _fetch-binary _fetch-tarball _fetch-yamllint

_unit:
	@$(MAKE) --no-print-directory _plugin HELM="$(HELM)"
	@echo "==> helm unittest [$(HELM)]"
	@$(HELM) unittest "$(CHART)" --strict \
		$(if $(SUITE),-f '$(SUITE)') \
		$(if $(JUNIT),-o '$(JUNIT)') \
		$(if $(COLOR),--color=$(COLOR))

_helm-suite:
	@$(MAKE) --no-print-directory chart-lint HELM="$(HELM)"
	@$(MAKE) --no-print-directory render HELM="$(HELM)"
	@$(MAKE) --no-print-directory render-all HELM="$(HELM)"
	@$(MAKE) --no-print-directory _unit HELM="$(HELM)"

_helm-version:
	@$(HELM) version --short 2>/dev/null | grep -qF "$(WANT)" \
		|| { echo "error: expected Helm $(WANT) but '$(HELM)' reports:" >&2; \
		     $(HELM) version --short >&2 || true; \
		     echo "hint: run 'make -C tests tools' to fetch the pinned versions" >&2; \
		     exit 1; }

_require:
	@command -v "$(TOOL)" >/dev/null 2>&1 || { \
		echo "error: '$(TOOL)' not found." >&2; \
		echo "hint: $(HINT), or install it and make sure it is on PATH" >&2; \
		exit 127; }

_plugin:
	@if $(HELM) plugin list 2>/dev/null | grep -q '^unittest'; then \
		echo "helm-unittest already installed for $(HELM)"; \
	else \
		echo "==> installing helm-unittest for $(HELM)"; \
		$(HELM) plugin install $(UNITTEST_REPO) \
			$$( $(HELM) version --short | grep -q '^v4' && echo --verify=false ); \
	fi

_plugin-status:
	@if $(HELM) plugin list 2>/dev/null | grep -q '^unittest'; then \
		echo "helm-unittest  installed for $(HELM)"; \
	else \
		echo "helm-unittest  MISSING for $(HELM) - run 'make -C tests plugin'"; \
	fi

_fetch-helm:
	@if [ -x "$(TOOLS)/helm-$(VERSION)" ]; then \
		echo "helm $(VERSION) already present"; \
	else \
		echo "==> fetching helm $(VERSION)"; \
		tmp="$$(mktemp -d)"; \
		curl -sSfL -o "$$tmp/helm.tgz" \
			"https://get.helm.sh/helm-$(VERSION)-linux-$(GOARCH).tar.gz"; \
		tar -xzf "$$tmp/helm.tgz" -C "$$tmp"; \
		mv "$$tmp/linux-$(GOARCH)/helm" "$(TOOLS)/helm-$(VERSION)"; \
		rm -rf "$$tmp"; \
		chmod +x "$(TOOLS)/helm-$(VERSION)"; \
	fi

# For projects that publish the executable as a bare asset.
_fetch-binary:
	@if [ -x "$(TOOLS)/$(BIN)" ]; then \
		echo "$(BIN) $(VERSION) already present"; \
	else \
		echo "==> fetching $(BIN) $(VERSION)"; \
		curl -sSfL -o "$(TOOLS)/$(BIN)" \
			"https://github.com/$(REPO)/releases/download/$(VERSION)/$(FILE)"; \
		chmod +x "$(TOOLS)/$(BIN)"; \
	fi

# For projects that publish a .tar.gz wrapping a single executable.
_fetch-tarball:
	@if [ -x "$(TOOLS)/$(BIN)" ]; then \
		echo "$(BIN) $(VERSION) already present"; \
	else \
		echo "==> fetching $(BIN) $(VERSION)"; \
		tmp="$$(mktemp -d)"; \
		curl -sSfL -o "$$tmp/tool.tgz" \
			"https://github.com/$(REPO)/releases/download/$(VERSION)/$(FILE)"; \
		tar -xzf "$$tmp/tool.tgz" -C "$$tmp" $(BIN); \
		mv "$$tmp/$(BIN)" "$(TOOLS)/$(BIN)"; \
		rm -rf "$$tmp"; \
		chmod +x "$(TOOLS)/$(BIN)"; \
	fi

_fetch-yamllint:
	@if [ -x "$(TOOLS)/yamllint/bin/yamllint" ]; then \
		echo "yamllint venv already present"; \
	else \
		echo "==> creating yamllint venv"; \
		python3 -m venv "$(TOOLS)/yamllint"; \
		"$(TOOLS)/yamllint/bin/pip" install --quiet --upgrade pip; \
		"$(TOOLS)/yamllint/bin/pip" install --quiet yamllint; \
	fi