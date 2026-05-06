#!/bin/sh
set -e
CRYPTOLPATH=$(dirname "$SAW")/../lib:$(cd "$(dirname "$0")" && pwd)
export CRYPTOLPATH
$SAW test.saw
