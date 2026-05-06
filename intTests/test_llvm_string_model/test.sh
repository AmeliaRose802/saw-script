#!/bin/sh
set -e
TESTDIR=$(dirname "$0")
export CRYPTOLPATH="${TESTDIR}/../../lib"
$SAW test.saw
