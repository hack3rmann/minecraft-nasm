%include "../memory.s"
%include "../function.s"

section .text

; #[systemv]
; fn set8((ptr := rdi): *mut u8, (value := sil): u8, (count := rdx): usize)
FN set8
    ; let (value := al) = value as u8
    mov al, sil

    ; while count != 0 {
    .while:
    test rdx, rdx
    jz .end_while

        ; *ptr = value
        mov byte [rdi], al

        ; ptr += 1
        inc rdi

        ; count -= 1
        dec rdx

    ; }
    jmp .while
    .end_while:
END_FN

; #[systemv]
; fn set32((ptr := rdi): *mut u32, (value := esi): u32, (count := rdx): usize)
FN set32
    PUSH r12, r13, r14

    ; let (ptr := r12) = ptr
    mov r12, rdi

    ; let (value := r13d) = value
    mov r13d, esi

    ; let (count := r14) = count
    mov r14, rdx

    ; while count != 0 && ptr % 32 != 0 {
    .while_head:
    test r14, r14
    jz .end_while_head
    test r12, 31
    jz .end_while_head

        ; *ptr = value
        mov dword [r12], r13d

        ; ptr += 1
        add r12, 4

        ; count -= 1
        dec r14

    ; }
    jmp .while_head
    .end_while_head:

    ; if count == 0 { return }
    test r14, r14
    jz .exit

    ; let (compacted_value := ymm0) = u32x8::splat(value)
    vmovd xmm0, r13d
    vpbroadcastd ymm0, xmm0

    ; while count >= 8 && ptr % 32 == 0 {
    .while_aligned:
    cmp r14, 8
    jb .end_while_aligned
    test r12, 31
    jnz .end_while_aligned

        ; *ptr.cast::<u32x8>() = compacted_value
        vmovaps [r12], ymm0

        ; ptr += sizeof(u32x8) / sizeof(u32)
        add r12, 32

        ; count -= 8
        sub r14, 8

    ; }
    jmp .while_aligned
    .end_while_aligned:

    ; if count == 0 { return }
    test r14, r14
    jz .exit

    ; while count != 0 {
    .while_tail:
    test r14, r14
    jz .end_while_tail

        ; *ptr = value
        mov dword [r12], r13d

        ; ptr += 1
        add r12, 4

        ; count -= 1
        dec r14

    ; }
    jmp .while_tail
    .end_while_tail:

    .exit:
END_FN r14, r13, r12

; #[systemv]
; fn set256((ptr := rdi): *mut u256, (value := ymm0): u256, (count := rdx): usize)
FN set256
    ; let (value := eax) = value as u32
    mov eax, esi

    ; while count != 0 {
    .while:
    test rdx, rdx
    jz .end_while

        ; *ptr = value
        vmovaps [rdi], ymm0

        ; ptr += 1
        add rdi, 32

        ; count -= 1
        dec rdx

    ; }
    jmp .while
    .end_while:
END_FN
