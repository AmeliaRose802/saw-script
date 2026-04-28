// Comprehensive async Rust test source
// Compile with: saw-rustc test.rs

pub fn add_one(x: u32) -> u32 {
    x.wrapping_add(1)
}

pub async fn async_immediate(x: u32) -> u32 {
    add_one(x)
}

pub async fn async_with_await(x: u32) -> u32 {
    let a = async_immediate(x).await;
    let b = async_immediate(a).await;
    b
}

pub async fn async_conditional(x: u32) -> u32 {
    if x > 10 {
        async_immediate(x).await
    } else {
        x
    }
}
