section .rodata
    SYSCALL_WRITE   equ 1
    SYSCALL_EXIT    equ 60

    EXIT_SUCCESS    equ 0
    EXIT_FAILURE    equ 1

    STDOUT          equ 1

    LF              equ 10

    hello_world     db "Hello, World!", LF
    hello_world.len equ $-hello_world

section .text

; #[fastcall]
; #[noreturn]
; fn start() -> !
global start
start:
    ; let (exit_code := rax) = main()
    call main

    ; exit(exit_code)
    mov rdi, rax
    mov rax, SYSCALL_EXIT
    syscall

; #[fastcall]
; fn main() -> i32
global main
main:
    ; write(STDOUT, hello_world, hello_world_len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, hello_world
    mov rdx, hello_world.len
    syscall

    ; return EXIT_SUCCESS
    xor rax, rax
    ret
