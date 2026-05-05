#!/bin/bash

output=$( $SAW --detect-vacuity test.saw 2>&1 )
n=$( echo "$output" | grep -c "Contradiction detected" )
echo "$output" >&2

if [ "$n" -eq 2 ]; then
  echo "Found 2 expected contradictions"
  exit 0
else
  echo "Expected 2 contradictions, found $n"
  exit 1
fi
