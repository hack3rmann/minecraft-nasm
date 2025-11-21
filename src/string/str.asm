%include "../string.s"
%include "../debug.s"

section .text

; #[systemv]
; fn Str::eq((lhs := rdi:rsi): Str, (rhs := rdx:rcx): Str) -> bool := al
Str_eq:
    ; let (result := al) = false
    xor al, al

    ; if lhs.len != rhs.len { return false }
    cmp rdi, rdx
    jne .exit

    ; while lhs.len > 0 {
    .while:
    test rdi, rdi
    jz .end_while

        ; if *lhs.ptr != *rhs.ptr { return false }
        mov ah, byte [rsi]
        cmp ah, byte [rcx]
        jne .exit

        ; lhs.ptr += 1
        inc rsi

        ; rhs.ptr += 1
        inc rcx

        ; lhs.len -= 1
        dec rdi

    ; }
    jmp .while
    .end_while:

    ; return true
    mov al, 1
    
    .exit:
    ret
