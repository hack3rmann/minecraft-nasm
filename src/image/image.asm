%include "../image.s"
%include "../debug.s"
%include "../memory.s"
%include "../error.s"

section .rodata
    align XMM_ALIGN
    u32x4_one     times 4 dd 1
    u24f8x4_one   times 4 dd U24F8(1, 0)

section .text

; #[systemv]
; fn Image::fill(&mut self := rdi, (color := esi): Color)
Image_fill:
    PUSH r12, r13

    ; let (self := r12) = self
    mov r12, rdi

    ; let (color := r13d) = color
    mov r13d, esi

    ; let (size := rax) = self.width as u64 * self.height as u64
    mov eax, dword [r12 + Image.width]
    mov r8d, dword [r12 + Image.height]
    mul r8

    ; set32(self.data, color, size)
    mov rdi, qword [r12 + Image.data]
    mov esi, r13d
    mov rdx, rax
    call set32

    POP r13, r12
    ret

; #[systemv]
; fn Image::slice(
;     ($ret := rdi): *mut ImageSlice,
;     &self := rsi,
;     ((x, y) := rdx): (u32, u32),
;     ((width, height) := rcx): (u32, u32),
; ) -> ImageSlice
Image_slice:
    PUSH r12, r13, r14

    ; let ($ret := r12) = $ret
    mov r12, rdi

    ; let (self := r13) = self
    mov r13, rsi

    ; let ((x, y) := r14) = (x, y)
    mov r14, rdx

    ; assert width + x <= self.width
    mov r8, rcx
    shr r8, 32
    mov r9, r14
    shr r9, 32
    add r8, r9
    cmp r8d, dword [r13 + Image.width]
    ja abort

    ; assert height + y <= self.height
    lea r8d, [r14d + ecx]
    cmp r8d, dword [r13 + Image.height]
    ja abort

    ; ($ret->width, $ret->height) = (width, height)
    rol rcx, 32
    mov qword [r12 + ImageSlice.width], rcx

    ; ($ret->total_width, $ret->total_height) = (self.width, self.height)
    mov rax, qword [r13 + Image.width]
    mov qword [r12 + ImageSlice.total_width], rax

    ; $ret->data = self.data + x + self.width * y
    mov r10, qword [r13 + Image.data]
    mov eax, r14d
    mov r8d, dword [r13 + Image.width]
    mul r8
    lea r10, [r10 + 4 * rax]
    mov r8, r14
    shr r8, 32
    lea r10, [r10 + 4 * r8]
    mov qword [r12 + ImageSlice.data], r10

    POP r14, r13, r12
    ret

; #[systemv]
; fn Image::fill_rect(
;     &mut self := rdi,
;     (color := esi): Color,
;     ((x, y) := rdx): (u32, u32),
;     ((width, height) := rcx): (u32, u32),
; )
Image_fill_rect:
    PUSH r12, r13, rbp
    mov rbp, rsp

    .slice              equ -ImageSlice.sizeof
    .stack_size         equ ALIGNED(-.slice)

    ; let slice: Image
    sub rsp, .stack_size

    ; let (self := r12) = self
    mov r12, rdi

    ; let (color := r13d) = color
    mov r13d, esi

    ; slice = self.slice((x, y), (width, height))
    lea rdi, [rbp + .slice]
    mov rsi, r12
    ; mov rdx, rdx
    ; mov rcx, rcx
    call Image_slice

    ; slice.fill(color)
    lea rdi, [rbp + .slice]
    mov esi, r13d
    call ImageSlice_fill

    add rsp, .stack_size

    POP rbp, r13, r12
    ret

; #[systemv]
; fn Image::fill_triangle(
;     &mut self := rdi,
;     (color := esi): Color,
;     (a := xmm0): u24f8x4,
;     (b := xmm1): u24f8x4,
;     (c := xmm2): u24f8x4,
; )
Image_fill_triangle:
    ; a.y = self.height as u24f8 - a.y - 1
    vpbroadcastd xmm5, dword [rdi + Image.height]
    pslld xmm5, 8
    psubd xmm5, xmm0
    psubd xmm5, [u24f8x4_one]
    vpblendd xmm0, xmm0, xmm5, 0b0010

    ; b.y = self.height as u24f8 - b.y - 1
    vpbroadcastd xmm5, dword [rdi + Image.height]
    pslld xmm5, 8
    psubd xmm5, xmm1
    psubd xmm5, [u24f8x4_one]
    vpblendd xmm1, xmm1, xmm5, 0b0010

    ; c.y = self.height as u24f8 - c.y - 1
    vpbroadcastd xmm5, dword [rdi + Image.height]
    pslld xmm5, 8
    psubd xmm5, xmm2
    psubd xmm5, [u24f8x4_one]
    vpblendd xmm2, xmm2, xmm5, 0b0010

    ; let (min := xmm3) = min(a, b, c) as u32x4
    vpminud xmm3, xmm0, xmm1
    pminud xmm3, xmm2
    psrld xmm3, 8

    ; let (max := xmm4) = max(a, b, c) as u32x4
    vpmaxud xmm4, xmm0, xmm1
    pmaxud xmm4, xmm2
    psrld xmm4, 8

    ; let ((x, y) := rdx) = (min.x, min.y)
    pextrq rdx, xmm3, 0
    rol rdx, 32

    ; let (size := xmm4) = max - min + u32x4::ONE
    paddd xmm4, [u32x4_one]
    psubd xmm4, xmm3

    ; let ((width, height) := rcx) = (size.x, size.y)
    pextrq rcx, xmm4, 0
    rol rcx, 32

    ; self.fill_rect(color, (x, y), (width, height))
    call Image_fill_rect

    ret

; #[systemv]
; fn ImageSlice::fill(&mut self := rdi, (color := esi): Color)
ImageSlice_fill:
    PUSH r12, r13, r14

    ; let (self := r12) = self
    mov r12, rdi

    ; let (color := r13d) = color
    mov r13d, esi

    ; for (i := r14) in 0..self.height {
    xor r14, r14
    .for:
    cmp r14d, dword [r12 + ImageSlice.height]
    jae .end_for

        ; set32(self.data + i * self.total_width, color, self.width)
        mov rdi, qword [r12 + ImageSlice.data]
        mov eax, dword [r12 + ImageSlice.total_width]
        mul r14
        lea rdi, [rdi + 4 * rax]
        mov esi, r13d
        mov edx, dword [r12 + ImageSlice.width]
        call set32

    ; }
    inc r14
    jmp .for
    .end_for:

    POP r14, r13, r12
    ret
