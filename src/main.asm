section .rodata
    LF              equ 10
    hello_world     db "Hello, World!", LF
    hello_world_len equ $-hello_world

section .text

global start
start:
    ; let (exit_code := rax) = main()
    call main

    ; exit(exit_code)
    mov rdi, rax
    mov rax, 60
    syscall

; fn main() -> i32
global main
main:
    ; write(STDOUT_FILENO, hello_world, hello_world_len)
    mov rax, 1
    mov rdi, 1
    mov rsi, hello_world
    mov rdx, hello_world_len
    syscall
    
    ; return 0
    xor rax, rax
    ret
