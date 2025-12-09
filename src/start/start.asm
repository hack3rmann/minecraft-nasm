%include "../syscall.s"
%include "../start.s"
%include "../function.s"
%include "../panic.s"

section .bss
    ; pub static argc: usize
    argc resq 1

    ; pub static argv: *const *const u8
    argv resq 1

    ; pub static envp: *const *const u8
    envp resq 1

    ; static stack_align: usize
    stack_align resq 1

section .text

; #[nocall]
; #[noreturn]
; pub fn start() -> !
FN start
    ; Higher addresses
    ; ┌───────────────────┐
    ; │ ...               │
    ; ├───────────────────┤
    ; │ NULL              │ ← End of environment pointers
    ; ├───────────────────┤
    ; │ ...               │
    ; │ envp[2]           │ ← Environment variable strings  
    ; │ envp[1]           │   (each is "NAME=VALUE")
    ; │ envp[0]           │
    ; ├───────────────────┤
    ; │ argv[argc] = NULL │ ← End of argument pointers  
    ; │ ...               │
    ; │ argv[1]           │ ← Command-line arguments
    ; │ argv[0]           │ ← Program name
    ; ├───────────────────┤
    ; │ argc              │ ← Argument count (integer)
    ; └───────────────────┘
    ; Lower addresses

    ; setup_unwind()
    mov qword [rbp + FN_UNWIND_INFO_OFFSET + UnwindHeader.offset], UNWIND_OFFSET_END

    ; argc = get_argc_from_stack()
    mov rax, qword [rsp + FN_STACK_OFFSET]
    mov qword [argc], rax

    ; argv = get_argv_from_stack()
    lea rax, [rsp + 8 + FN_STACK_OFFSET]
    mov qword [argv], rax

    ; envp = get_envp_from_stack()
    mov rax, qword [argc]
    lea rax, [8 * rax + 16 + rsp + FN_STACK_OFFSET]
    mov qword [envp], rax

    ; let stack_align = rsp % 16
    mov rax, rsp
    and rax, 0xF
    mov qword [stack_align], rax

    ; align(16) stack before `main()`
    sub rsp, rax

    ; let (exit_code := rax) = main()
    call main

    ; unalign the stack
    add rsp, qword [stack_align]

    ; exit(exit_code)
    mov rdi, rax
    mov rax, SYSCALL_EXIT
    syscall
END_FN
