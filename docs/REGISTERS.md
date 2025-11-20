# x64 Calling Conventions

## System V AMD64 ABI (Linux, macOS, BSD)

- Arguments: `RDI`, `RSI`,`RDX`, `RCX`, `R8`, `R9` (then stack)
- Return value: `RAX` (and `RDX` for 128-bit)
- Stack alignment: 16-byte before call
- Caller-saved: `RAX`, `RCX`, `RDX`, `RSI`, `RDI`, `R8`-`R11`
- Callee-saved: `RBX`, `RBP`, `R12`-`R15`
