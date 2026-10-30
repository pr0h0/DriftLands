#!/usr/bin/env bash
# Exports the web build and packs it for itch.io: build/driftlands-web.zip (index.html at the root).
# On itch: Kind of project = HTML, upload the zip, tick "This file will be played in the browser",
# Viewport 1280x720 with "Mobile friendly" (landscape) and the fullscreen button enabled.
# Leave "SharedArrayBuffer support" off (the build is single-threaded).
set -e
cd "$(dirname "$0")/.."
tools/web.sh > /dev/null
rm -f build/driftlands-web.zip
(cd build/web && zip -qr ../driftlands-web.zip . -x '*.import')
ls -lh build/driftlands-web.zip
