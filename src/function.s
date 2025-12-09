%ifndef _FUNCTION_INC
%define _FUNCTION_INC

%define N_PUSHAS 16
%define MAX_TRACE_LEN 256
%define FN_STACK_OFFSET 16
%define FN_ALIGN 16
%define FN_SAVED_RIP_OFFSET 8
%define FN_SAVED_RBP_OFFSET 0
%define FN_UNWIND_INFO_OFFSET -8

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

        align FN_ALIGN
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
            %assign .unwind_size 0
            %assign .stack_size 0
            %assign .unwind_offset FN_UNWIND_INFO_OFFSET

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

        align FN_ALIGN
        %1:
            ; Save frame ptr
            push rbp
            mov rbp, rsp

            %assign .push_size 0
            %assign .local_size 0
            %assign .unwind_size 0
            %assign .stack_size 0
            %assign .unwind_offset FN_UNWIND_INFO_OFFSET

            ; Empty unwind info
            PUSH 0
    %endmacro
%endif

; FN <NAME>
;     ...
; END_FN <REGISTERS>,*
%macro END_FN 0-*
%ifdef DEBUG
    call stack_trace_pop_fn
%endif

    push rax
    push rdx

    call panic_call_deferred

    pop rdx
    pop rax

    add rsp, .stack_size

    %rep %0
        POP %1
    %rotate 1
    %endrep

    mov rsp, rbp
    pop rbp
    ret
%endmacro

; LOCAL <NAME>, <SIZE>
%macro LOCAL 2
    %1 equ -(%2) - .local_size - .push_size - .unwind_size

    %assign .local_size .local_size+(%2)
%endmacro

; STACK <SIZE_NAME>
%macro STACK 1
    %1 equ ALIGNED(.local_size + .unwind_size)
%endmacro

; ALLOC_STACK <SIZE_NAME>
%macro ALLOC_STACK 0
    %assign .stack_size ALIGNED(.local_size + .unwind_size)

    sub rsp, .stack_size
%endmacro

; UNWIND_PTR <NAME>
%macro UNWIND_PTR 1
    %1 equ -24 - .local_size - .push_size - .unwind_size

    mov qword [rbp + .unwind_offset], %1
    %assign .unwind_offset %1

    mov qword [rbp + %1 + UnwindInfoSinglePtr.header + UnwindInfoHeader.next_offset], 0
    mov qword [rbp + %1 + UnwindInfoSinglePtr.header + UnwindInfoHeader.drop_and_flags], 0
    mov qword [rbp + %1 + UnwindInfoSinglePtr.value_offset], 0

    %assign .unwind_size .unwind_size+24
%endmacro

; DEFER_PTR <UNWIND_OFFSET>, <LOCAL_OFFSET>, <DROP_FN>
%macro DEFER_PTR 3
    mov qword [rbp + %1 + UnwindInfoSinglePtr.header + UnwindInfoHeader.drop_and_flags], %3
    mov qword [rbp + %1 + UnwindInfoSinglePtr.value_offset], %2
%endmacro

extern stack_trace_push_fn, stack_trace_pop_fn, stack_trace_print, panic_call_deferred

%endif ; !_FUNCTION_INC
