%include "../syscall.s"
%include "../error.s"
%include "../debug.s"

section .rodata
    abort_error                   db "The process has been aborted", LF
    abort_error.len               equ $-abort_error

section .text

; #[noreturn]
; #[jumpable]
; fn abort() -> !
abort:
    ; write(STDOUT, abort_error, abort_error.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, abort_error
    mov rdx, abort_error.len
    syscall

    ; exit(EXIT_FAILURE)
    mov rax, SYSCALL_EXIT
    mov rdi, EXIT_FAILURE
    syscall

    ; do return just in case
    ret

; #[fastcall]
; fn exit_on_error((code := rax): usize)
exit_on_error:
    ; if code < 0 { abort() }
    cmp rax, 0
    jl abort
    ret
