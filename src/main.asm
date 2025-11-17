section .text

global start
start:
    mov rax, 60
    xor rdi, rdi
    syscall
