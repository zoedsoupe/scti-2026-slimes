#!/bin/sh
# Builds priv/student-kit.zip: the JS student kit (student-kit/) plus the
# unofficial Elixir kit (student-kit-ex/), each with PROTOCOL.md and
# WORKSHOP.md alongside. The server serves the zip at GET /kit.zip and the
# instructor copies it to the USB drives.
set -eu

cd "$(dirname "$0")/.."
root=$(pwd)
out=priv/student-kit.zip

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

mkdir "$stage/student-kit" "$stage/student-kit-ex"
cp -R client-js/kit/. "$stage/student-kit/"
cp -R client-ex/kit/. "$stage/student-kit-ex/"
cp docs/PROTOCOL.md docs/WORKSHOP.md "$stage/student-kit/"
cp docs/PROTOCOL.md docs/WORKSHOP.md "$stage/student-kit-ex/"

rm -f "$out"
(cd "$stage" && zip -qr "$root/$out" student-kit student-kit-ex -x '*/.DS_Store')
ls -lh "$out"
