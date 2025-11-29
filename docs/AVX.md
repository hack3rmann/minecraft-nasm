## Registers

- `xmm0`-`xmm15` 128-bit registers
- `ymm0`-`ymm15` 256-bit registers

## Definitions

- **packed** means "multiple data"
- **scalar** means "only the first element"

- type `i24f8x4` means 4d-vector of fixed point numbers (24-bit whole part + 8-bit fraction)

## Instructions

### Add

For `i32x4`

- `paddd xmm0, xmm1/m128` in SSE
- `vpaddd xmm0, xmm1, xmm2/m128` in AVX

### Multiply

For `i32x4`

- `pmulld xmm0, xmm1/m128` in SSE
- `vpmulld xmm0, xmm1, xmm2/m128` in AVX

### XOR

Packed integer XOR

- `vpxor ymm0, ymm1, ymm2/m256`
- `vpxor xmm0, xmm1, xmm2/m128`

### Shift

Packed integer SHL

- `pslld xmm0, xmm1/c128`
- `vpslld xmm0, xmm1, xmm2/c128`

### Load/Store

Aligned packed `f32x8` load/store

- `vmovaps m256, ymm0`
