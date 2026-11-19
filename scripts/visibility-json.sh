#!/usr/bin/env bash
# Copyright (c) 2026 RedStone. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Turn the transaction listings `make test` writes, one directory per test
# module, into the input of Test.Visibility:check: a JSON list with one
# object per node.
set -euo pipefail

listings="$1"
nodes_awk="$(dirname "$0")/visibility-nodes.awk"

if ! ls "$listings"/*/transaction-*.html > /dev/null 2>&1; then
  echo "visibility-json: no transaction listings in $listings" >&2
  exit 1
fi

# One listing as plain text: one line per <br>, tags dropped, entities decoded.
as_text() {
  awk -v RS='<br>' '{ print }' "$1" |
    sed -e 's/<[^>]*>//g' \
      -e "s/&#39;/'/g" \
      -e 's/&quot;/"/g' \
      -e 's/&lt;/</g' \
      -e 's/&gt;/>/g' \
      -e 's/&amp;/\&/g'
}

nodes() {
  for listing in "$listings"/*/transaction-*.html; do
    module="$(basename "$(dirname "$listing")")"
    test_name="$(basename "$listing" .html)"
    test_name="$module:${test_name#transaction-}"
    as_text "$listing" | awk -v test="$test_name" -f "$nodes_awk"
  done
}

echo "["
nodes | sed '$!s/$/,/'
echo "]"
