%include "../vector.s"
%include "../memory.s"

section .rodata
    align XMM_ALIGN
    i24f8x4_half    times 4 dd U24F8(0, 128)
    u32x4_one       times 4 dd 1
