%include "../image.s"
%include "../debug.s"
%include "../memory.s"

section .text

; Image2d::fill(&mut self := rdi, (color := esi): Color)
Image2d_fill:
    PUSH r12, r13

    ; let (self := r12) = self
    mov r12, rdi

    ; let (color := r13d) = color
    mov r13d, esi

    ; let (size := rax) = self.width as u64 * self.height as u64
    mov eax, dword [r12 + Image2d.width]
    mov r8d, dword [r12 + Image2d.height]
    mul r8

    ; set32(self.data, color, size)
    mov rdi, qword [r12 + Image2d.data]
    mov esi, r13d
    mov rdx, rax
    call set32

    POP r13, r12
    ret
