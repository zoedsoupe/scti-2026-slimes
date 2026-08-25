#!/bin/sh
# Builds priv/student-kit.zip: the JS student kit plus PROTOCOL.md and
# WORKSHOP.md, laid out under a single student-kit/ directory. The server
# serves the zip at GET /kit.zip and the instructor copies it to the USB drives.
set -eu

cd "$(dirname "$0")/.."
root=$(pwd)
out=priv/student-kit.zip

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

mkdir "$stage/student-kit"
cp -R client-js/kit/. "$stage/student-kit/"
cp docs/PROTOCOL.md docs/WORKSHOP.md "$stage/student-kit/"

rm -f "$out"
(cd "$stage" && zip -qr "$root/$out" student-kit -x '*/.DS_Store')
ls -lh "$out"
