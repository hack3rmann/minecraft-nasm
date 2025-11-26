%include "../memory.s"

section .text

; #[systemv]
; fn set((ptr := rdi): *mut u8, (value := rsi): u8, (count := rdx): usize)
set:
    ; let (value := al) = value as u8
    mov rax, rsi

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

    ret
