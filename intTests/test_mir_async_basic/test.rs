// Minimal async Rust test source.
// Compile with: saw-rustc test.rs
// This produces test.linked-mir.json

/// A simple synchronous helper
pub fn add_one(x: u32) -> u32 {
    x.wrapping_add(1)
}

/// A minimal async function.  After desugaring, rustc produces a
/// coroutine state machine that calls add_one.
pub async fn async_add_one(x: u32) -> u32 {
    add_one(x)
}
