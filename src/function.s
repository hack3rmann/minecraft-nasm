%ifndef _FUNCTION_INC
%define _FUNCTION_INC

%define N_PUSHAS 16

%macro PUSH 0-*
    %rep %0
        push %1
        %assign .push_size .push_size+8
    %rotate 1
    %endrep
%endmacro

%macro POP 0-*
    %rep %0
        POP %1
    %rotate 1
    %endrep

    %assign .push_size 0
%endmacro

%macro PUSHA 0
    pushf
    PUSH rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi, \
         r8, r9, r10, r11, r12, r13, r14, r15
%endmacro

%macro POPA 0
    POP r15, r14, r13, r12, r11, r10, r9, r8, rdi, rsi, rbp, \
        rsp, rbx, rdx, rcx, rax
    popf
%endmacro

; FUNCTION <NAME>
%macro FN 1
%1:
    push rbp
    mov rbp, rsp

    %assign .push_size 0
    %assign .local_size 0
%endmacro

%macro END_FN 0
    mov rsp, rbp
    pop rbp
    ret
%endmacro

%macro LOCAL 2
    %1 equ -%2 - .local_size - .push_size

    %assign .local_size .local_size+%2
%endmacro

%macro STACK 1
    %1 equ ALIGNED(.local_size)
%endmacro

%endif ; !_FUNCTION_INC
