%include "../debug.s"
%include "../memory.s"
%include "../syscall.s"
%include "../error.s"
%include "../string.s"
%include "../function.s"

section .rodata
    newline       db LF
    i32x4_fmt.ptr db "({isize}, {isize}, {isize}, {isize})", LF
    i32x4_fmt.len equ $-i32x4_fmt.ptr

section .text

; #[systemv]
; fn print_int((value := rdi): i64)
FN print_int
    PUSH r12, r13, rbx

    .n_digits           equ 24
    LOCAL .digits, .n_digits
    ALLOC_STACK

    ; let digits: [u8; 24]
    sub rsp, .stack_size

    ; digits[-1] = b'0'
    mov byte [rbp + .digits + .n_digits - 1], "0"

    ; let (n_digits := rcx) = 0
    xor rcx, rcx

    ; let (is_negative := bl) = false
    xor bl, bl

    ; if value < 0 {
    cmp rdi, 0
    jge .end_if_less

        ; is_negative = true
        inc bl

        ; value = -value
        neg rdi

        ; digits = [b'-'; 24]
        mov dword [rbp + .digits + 0], "----"
        mov dword [rbp + .digits + 4], "----"
        mov dword [rbp + .digits + 8], "----"
        mov dword [rbp + .digits + 12], "----"
        mov dword [rbp + .digits + 16], "----"
        mov dword [rbp + .digits + 20], "----"

    ; }
    .end_if_less:

    ; while value != 0 {
    .while:
    test rdi, rdi
    jz .end_while

        ; let ({ value / 10 } := rax, digit_value := rdx) = divmod(value, 10)
        xor rdx, rdx
        mov rax, rdi
        mov r8, 10
        div r8

        ; value = value / 10
        mov rdi, rax

        ; let (digit := dl) = (digit_value + '0') as u8
        add rdx, "0"

        ; digits[digits.len - 1 - n_digits] = digit
        mov r8, rcx
        neg r8
        mov byte [rbp + .digits + .n_digits - 1 + r8], dl

        ; n_digits += 1
        inc rcx

    ; }
    jmp .while
    .end_while:

    ; if n_digits == 0 { n_digits = 1 }
    test rcx, rcx
    mov rax, 1
    cmovz rcx, rax

    ; if is_negative { n_digits += 1 }
    movzx rbx, bl
    add rcx, rbx

    ; let (n_digits := r13) = n_digits
    mov r13, rcx

    ; write(STDOUT, &digits + digits.len - n_digits, n_digits)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    lea rsi, [rbp + .digits + .n_digits]
    sub rsi, r13
    mov rdx, r13
    syscall
    call exit_on_error
END_FN rbx, r13, r12

; #[systemv]
; fn print_uint((value := rdi): usize)
FN print_uint
    .n_digits equ 24
    LOCAL .digits, .n_digits
    ALLOC_STACK

    ; let digits: [u8; 24]
    sub rsp, .stack_size

    ; digits[-1] = b'0'
    mov byte [rbp+.digits+.n_digits-1], "0"

    ; let n_digits = 0
    xor rcx, rcx

    ; while value != 0 {
    .while:
    test rdi, rdi
    jz .end_while

        ; let ({ value / 10 } := rax, digit_value := rdx) = divmod(value, 10)
        xor rdx, rdx
        mov rax, rdi
        mov r8, 10
        div r8

        ; value = value / 10
        mov rdi, rax

        ; let (digit := dl) = (digit_value + '0') as u8
        add rdx, "0"

        ; digits[digits.len - 1 - n_digits] = digit
        mov r8, rcx
        neg r8
        mov byte [rbp + .digits + .n_digits - 1 + r8], dl

        ; n_digits += 1
        inc rcx

    ; }
    jmp .while
    .end_while:

    ; if n_digits == 0 { n_digits = 1 }
    test rcx, rcx
    mov rax, 1
    cmovz rcx, rax

    ; write(STDOUT, &digits + digits.len - n_digits, n_digits)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    lea rsi, [rbp + .digits + .n_digits]
    sub rsi, rcx
    mov rdx, rcx
    syscall
    call exit_on_error
END_FN

; fn print_uint_hex((value := rdi): usize)
FN print_uint_hex
    .n_digits equ 16
    LOCAL .digits, 24
    ALLOC_STACK

    ; let digits: [u8; 19] = [0; 19]
    push 0
    push 0
    push 0

    ; digits[..2] = b"0x"
    mov word [rbp+.digits], "0x"

    ; digits[-1] = b'\n'
    mov byte [rbp+.digits+2+.n_digits], LF

    ; let (value := r8) = value
    mov r8, rdi

    ; for i in n_digits - 1 + 2..=2 {
    %assign i .n_digits-1+2
    %rep .n_digits

        ; let (digit_value := rax) = value % 16
        mov rax, r8
        and rax, 0xF

        ; let (char_difference := rdx) = if digit_value < 10 { '0' } else { 'A' - 10 }
        mov rdx, 'A'-10
        mov rbx, '0'
        cmp rax, 10
        cmovl rdx, rbx

        ; let (digit := rax) = (digit_value + char_difference) as u8
        add rax, rdx

        ; digits[i] = digit as u8
        mov byte [rbp+.digits+i], al

        ; value /= 16
        shr r8, 4

    ; }
    %assign i i-1
    %endrep

    ; write(STDOUT, &digits, 19)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, rbp
    add rsi, .digits
    mov rdx, 19
    syscall
    call exit_on_error
END_FN

; #[systemv]
; fn print_newline()
FN print_newline
    ; write(STDOUT, &newline, 1)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, newline
    mov rdx, 1
    syscall
    call exit_on_error
END_FN

; #[systemv]
; fn print_i32x4((value := xmm0): i32x4)
FN print_i32x4
    LOCAL .values, 64
    ALLOC_STACK

    ; for i in 0..4 {
    %assign i 0
    %rep 4

        ; values[i] = value[i] as i64
        pextrd eax, xmm0, i
        movsx rax, eax
        mov qword [rbp + .values + 8 * i], rax

    ; }
    %assign i i+1
    %endrep

    ; format_buffer.clear()
    mov rdi, format_buffer
    call String_clear

    ; format_buffer.format_array(i32x4_fmt, &values)
    mov rdi, format_buffer
    mov rsi, i32x4_fmt.len
    mov rdx, i32x4_fmt.ptr
    lea rcx, [rbp + .values]
    call String_format_array

    ; write(STDOUT, format_buffer.ptr, format_buffer.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, qword [format_buffer + String.ptr]
    mov rdx, qword [format_buffer + String.len]
    syscall
    call exit_on_error
END_FN
