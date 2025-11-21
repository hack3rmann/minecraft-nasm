%include "../string.s"
%include "../memory.s"
%include "../debug.s"

section .text

; #[systemv]
; fn String::new(($return := rdi): *mut Self) -> Self
String_new:
    ; $return->len = 0
    mov qword [rdi + String.len], 0

    ; $return->ptr = null
    mov qword [rdi + String.ptr], 0

    ; $return->cap = 0
    mov qword [rdi + String.cap], 0

    ret

; #[systemv]
; fn String::with_capacity(($return := rdi): *mut Self, (capacity := rsi): usize) -> Self
String_with_capacity:
    push r12

    ; let (self := r12) = self
    mov r12, rdi

    ; $return->len = 0
    mov qword [r12 + String.len], 0

    ; capacity = max(16, capacity)
    mov rax, 16
    cmp rax, rsi
    cmova rsi, rax

    ; $return->cap = capacity
    mov qword [r12 + String.len], rsi

    ; $return->ptr = alloc(capacity)
    mov rdi, rsi
    call alloc
    mov qword [r12 + String.ptr], rax

    pop r12
    ret

; #[systemv]
; fn String::reserve_exact(&mut self := rdi, (additional := rsi): usize)
String_reserve_exact:
    push r12

    ; let (self := r12) = self
    mov r12, rdi

    ; let (new_cap := rax) = self.len + additional
    mov rax, qword [r12 + String.len]
    add rax, rsi

    ; if self.cap >= new_cap { return }
    cmp qword [r12 + String.cap], rax
    jae .exit

    ; self.cap = new_cap
    mov qword [r12 + String.cap], rax

    ; if self.ptr == null {
    cmp qword [r12 + String.ptr], 0
    jne .else

        ; self.ptr = alloc(new_cap)
        mov rdi, rax
        call alloc
        mov qword [r12 + String.ptr], rax

    ; } else {
    jmp .end_if
    .else:

        ; self.ptr = realloc(self.ptr, new_cap)
        mov rdi, qword [r12 + String.ptr]
        mov rsi, rax
        call realloc
        mov qword [r12 + String.ptr], rax

    ; }
    .end_if:

    .exit:
    pop r12
    ret

; FIXME(hack3rmann): debug and fix
;
; #[systemv]
; fn String::reserve(&mut self := rdi, (additional := rsi): usize)
String_reserve:
    push r12

    ; let (self := r12) = self
    mov r12, rdi

    ; let (predicted_cap := rax) = self.cap + self.cap / 2
    mov rax, qword [r12 + String.cap]
    shr rax, 1
    add rax, qword [r12 + String.cap]

    ; let (next_cap := rax) = max(predicted_cap, self.len + additional)
    mov rdi, qword [r12 + String.len]
    add rdi, rsi
    cmp rax, rdi
    cmovb rax, rdi

    ; self.reserve_exact(next_cap - self.len)
    sub rax, qword [r12 + String.len]
    mov rdi, r12
    mov rsi, rax
    call String_reserve_exact

    pop r12
    ret

; #[systemv]
; fn String::push_ascii(&mut self := rdi, (value := rsi): u8)
String_push_ascii:
    push r12
    push r13

    ; let (self := r12) = self
    mov r12, rdi

    ; let (value := r13) = value
    mov r13, rsi

    ; if self.cap == 0 {
    cmp qword [r12 + String.cap], 0
    jne .else_if
        
        ; self.ptr = alloc(16)
        mov rdi, 16
        call alloc
        mov qword [r12 + String.ptr], rax

        ; self.cap = 16
        mov qword [r12 + String.cap], 16

    ; } else if (self.cap := rax) == self.len {
    jmp .end_if
    .else_if:
    mov rax, qword [r12 + String.cap]
    cmp rax, qword [r12 + String.len]
    jne .end_if

        ; self.cap += self.cap / 2
        shr rax, 1
        add qword [r12 + String.cap], rax

        ; self.ptr = realloc(self.ptr, self.cap)
        mov rdi, qword [r12 + String.ptr]
        mov rsi, qword [r12 + String.cap]
        call realloc
        mov qword [r12 + String.ptr], rax

    ; }
    .end_if:

    ; self.ptr[self.len] = value
    mov rax, qword [r12 + String.len]
    add rax, qword [r12 + String.ptr]
    mov rdx, r13
    mov byte [rax], dl

    ; self.len += 1
    inc qword [r12 + String.len]

    pop r13
    pop r12
    ret

