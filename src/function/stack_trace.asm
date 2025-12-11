%include "../string.s"
%include "../function.s"
%include "../debug.s"
%include "../syscall.s"
%include "../memory.s"
%include "../error.s"

section .rodata
    STR trace_msg, "Stack trace:"
    STR trace_fmt, "  {usize}: {str}", LF

section .bss
    ; static stack_trace: [Str; MAX_TRACE_LEN]
    align Str.alignof
    stack_trace resb MAX_TRACE_LEN * Str.sizeof

section .data
    ; static stack_trace_len: usize = 0
    stack_trace_len dq 0

section .text

; NOTE(hack3rmann): this can't be an `FN`-type function, because it will call itself indefinitely
;
; #[fastcall(rax)]
; fn stack_trace_push_fn((name := rdi:rsi): Str)
stack_trace_push_fn:
    ; if stack_trace_len < MAX_TRACE_LEN {
    cmp qword [stack_trace_len], MAX_TRACE_LEN
    jae .end_if

        ; stack_trace[stack_trace_len] = name
        mov rax, qword [stack_trace_len]
        shl rax, Str.sizeof_log2
        mov qword [stack_trace + rax + Str.len], rdi
        mov qword [stack_trace + rax + Str.ptr], rsi

    ; }
    .end_if:

    ; stack_trace_len += 1
    inc qword [stack_trace_len]

    ret

; #[fastcall]
; fn stack_trace_pop_fn()
stack_trace_pop_fn:
    ; if stack_trace_len == 0 { return }
    cmp qword [stack_trace_len], 0
    je .exit

    ; stack_trace_len -= 1
    dec qword [stack_trace_len]
    
    .exit:
    ret

; #[nothrow]
; #[systemv]
; fn stack_trace_print()
FN stack_trace_print
    PUSH r12

    LOCAL .args, 8 + Str.sizeof
    .args.index equ .args + 0
    .args.name  equ .args + 8
    ALLOC_STACK

    DEBUG_STR trace_msg.len, trace_msg.ptr

    ; format_buffer.clear()
    mov rdi, format_buffer
    call String_clear

    ; for (i := r12) in 0..stack_trace_len {
    xor r12, r12
    .for:
    cmp r12, qword [stack_trace_len]
    jae .end_for

        ; args.index = i + 1
        lea rax, [r12 + 1]
        mov qword [rbp + .args.index], rax

        ; args.name = stack_trace[i]
        mov rcx, r12
        shl rcx, Str.sizeof_log2
        mov rax, qword [stack_trace + rcx + Str.len]
        mov qword [rbp + .args.name + Str.len], rax
        mov rax, qword [stack_trace + rcx + Str.ptr]
        mov qword [rbp + .args.name + Str.ptr], rax

        ; format_buffer.format_array(trace_fmt, &args)
        mov rdi, format_buffer
        mov rsi, trace_fmt.len
        mov rdx, trace_fmt.ptr
        lea rcx, [rbp + .args]
        call String_format_array

    ; }
    inc r12
    jmp .for
    .end_for:

    ; write(STDERR, format_buffer.ptr, format_buffer.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDERR
    mov rsi, qword [format_buffer + String.ptr]
    mov rdx, qword [format_buffer + String.len]
    syscall
END_FN r12
