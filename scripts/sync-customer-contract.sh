#!/usr/bin/env bash
set -euo pipefail

frontend_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend_root="${BACKEND_REPO:-"$frontend_root/../enkepos"}"
source_file="$backend_root/contracts/openapi/customers.yaml"
target_file="$frontend_root/contracts/openapi/customers.yaml"

if [[ ! -f "$source_file" ]]; then
  echo "Customer contract not found: $source_file" >&2
  exit 1
fi

if [[ "${1:-}" == "--check" ]]; then
  if [[ ! -f "$target_file" ]] || ! cmp -s "$source_file" "$target_file"; then
    echo "Frontend Customer contract is out of date." >&2
    echo "Run: ./scripts/sync-customer-contract.sh" >&2
    exit 1
  fi
  echo "Frontend Customer contract is current."
  exit 0
fi

mkdir -p "$(dirname "$target_file")"
cp "$source_file" "$target_file"
echo "Synchronized Customer contract from $source_file"