; #[systemv]
; fn String::push_str(&mut self := rdi, Str { len := rsi, ptr := rdx }: Str)
String_push_str:
    push r12
    push r13
    push r14

    ; let (self := r12) = self
    mov r12, rdi

    ; let (str_len := r13) = len
    mov r13, rsi

    ; let (str_ptr := r14) = ptr
    mov r14, rdx

    ; if self.cap == 0 {
    cmp qword [r12 + String.cap], 0
    jne .else_if

        ; let (new_cap := rax) = max(16, str_len)
        mov rax, 16
        cmp rax, r13
        cmovb rax, r13

        ; self.cap = new_cap
        mov qword [r12 + String.cap], rax

        ; self.ptr = alloc(new_cap)
        mov rdi, rax
        call alloc
        mov qword [r12 + String.ptr], rax

    ; } else if self.cap - self.len < str_len {
    jmp .end_if
    .else_if:
    mov rax, qword [r12 + String.cap]
    sub rax, qword [r12 + String.len]
    cmp rax, r13
    jae .end_if

        ; let (predicted_cap := rax) = self.cap + self.cap / 2
        mov rax, qword [r12 + String.cap]
        shr rax, 1
        add rax, qword [r12 + String.cap]

        ; let (next_cap := rax) = if predicted_cap - self.len >= str_len
        ; { predicted_cap } else { self.len + str_len }
        mov rdx, qword [r12 + String.len]
        add rdx, r13
        mov rdi, rax
        sub rdi, qword [r12 + String.len]
        cmp rdi, r13
        cmovb rax, rdx

        ; self.cap = next_cap
        mov qword [r12 + String.cap], rax

        ; self.ptr = realloc(self.ptr, next_cap)
        mov rdi, qword [r12 + String.ptr]
        mov rsi, rax
        call realloc
        mov qword [r12 + String.ptr], rax

    ; }
    .end_if:

    ; copy(str_ptr, self.ptr + self.len, str_len)
    mov rdi, r14
    mov rsi, qword [r12 + String.ptr]
    add rsi, qword [r12 + String.len]
    mov rdx, r13
    call copy

    ; self.len += str_len
    add qword [r12 + String.len], r13

    pop r14
    pop r13
    pop r12
    ret

; #[fastcall]
; fn String::clear(&mut self := rdi)
String_clear:
    ; self.len = 0
    mov qword [rdi + String.len], 0

    ret

; #[systemv]
; fn String::drop(&mut self := rdi)
String_drop:
    push r12

    ; let (self := r12) = self
    mov r12, rdi

    ; dealloc(self->ptr)
    mov rdi, qword [rdi + String.ptr]
    call dealloc

    ; *self = String::new()
    mov rdi, r12
    call String_new

    pop r12
    ret

; #[systemv]
; fn String::format_u64(&mut self := rdi, (value := rsi): u64)
String_format_u64:
    push rbp
    push r12
    push r13
    mov rbp, rsp

    .digits             equ -24
    .n_digits           equ 24
    .stack_size         equ ALIGNED(-.digits)

    ; let (self := r12) = self
    mov r12, rdi

    ; let digits: [u8; 24]
    sub rsp, .stack_size

    ; digits[-1] = b'0'
    mov byte [rbp+.digits+.n_digits-1], "0"

    ; let n_digits = 0
    xor rcx, rcx

    ; while value != 0 {
    .while:
    test rsi, rsi
    jz .end_while

        ; let ({ value / 10 } := rax, digit_value := rdx) = divmod(value, 10)
        xor rdx, rdx
        mov rax, rsi
        mov r8, 10
        div r8

        ; value = value / 10
        mov rsi, rax

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

    ; let (n_digits := r13) = n_digits
    mov r13, rcx

    ; self.push_str(Str { n_digits, &digits + digits.len - n_digits })
    mov rdi, r12
    mov rsi, r13
    lea rdx, [rbp + .digits + .n_digits]
    sub rdx, r13
    call String_push_str

    add rsp, .stack_size

    pop r13
    pop r12
    pop rbp
    ret
