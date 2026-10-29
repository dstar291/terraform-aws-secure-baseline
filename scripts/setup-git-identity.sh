#!/usr/bin/env bash
# Sets the git author for THIS repository only, using values from .env.
# This stops the global (e.g. employer) identity from being stamped on commits.
# Usage: bash scripts/setup-git-identity.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Missing .env. Run: cp .env.example .env  and fill it in." >&2
  exit 1
fi

# Read only the two identity values; the token is never loaded or printed here.
name=$(grep -E '^GIT_USER_NAME=' .env | head -1 | cut -d= -f2-)
email=$(grep -E '^GIT_USER_EMAIL=' .env | head -1 | cut -d= -f2-)

if [ -z "$name" ] || [ -z "$email" ]; then
  echo "Set GIT_USER_NAME and GIT_USER_EMAIL in .env first." >&2
  exit 1
fi

git config --local user.name "$name"
git config --local user.email "$email"
echo "Local git identity set: $name <$email>"
