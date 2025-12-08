%include "../syscall.s"
%include "../error.s"
%include "../function.s"
%include "../debug.s"

section .text

; #[noreturn]
; #[jumpable]
; fn abort() -> !
FN abort
    ; stack_trace_print()
    call stack_trace_print

    ; let (pid := rax) = getpid()
    mov rax, SYSCALL_GETPID
    syscall

    ; kill(pid, SIGABRT)
    mov rdi, rax
    mov rax, SYSCALL_KILL
    mov rsi, SIGABRT
    syscall

    ; // do exit in case if SIGABRT have been handled
    ; exit(EXIT_FAILURE)
    mov rax, SYSCALL_EXIT
    mov rdi, EXIT_FAILURE
    syscall

    ; // loop forever just in case
    .loop:
    jmp .loop
END_FN

; #[fastcall]
; fn exit_on_error((code := rax): usize)
exit_on_error:
    ; if code < 0 { abort() }
    cmp rax, 0
    jl abort
    ret
