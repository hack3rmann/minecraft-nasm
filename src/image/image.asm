%include "../image.s"
%include "../debug.s"
%include "../memory.s"
%include "../error.s"
%include "../vector.s"

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
    vpblendd xmm0, xmm0, xmm5, BLEND(0, 1, 0, 0)

    ; b.y = self.height as u24f8 - b.y - 1
    vpbroadcastd xmm5, dword [rdi + Image.height]
    pslld xmm5, 8
    psubd xmm5, xmm1
    psubd xmm5, [u24f8x4_one]
    vpblendd xmm1, xmm1, xmm5, BLEND(0, 1, 0, 0)

    ; c.y = self.height as u24f8 - c.y - 1
    vpbroadcastd xmm5, dword [rdi + Image.height]
    pslld xmm5, 8
    psubd xmm5, xmm2
    psubd xmm5, [u24f8x4_one]
    vpblendd xmm2, xmm2, xmm5, BLEND(0, 1, 0, 0)

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

    ; let (size := xmm5) = max - min + u32x4::ONE
    vpaddd xmm5, xmm4, [u32x4_one]
    psubd xmm5, xmm3

    ; let ((width, height) := rcx) = (size.x, size.y)
    pextrq rcx, xmm5, 0
    rol rcx, 32

    ; self.fill_rect(color, (x, y), (width, height))
    call Image_fill_rect

    ret

; #[fastcall(rax, rdx, r8)]
; fn Image::set_pixel(
;     &mut self := rdi,
;     (color := esi): Color,
;     ((x, y) := rdx): (u32, u32),
; )
Image_set_pixel:
    ; let ((x, y) := r8) = (x, y)
    mov r8, rdx

    ; assert x < self.width
    mov rax, r8
    shr rax, 32
    cmp eax, dword [rdi + Image.width]
    jae abort

    ; assert y < self.height
    cmp r8d, dword [rdi + Image.height]
    jae abort

    ; let (index := rax) = x + self.width * y
    mov eax, dword [rdi + Image.width]
    mov edx, r8d
    mul rdx
    mov rdx, r8
    shr rdx, 32
    add rax, rdx

    ; self.data[index] = color
    shl rax, 2
    add rax, qword [rdi + Image.data]
    mov dword [rax], esi

    ret

; #[systemv]
; fn Image::draw_line(
;     &mut self := rdi,
;     (color := esi): Color,
;     (from := xmm0): i24f8x4,
;     (to := xmm1): i24f8x4,
; )
Image_draw_line:
    PUSH r12, r13, r14, r15, rbx

    ; let (delta := xmm2) = to - from
    vpsubd xmm2, xmm1, xmm0

    ; let (abs_dir := xmm3) = dir.abs()
    pabsd xmm3, xmm2

    ; let (perm_shift := r15b) = if abs_dir.y < abs_dir.x {
    pextrd edx, xmm3, 0
    pextrd eax, xmm3, 1
    cmp eax, edx
    jge .else_abs_dir

        ; perm_shift = 0
        xor r15b, r15b

    ; } else {
    jmp .end_if_abs_dir
    .else_abs_dir:

        ; mem::swap(&mut from.x, &mut from.y)
        pshufd xmm0, xmm0, SHUF(1, 0, 2, 3)

        ; mem::swap(&mut to.x, &mut to.y)
        pshufd xmm1, xmm1, SHUF(1, 0, 2, 3)

        ; mem::swap(&mut delta.x, &mut delta.y)
        pshufd xmm2, xmm2, SHUF(1, 0, 2, 3)

        ; mem::swap(&mut abs_dir.x, &mut abs_dir.y)
        pshufd xmm3, xmm3, SHUF(1, 0, 2, 3)

        ; perm_shift = 32
        mov r15b, 32

    ; }
    .end_if_abs_dir:

    ; let (n_steps := r13d) = abs_dir.x.round_up() as u32
    pextrd r13d, xmm3, 0
    add r13d, U24F8(0, 255)
    shr r13d, 8

    ; let (sign_x := r14d) = delta.x.sign()
    pextrd r14d, xmm2, 0
    sar r14d, 31 ; r14d = (-1|0)
    shl r14d, 1  ; r14d = (-2|0)
    inc r14d     ; r14d = (-1|1)
    shl r14d, 8  ; r14d = (-256|256)

    ; let (sign_y := ebx) = delta.y.sign()
    pextrd ebx, xmm2, 1
    sar ebx, 31 ; ebx = (-1|0)
    shl ebx, 1  ; ebx = (-2|0)
    inc ebx     ; ebx = (-1|1)
    shl ebx, 8  ; ebx = (-256|256)

    ; let (normal := xmm2) = i24f8x4::new(-delta.y, delta.x, ..delta)
    pshufd xmm2, xmm2, SHUF(1, 0, 2, 3)    ; (x, y, z, w) |-> (y, x, z, w)
    pxor xmm3, xmm3
    vpsubd xmm3, xmm3, xmm2                ; xmm3 = -(y, x, z, w)
    vpblendd xmm2, xmm3, BLEND(1, 0, 0, 0) ; xmm2 = (xmm3.x, ..xmm2)

    ; let (current := xmm3) = from
    vmovaps xmm3, xmm0

    ; let (from_dot_normal := r12d) = from.dot(normal)
    DOT_I24F8X4 r12d, xmm0, xmm2

    ; while n_steps != 0 {
    .while_steps:
    test r13d, r13d
    jz .end_while_steps

        ; let ((x, y) := r8) = (current.x as u32, current.y as u32)
        pextrd eax, xmm3, 0
        shr rax, 8
        pextrd r8d, xmm3, 1
        shr r8, 8
        shl rax, 32
        or r8, rax

        ; if perm_shift == 32 { mem::swap(&mut x, &mut y) }
        mov cl, r15b
        rol r8, cl

        ; self.set_pixel(color, (x, y))
        mov rdx, r8
        call Image_set_pixel

        ; let (distance := eax) = current.dot(normal) - from_dot_normal
        DOT_I24F8X4 eax, xmm3, xmm2
        sub eax, r12d

        ; distance *= sign_x * sign_y
        mov edx, r14d
        sar edx, 8
        imul eax, edx
        mov edx, ebx
        sar edx, 8
        imul eax, edx

        ; let (y_increment := eax) = if distance <= 0 { 1 } else { 0 }
        cmp eax, 0
        setle al
        movzx eax, al
        shl eax, 8

        ; y_increment *= sign_y
        mov edx, ebx
        shr edx, 8
        imul eax, edx

        ; current.y += y_increment
        pxor xmm4, xmm4
        pinsrd xmm4, eax, 1
        paddd xmm3, xmm4

        ; current.x += sign_x
        pxor xmm4, xmm4
        pinsrd xmm4, r14d, 0
        paddd xmm3, xmm4

        ; n_steps -= 1
        dec r13d

    ; }
    jmp .while_steps
    .end_while_steps:

    ; let ((x, y) := r8) = (to.x as u32, to.y as u32)
    pextrd eax, xmm1, 0
    shr rax, 8
    pextrd r8d, xmm1, 1
    shr r8, 8
    shl rax, 32
    or r8, rax

    ; if perm_shift == 32 { mem::swap(&mut x, &mut y) }
    mov cl, r15b
    rol r8, cl

    ; self.set_pixel(color, (x, y))
    mov rdx, r8
    call Image_set_pixel

    POP rbx, r15, r14, r13, r12
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
