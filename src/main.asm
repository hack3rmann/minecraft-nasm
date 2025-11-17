section .rodata
    SYSCALL_WRITE   equ 1
    SYSCALL_EXIT    equ 60

    EXIT_SUCCESS    equ 0
    EXIT_FAILURE    equ 1

    STDOUT          equ 1

    LF              equ 10

    hello_world     db "Hello, World!", LF
    hello_world.len equ $-hello_world
    cstring         db "This is a C-string!!!", LF, 0

section .bss
    ; static argc: usize
    argc resq 1
    ; static argv: *const *const u8
    argv resq 1
    ; static envp: *const *const u8
    envp resq 1

section .text

; #[nocall]
; #[noreturn]
; fn start() -> !
global start
start:
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

    ; argc = get_argc_from_stack()
    mov rax, qword [rsp]
    mov qword [argc], rax

    ; argv = get_argv_from_stack()
    lea rax, [rsp+8]
    mov qword [argv], rax

    ; envp = get_envp_from_stack()
    mov rax, qword [argc]
    lea rax, [8*rax+16+rsp]
    mov qword [envp], rax

    ; let (exit_code := rax) = main()
    call main

    ; exit(exit_code)
    mov rdi, rax
    mov rax, SYSCALL_EXIT
    syscall

; #[fastcall(all)]
; fn main() -> i64
global main
main:
    ; print_cstr(envp[0])
    mov rsi, qword [envp]
    mov rsi, qword [rsi+6*8]
    call print_cstr

    ; return EXIT_SUCCESS
    xor rax, rax
    ret

; #[fastcall(al, rdx)]
; fn cstr_len((ptr := rsi): *const u8) -> usize := rdx
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

; #[fastcall(rdx, rax, rdi)]
; fn print_cstr((ptr := rsi): *const u8)
print_cstr:
    ; let (len := rdx) = cstr_len(ptr)
    call cstr_len

    ; write(STDOUT, ptr, len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    syscall

    ret
