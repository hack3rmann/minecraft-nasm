%include "../env.inc.asm"
%include "../string.inc.asm"

extern envp

section .text

; #[fastcall(rbx, rcx, ax)]
; pub unsafe fn get_env((name: rdi): *const u8, (name_len := rdx): usize) -> *const u8 := rsi
get_env:
    ; let (i := rbx) = 0
    xor rbx, rbx

    ; for (envp[i] := rsi) != null {
    .while:
    mov rsi, qword [envp]
    mov rsi, qword [rsi+8*rbx]
    test rsi, rsi
    jz .end_while

        ; let (match_len := rcx) = cstr_match_length(envp[i] := rsi, name := rdi)
        call cstr_match_length

        ; if match_len == name_len {
        cmp rcx, rdx
        jne .end_if

            ; return envp[i][match_len + 1..]
            lea rsi, [rsi+rcx+1]
            ret

        ; }
        .end_if:

        ; i += 1
        inc rbx

    ; }
    jmp .while
    .end_while:

    ; return null
    xor rsi, rsi
    ret
