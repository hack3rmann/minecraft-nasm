%include "../memory.s"

section .text

; #[fastcall(rdi, rsi, rdx, al)]
; fn copy((source := rdi): *mut u8, (dest := rsi): *mut u8, (size := rdx): usize)
copy:
    ; while (size as isize) >= 0 {
    .while:
    cmp rdx, 0
    jl .end_while

        ; *dest = *source
        mov al, byte [rdi]
        mov byte [rsi], al

        ; dest += 1
        inc rsi

        ; source += 1
        inc rdi

        ; size -= 1
        dec rdx

    ; }
    jmp .while
    .end_while:

    ret
