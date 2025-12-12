%define SYSCALL_READ   0
%define SYSCALL_WRITE  1
%define SYSCALL_GETPID 39
%define SYSCALL_EXIT   60
%define SYSCALL_KILL   62

%define SIGABRT        6

%define EXIT_FAILURE   1

%define STDIN          0
%define STDOUT         1
%define STDERR         2

%define LF 10

%define READ_LEN       4096

struc StringBuffer
    .len          resq 1
                  resb 32-8 ; padding
    .data         resb READ_LEN
    .sizeof       equ $-.len
    .alignof      equ 32
endstruc

section .rodata
    hello_world.ptr   db "Hello, World!", LF
    hello_world.len   equ $-hello_world.ptr

section .data
    argc        dq 0
    argv        dq 0
    stack_align dq 0

    align 16
    stdin_buffer      times StringBuffer.sizeof db 0

section .text

; #[systemv]
; #[noreturn]
; #[jumpable]
; fn abort() -> !
abort:
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

; #[syscall]
; fn StringBuffer::fill_from(&mut self := rdi, (fd := esi): Fd) -> ErrorCode := rax
StringBuffer_fill_from:
    push r12
    push r13

    ; let (self := r12) = self
    mov r12, rdi

    ; let (fd := r13d) = esi
    mov r13d, esi

    ; let (n_bytes := rax) = read(fd, &self.data, READ_LEN)
    mov rax, SYSCALL_READ
    mov edi, r13d
    lea rsi, [r12 + StringBuffer.data]
    mov rdx, READ_LEN
    syscall

    ; if n_bytes < 0 { return n_bytes }
    cmp rax, 0
    jl .exit

    ; if n_bytes > READ_LEN { return n_bytes }
    cmp rax, READ_LEN
    jg .exit

    ; self.len = n_bytes
    mov qword [r12 + StringBuffer.len], rax

    ; return 0
    xor rax, rax

    .exit:
    pop r13
    pop r12
    ret

; #[systemv]
; fn main() -> i64 := rax
main:
    ; let (error := rax) = stdin_buffer.fill_from(STDIN)
    mov rdi, stdin_buffer
    mov esi, STDIN
    call StringBuffer_fill_from

    ; assert error == 0
    test rax, rax
    jnz abort

    ; write(STDOUT, &stdin_buffer.data, stdin_buffer.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, stdin_buffer + StringBuffer.data
    mov rdx, qword [stdin_buffer + StringBuffer.len]
    syscall

    ; return 0
    xor rax, rax

    ret

global start
start:
    ; argc = get_argc_from_stack()
    mov rax, qword [rsp]
    mov qword [argc], rax

    ; argv = get_argv_from_stack()
    lea rax, [rsp + 8]
    mov qword [argv], rax

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

    ; exit(0)
    mov rax, SYSCALL_EXIT
    xor rdi, rdi
    syscall
