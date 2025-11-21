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
