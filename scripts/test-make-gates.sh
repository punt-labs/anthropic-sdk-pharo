#!/usr/bin/env bash
# Regression test: `make test` and `make test-fast` must exit nonzero unless
# the image reports zero failures and zero errors. Runs without Pharo by
# replacing CURL with a stub that prints SUMMARY and exits RESULT_EXIT.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC2016 # expanded by the stub shell, not here
stub='sh -c '\''printf "%s\n" "$$SUMMARY"; exit "$$RESULT_EXIT"'\'' stub'

# name|summary|curl exit|expected make exit (0 = pass, 1 = fail)
cases=(
	"pass|'Tests: 2  Passed: 2  Failures: 0  Errors: 0'|0|0"
	"failure|'Tests: 2  Passed: 1  Failures: 1  Errors: 0'|0|1"
	"error|'Tests: 2  Passed: 1  Failures: 0  Errors: 1'|0|1"
	"empty||0|1"
	"malformed|HTTP error page|0|1"
	"connection||7|1"
)

failed=0
for target in test test-fast; do
	for entry in "${cases[@]}"; do
		IFS='|' read -r name summary code expected <<<"$entry"
		status=0
		SUMMARY="$summary" RESULT_EXIT="$code" \
			make -s -C "$root" "$target" CURL="$stub" >/dev/null 2>&1 || status=$?
		if { [ "$expected" -eq 0 ] && [ "$status" -ne 0 ]; } ||
			{ [ "$expected" -ne 0 ] && [ "$status" -eq 0 ]; }; then
			echo "FAIL $target $name: exit=$status"
			failed=1
		else
			echo "ok   $target $name: exit=$status"
		fi
	done
done
exit "$failed"
