%include "../debug.s"
%include "../memory.s"
%include "../syscall.s"

section .text

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

    ; let (value := r12) = value
    mov r12, rdi

    ; for i in n_digits - 1 + 2..=2 {
    %assign i .n_digits-1+2
    %rep .n_digits

        ; let (digit_value := rax) = value % 16
        mov rax, r12
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
        shr r12, 4

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

    add rsp, .stack_size

    pop rbp
    ret
