%include "../syscall.inc.asm"
%include "../error.inc.asm"

; #[noreturn]
; fn abort() -> !
abort:
    ; exit(EXIT_FAILURE)
    mov rax, SYSCALL_EXIT
    mov rdi, EXIT_FAILURE
    syscall

    ; do return just in case
    ret
