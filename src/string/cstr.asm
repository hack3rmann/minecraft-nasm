%include "../string.s"
%include "../syscall.s"
%include "../debug.s"

section .text

; # Safety
;
; - both `source` and `template` should be non-null
;
; #[fastcall(rcx, ax)]
; unsafe fn cstr_match_length(
;     (source := rsi): *const u8,
;     (template := rdi): *const u8,
; ) -> usize := rcx
cstr_match_length:
    ; let (i := rcx) = 0
    xor rcx, rcx

    ; while source[i] != '\0' && template[i] != '\0' && source[i] == template[i] {
    .while:
    mov ah, byte [rsi+rcx]
    mov al, byte [rdi+rcx]
    cmp ah, ah
    jne .end_while
    test al, al
    jz .end_while
    cmp ah, al
    jne .end_while

        ; i += 1
        inc rcx

    ; }
    jmp .while
    .end_while:

    ret

; # Safety
;
; - `ptr` should be non-null
;
; #[fastcall(al, rdx)]
; unsafe fn cstr_len((ptr := rsi): *const u8) -> usize := rdx
cstr_len:
    ; let (result := rdx) = 0
    xor rdx, rdx

    ; while *(ptr + result) != null {
    .while:
    mov al, byte [rsi+rdx]
    test al, al
    jz .end_while

        ; result += 1
        inc rdx

    ; }
    jmp .while
    .end_while:

    ret

; # Safety
;
; - `ptr` should be non-null
;
; #[fastcall(all)]
; fn print_cstr((ptr := rsi): *const u8)
print_cstr:
    ; let (len := rdx) = cstr_len(ptr)
    call cstr_len

    ; write(STDOUT, ptr, len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    syscall

    ret
