set -e

# Determine the platform's path list separator.
# On Windows (detected via DIRSEP from the test harness, or CPSEP env),
# use ';' instead of ':' since ':' is used in drive letters like C:.
if [ "$DIRSEP" = "\\" ] || [ "$CPSEP" = ";" ]; then
    SEP=";"
else
    SEP=":"
fi

# All of the following are equivalent, and they should all succeed.
# Note: for the env var form we use export+unset rather than inline
# assignment because inline `VAR=val $SAW` doesn't work when $SAW
# contains eval (the semicolons in Windows paths get misinterpreted).
export SAW_IMPORT_PATH="b_dir${SEP}c_dir1/c_dir2"
$SAW test.saw
unset SAW_IMPORT_PATH

# On Windows, $SAW uses eval which misinterprets semicolons in arguments
# as command separators. Use separate --import-path flags on Windows.
if [ "$SEP" = ";" ]; then
    $SAW --import-path b_dir --import-path c_dir1/c_dir2 test.saw
    $SAW -i b_dir -i c_dir1/c_dir2 test.saw
else
    $SAW --import-path "b_dir${SEP}c_dir1/c_dir2" test.saw
    $SAW -i "b_dir${SEP}c_dir1/c_dir2" test.saw
fi
$SAW --import-path b_dir --import-path c_dir1/c_dir2 test.saw
$SAW -i b_dir -i c_dir1/c_dir2 test.saw
