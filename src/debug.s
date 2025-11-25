%ifndef _DEBUG_INC
%define _DEBUG_INC

%define N_PUSHAS 9

%macro PUSH 0-*
    %rep %0
        push %1
    %rotate 1
    %endrep
%endmacro

%macro POP 0-*
    %rep %0
        POP %1
    %rotate 1
    %endrep
%endmacro

%macro PUSHA 0
    pushf
    PUSH rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi, \
         r0, r1, r2, r3, r4, r5 ,r6, r7, r8, r9, \
         r10, r11, r12, r13, r14, r15
%endmacro

%macro POPA 0
    POP r15, r14, r13, r12, r11, r10, r9, r8, r7, \
        r6, r5, r4, r3, r2, r1, r0, rdi, rsi, rbp, \
        rsp, rbx, rdx, rcx, rax
    popf
%endmacro

%macro DEBUG_HEX 1
    PUSHA

    ; in case we care about `rsp`
    add rsp, 8 * N_PUSHAS
    mov rdi, %1
    sub rsp, 8 * N_PUSHAS

    call print_uint_hex

    POPA
%endmacro

%macro DEBUG_UINT 1
    PUSHA

    ; in case we care about `rsp`
    add rsp, 8 * N_PUSHAS
    mov rdi, %1
    sub rsp, 8 * N_PUSHAS

    call print_uint
    call print_newline

    POPA
%endmacro

%macro DEBUG_STR 2
    PUSHA
    
    ; write(STDOUT, str.ptr, str.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, %2
    mov rdx, %1
    syscall

    call print_newline

    POPA
%endmacro

%macro DEBUG_NEWLINE 0
    PUSHA
    call print_newline
    POPA
%endmacro

%macro DEBUG_STR_INLINE 1
%push
%push
    section .rodata
        %$str     db %1
        %$str.len equ $ - %$str

    section .text
        DEBUG_STR %$str.len, %$str
%pop
%pop
%endmacro

STDIN                        equ 0
STDOUT                       equ 1
STDERR                       equ 2
LF                           equ 10

section .rodata
    newline db LF

extern format_buffer

extern init_format, deinit_format

extern print_uint_hex, print_uint, print_newline

%endif ; !_DEBUG_INC
