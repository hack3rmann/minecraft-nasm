%ifndef _DEBUG_INC
%define _DEBUG_INC

%define N_PUSHAS 9

%macro PUSHA 0
    pushf
    push rax
    push rcx
    push rdx
    push rbx
    push rsp
    push rbp
    push rsi
    push rdi
%endmacro

%macro POPA 0
    pop rdi
    pop rsi
    pop rbp
    pop rsp
    pop rbx
    pop rdx
    pop rcx
    pop rax
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

%macro DEBUG_NEWLINE 0
    PUSHA
    call print_newline
    POPA
%endmacro

STDIN                        equ 0
STDOUT                       equ 1
STDERR                       equ 2
LF                           equ 10

section .rodata
    newline db LF

extern print_uint_hex, print_uint, print_newline

%endif ; !_DEBUG_INC
