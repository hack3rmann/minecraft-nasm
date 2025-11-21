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

; #[systemv]
; fn String::drop(&mut self := rdi)
String_drop:
    ; let (self := r8) = self
    mov r8, rdi

    ; dealloc(self->ptr)
    mov rdi, qword [rdi + String.ptr]
    call dealloc

    ; *self = String::new()
    mov rdi, r8
    call String_new

    ret
