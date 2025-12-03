%include "../debug.s"
%include "../memory.s"
%include "../syscall.s"
%include "../error.s"

section .text

; #[systemv]
; fn print_int((value := rdi): i64)
print_int:
    push rbp
    push r12
    push r13
    push rbx
    mov rbp, rsp

    .digits             equ -24
    .n_digits           equ 24
    .stack_size         equ ALIGNED(-.digits)

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

    add rsp, .stack_size

    pop rbx
    pop r13
    pop r12
    pop rbp
    ret

; #[systemv]
; fn print_uint((value := rdi): usize)
print_uint:
    push rbp
    mov rbp, rsp

    .digits             equ -24
    .n_digits           equ 24
    .stack_size         equ ALIGNED(-.digits)

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

    add rsp, .stack_size

    pop rbp
    ret

; fn print_uint_hex((value := rdi): usize)
print_uint_hex:
    push rbp
    mov rbp, rsp

    .digits       equ -24
    .n_digits     equ 16
    .stack_size   equ ALIGNED(-.digits)

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

    add rsp, .stack_size

    pop rbp
    ret

; #[systemv]
; fn print_newline()
print_newline:
    ; write(STDOUT, &newline, 1)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, newline
    mov rdx, 1
    syscall
    call exit_on_error

    ret
