#!/bin/sh

set -e

exec /heka/bin/hekad --config "/heka/etc/${HEKA_CONF}"
