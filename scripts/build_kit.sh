#!/bin/sh
# Builds one zip per language kit into priv/: student-kit.zip (JS),
# student-kit-elixir.zip, student-kit-golang.zip, student-kit-c.zip and
# student-kit-python.zip, each with PROTOCOL.md and WORKSHOP.md alongside.
# The router serves them at GET /kit and GET /kit/<lang>.
set -eu

cd "$(dirname "$0")/.."
root=$(pwd)

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

# lang:source-dir (lang "js" is the default kit, served at /kit)
kits="js:client-js/kit elixir:client-ex/kit golang:client-go/kit c:client-c/kit python:client-py/kit"

for pair in $kits; do
  lang=${pair%%:*}
  src=${pair#*:}

  if [ "$lang" = js ]; then
    dir=student-kit
    out=priv/student-kit.zip
  else
    dir=student-kit-$lang
    out=priv/student-kit-$lang.zip
  fi

  mkdir "$stage/$dir"
  cp -R "$src/." "$stage/$dir/"
  cp docs/PROTOCOL.md docs/CHEATSHEET.md "$stage/$dir/"

  rm -f "$out"
  (cd "$stage" && zip -qr "$root/$out" "$dir" \
    -x '*/.DS_Store' '*/_build/*' '*/deps/*' '*/.expert/*' '*/__pycache__/*' '*/node_modules/*' \
       '*/slimes' '*/test_decide' '*/test_protocol')
  rm -rf "$stage/$dir"
  ls -lh "$out"
done
