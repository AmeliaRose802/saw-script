# Support async_trait Desugaring in MIR Verification

**Issue:** saw-script-dv0  
**Parent:** saw-script-3ea (EPIC: Close SAW MIR verification gaps)

## Background

The `#[async_trait]` macro (from the `async-trait` crate) desugars async
trait methods into methods that return `Pin<Box<dyn Future<Output = T>>>`.
This differs from native async fn in traits (stabilized in Rust 1.75).

### async_trait Desugaring

```rust
#[async_trait]
trait MyTrait {
    async fn process(&self, x: u32) -> u32;
}
```

Becomes roughly:

```rust
trait MyTrait {
    fn process<'a>(&'a self, x: u32) -> Pin<Box<dyn Future<Output = u32> + 'a>>;
}
```

### Native async fn in traits (Rust 1.75+)

```rust
trait MyTrait {
    async fn process(&self, x: u32) -> u32;
    // Desugars to: fn process(&self, x: u32) -> impl Future<Output = u32>;
}
```

## Verification Strategy

### For async_trait (Box<dyn Future>)

1. **Pin<Box<dyn Future>>** is triple-wrapped:
   - Pin: transparent (handled by 80n)
   - Box: heap allocation (existing support)
   - dyn Future: trait object (needs vtable)

2. The implementation creates a boxed coroutine:
   ```rust
   fn process<'a>(&'a self, x: u32) -> Pin<Box<dyn Future<Output = u32> + 'a>> {
       Box::pin(async move { self.inner_process(x) })
   }
   ```

3. For verification, we override the entire method, bypassing the
   boxing layer:
   ```sawscript
   let process_spec = do {
       self_ref <- mir_alloc (mir_adt my_struct_adt);
       x <- mir_fresh_var "x" mir_u32;
       mir_execute_func [self_ref, mir_term x];
       // Return value models the boxed future abstractly
       result <- mir_fresh_var "result" mir_u32;
       mir_return (mir_term result);
   };
   process_ov <- mir_unsafe_assume_spec m "MyStruct::process" process_spec;
   ```

### For native async fn in traits

1. The callee is a coroutine, handled by coroutine TypeShape support (d8k)
2. Pin erasure (80n) handles `Pin<&mut Self>` in poll signatures
3. Standard coroutine verification patterns apply

## Implementation Plan

1. Add `async_trait`-style override patterns to documentation
2. Create helper SAWScript for boxing abstraction
3. Test with a real `async_trait`-using crate
4. Consider automatic detection of `async_trait` desugaring patterns
