#!/usr/bin/env bash
set -euxo pipefail

terraform output --json \
  | jq '[ . | to_entries[] | select( .value.value != "" and .value.value != [] and .value.value != {} ) ] | from_entries'
