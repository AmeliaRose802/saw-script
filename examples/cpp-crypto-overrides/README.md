# C++ Crypto Override Specs for SAW

Cryptol specifications and SAW override templates for verifying C++ code that
calls platform cryptographic APIs.

## Files

| File | Purpose |
|------|---------|
| `CryptoSpecs.cry` | Cryptol module wrapping `cryptol-specs` SHA-256, HMAC-SHA256, and a Base64 decode spec |
| `crypto_overrides.saw` | SAWScript override definitions that map C function signatures to the Cryptol specs |

## Which platform APIs are modeled

| Cryptol spec | Windows (BCrypt) | Linux (OpenSSL) |
|---|---|---|
| `hmac_sha256` / `hmac_sha256_bytes` | `BCryptHash` with `BCRYPT_SHA256_HMAC_ALGORITHM` | `HMAC(EVP_sha256(), ...)` |
| `sha256` / `sha256_bytes` | `BCryptHash` with `BCRYPT_SHA256_ALGORITHM` | `SHA256(...)` |
| `base64_decode` | `CryptStringToBinaryA` | `EVP_DecodeBlock` / `BIO_read` |

The SAW overrides use a simplified C calling convention
(`uint8_t*` buffers + length parameters). You will need to adjust the
function names and parameter layouts to match the mangled symbols in your
specific LLVM bitcode.

## How to use

### 1. Compile your C++ to LLVM bitcode

```bash
clang++ -emit-llvm -c -g -O1 -fno-exceptions authenticate.cpp -o authenticate.bc
```

### 2. Set `CRYPTOLPATH`

The Cryptol module imports from `cryptol-specs`, so SAW needs to find it:

```bash
export CRYPTOLPATH="examples/cpp-crypto-overrides:deps/cryptol-specs"
```

### 3. Find the symbol names

```bash
llvm-nm authenticate.bc | grep -i 'hmac\|sha256\|base64'
```

Edit `crypto_overrides.saw` to use the exact mangled names.

### 4. Run SAW

```bash
saw examples/cpp-crypto-overrides/crypto_overrides.saw
```

## Override approach

The key insight is *compositional verification*:

1. **Assume** the platform crypto API behaves like the Cryptol spec
   (using `llvm_unsafe_assume_spec` or by separately verifying the
   crypto library).
2. **Verify** the application function (`Authenticate`, `validate_token`,
   etc.) using those overrides. SAW executes the application logic
   symbolically but intercepts calls to crypto APIs with the Cryptol
   equivalents.

This keeps the verification tractable—SAW never has to reason about the
internals of SHA-256 or HMAC, only about how the application *uses* them.

## Extending for additional crypto operations

To add a new override:

1. Add the Cryptol spec to `CryptoSpecs.cry`, importing from `cryptol-specs`
   where possible (AES, ChaCha20, etc. are all available).
2. Add a SAW override function in `crypto_overrides.saw` that maps the
   C function signature to the Cryptol spec.
3. Pass the override to `llvm_verify` alongside the existing ones.

Available primitives in `deps/cryptol-specs/`:
- `Primitive::Symmetric::Cipher::Block::AES` (AES-128/192/256)
- `Primitive::Symmetric::Cipher::Stream::ChaCha20`
- `Primitive::Keyless::Hash::SHA2` (SHA-224/256/384/512)
- `Primitive::Keyless::Hash::SHA3`
- `Primitive::Symmetric::MAC::HMAC`
- `Primitive::Asymmetric::Signature::RSA_PSS_SHA384`
- And many more—see `deps/cryptol-specs/README.md`
