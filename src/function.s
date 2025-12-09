%ifndef _FUNCTION_INC
%define _FUNCTION_INC

%define N_PUSHAS 16
%define MAX_TRACE_LEN 256
%define FN_STACK_OFFSET 16

; PUSH <REGISTERS>,*
%macro PUSH 0-*
    %rep %0
        push %1
        %assign .push_size .push_size+8
    %rotate 1
    %endrep
%endmacro

; POP <REGISTERS>,*
%macro POP 0-*
    %rep %0
        POP %1
    %rotate 1
    %endrep

    %assign .push_size 0
%endmacro

; PUSHA
%macro PUSHA 0
    pushf
    PUSH rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi, \
         r8, r9, r10, r11, r12, r13, r14, r15

    %assign .push_size .push_size+8
%endmacro

; POPA
%macro POPA 0
    POP r15, r14, r13, r12, r11, r10, r9, r8, rdi, rsi, rbp, \
        rsp, rbx, rdx, rcx, rax
    popf
%endmacro

%ifdef DEBUG
    ; FN <NAME>
    ;     ...
    ; END_FN
    %macro FN 1
        %push
        %push
        %push

        %defstr %$FN_NAME %1

        section .rodata
            %$fn_name.ptr db %$FN_NAME
            %$fn_name.len equ $-%$fn_name.ptr

        section .text
        %1:
            ; Save frame ptr
            push rbp
            mov rbp, rsp

            push rax
            push rdi
            push rsi

            mov rdi, %$fn_name.len
            mov rsi, %$fn_name.ptr
            call stack_trace_push_fn

            pop rsi
            pop rdi
            pop rax

            %assign .push_size 0
            %assign .local_size 0

            ; Empty unwind info
            PUSH 0

        %pop
        %pop
        %pop
    %endmacro
%else
    ; FN <NAME>
    ;     ...
    ; END_FN
    %macro FN 1
        section .text
        %1:
            ; Save frame ptr
            push rbp
            mov rbp, rsp

            %assign .push_size 0
            %assign .local_size 0

            ; Empty unwind info
            PUSH 0
    %endmacro
%endif

; FN <NAME>
;     ...
; END_FN
%macro END_FN 0
%ifdef DEBUG
    call stack_trace_pop_fn
%endif

    mov rsp, rbp
    pop rbp
    ret
%endmacro

; LOCAL <NAME> <SIZE>
%macro LOCAL 2
    %1 equ -(%2) - .local_size - .push_size

    %assign .local_size .local_size+(%2)
%endmacro

; STACK <SIZE_NAME>
%macro STACK 1
    %1 equ ALIGNED(.local_size)
%endmacro

extern stack_trace_push_fn, stack_trace_pop_fn, stack_trace_print

%endif ; !_FUNCTION_INC
