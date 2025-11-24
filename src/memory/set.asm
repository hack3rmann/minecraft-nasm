%include "../memory.s"

section .text

; #[systemv]
; fn set((ptr := rdi): *mut u8, (value := rsi): u8, (count := rdx): usize)
set:
    ; let (value := al) = value as u8
    mov rax, rsi

    ; while (count as isize) >= 0 {
    .while:
    cmp rdx, 0
    jl .end_while

        ; *ptr = value
        mov byte [rdi], al

        ; ptr += 1
        inc rdi

        ; count -= 1
        dec rdx

    ; }
    jmp .while
    .end_while:

    ret
