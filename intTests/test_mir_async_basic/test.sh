set -e

# The MIR JSON would be produced by saw-rustc test.rs
# For now, only verify the synchronous helper
$SAW test.saw
