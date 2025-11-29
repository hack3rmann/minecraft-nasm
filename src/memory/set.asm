%include "../memory.s"

section .text

; #[systemv]
; fn set8((ptr := rdi): *mut u8, (value := rsi): u8, (count := rdx): usize)
set8:
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

; #[systemv]
; fn set32((ptr := rdi): *mut u32, (value := esi): u32, (count := rdx): usize)
set32:
    ; let (value := eax) = value as u32
    mov eax, esi

    ; while count != 0 {
    .while:
    test rdx, rdx
    jz .end_while

        ; *ptr = value
        mov dword [rdi], eax

        ; ptr += 1
        add rdi, 4

        ; count -= 1
        dec rdx

    ; }
    jmp .while
    .end_while:

    ret
