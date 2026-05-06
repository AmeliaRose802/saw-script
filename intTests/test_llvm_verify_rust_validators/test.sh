#!/bin/sh
set -e
CRYPTOLPATH=$(cd "$(dirname "$0")" && pwd)
export CRYPTOLPATH
$SAW test.saw
