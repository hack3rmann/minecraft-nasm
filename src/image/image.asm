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
    ; let (dir := xmm3) = to - from
    vpsubd xmm3, xmm1, xmm0

    ; dir.x := r8d
    pextrd r8d, xmm3, 0

    ; dir.y := eax
    pextrd eax, xmm3, 1

    ; let (sign := r9d) = i32::sign(dir.y * dir.x)
    mov r9d, eax
    xor r9d, r8d
    sar r9d, 31

    ; let (signed_half := r10d) = if sign == 0 {
    ;     i24f8::new(0, 128)
    ; } else { -i24f8::new(0, 128) }
    mov r10d, U24F8(0, 128)
    mov r11d, -U24F8(0, 128)
    test r9d, r9d
    cmovnz r10d, r11d

    ; let (abs_dir := xmm2) = dir.abs()
    pabsd xmm2, xmm3

    ; let (step := xmm2, n_steps := r9d) = if abs_dir.y < abs_dir.x {
    pextrd r8d, xmm2, 0
    pextrd eax, xmm2, 1
    cmp eax, r8d
    jge .else_if_step

        ; dir.x := r8d
        pextrd r8d, xmm3, 0

        ; abs_dir.x := ecx
        pextrd ecx, xmm2, 0

        ; dir.y := eax
        pextrd eax, xmm3, 1

        ; if dir.x != 0 {
        test r8d, r8d
        jz .else_if_dirx

            ; let (slope := eax) = dir.y / abs_dir.x
            movsx rcx, ecx
            add eax, r10d
            movsx rax, eax
            sal rax, 8
            mov rdx, rax
            sar rdx, 63
            idiv rcx

            ; let (sign_x := r9d) = dir.x.sign() as u24f8
            mov r9d, r8d
            sar r9d, 31
            sal r9d, 9
            add r9d, U24F8(1, 0)

            ; let (step := xmm2) = u24f8x4::new(sign_x, slope, 0, 0)
            pxor xmm2, xmm2
            pinsrd xmm2, r9d, 0
            pinsrd xmm2, eax, 1

        ; } else {
        jmp .endif_if_dirx
        .else_if_dirx:

            ; let (step := xmm2) = u24f8x4::new(0, dir.y, 0, 0)
            pxor xmm2, xmm2
            pinsrd xmm2, eax, 1

        ; }
        .endif_if_dirx:

        ; let (n_steps := r9d) = (to - from).abs().x.round_up() as u32
        vpsubd xmm4, xmm1, xmm0
        pabsd xmm4, xmm4
        pextrd r9d, xmm4, 0
        add r9d, U24F8(0, 255)
        shr r9d, 8

    ; } else {
    jmp .end_if_step
    .else_if_step:

        ; dir.x := r8d
        pextrd r8d, xmm3, 0

        ; dir.y := eax
        pextrd eax, xmm3, 1

        ; abs_dir.y := ecx
        pextrd ecx, xmm2, 1

        ; if dir.y != 0 {
        test eax, eax
        jz .else_if_diry

            ; let (slope := eax) = dir.x / abs_dir.y
            mov eax, r8d
            movsx rcx, ecx
            add eax, r10d
            movsx rax, eax
            sal rax, 8
            mov rdx, rax
            sar rdx, 63
            idiv rcx

            ; let (sign_y := r9d) = dir.y.sign() as u24f8
            mov r9d, eax
            sar r9d, 31
            sal r9d, 9
            add r9d, U24F8(1, 0)

            ; let (step := xmm2) = u24f8x4::new(slope, sign_y, 0, 0)
            pxor xmm2, xmm2
            pinsrd xmm2, eax, 0
            pinsrd xmm2, r9d, 1

        ; } else {
        jmp .endif_if_diry
        .else_if_diry:

            ; let (step := xmm2) = u24f8x4::new(dir.x, 0, 0, 0)
            pxor xmm2, xmm2
            pinsrd xmm2, r8d, 0

        ; }
        .endif_if_diry:

        ; let (n_steps := r9d) = (to - from).abs().y.round_up() as u32
        vpsubd xmm4, xmm1, xmm0
        pabsd xmm4, xmm4
        pextrd r9d, xmm4, 1
        add r9d, U24F8(0, 255)
        shr r9d, 8

    ; }
    .end_if_step:

    ; while n_steps != 0 {
    .while:
    test r9d, r9d
    jz .end_while

        ; let ((x, y) := r8) = (from.x as u32, from.y as u32)
        pextrd eax, xmm0, 0
        shr rax, 8
        pextrd r8d, xmm0, 1
        shr r8, 8
        shl rax, 32
        or r8, rax

        ; self.set_pixel(color, (x, y))
        mov rdx, r8
        call Image_set_pixel

        ; from += step
        paddd xmm0, xmm2

        ; n_steps -= 1
        dec r9d

    ; }
    jmp .while
    .end_while:

    ; let ((x, y) := r8) = (to.x as u32, to.y as u32)
    pextrd eax, xmm1, 0
    shr rax, 8
    pextrd r8d, xmm1, 1
    shr r8, 8
    shl rax, 32
    or r8, rax

    ; self.set_pixel(color, (x, y))
    mov rdx, r8
    call Image_set_pixel

    ret

; #[systemv]
; fn Image::draw_line_better(
;     &mut self := rdi,
;     (color := esi): Color,
;     (from := xmm0): i24f8x4,
;     (to := xmm1): i24f8x4,
; )
Image_draw_line_better:
    PUSH r12

    ; let (delta := xmm2) = to - from
    vpsubd xmm2, xmm1, xmm0

    ; let (normal := xmm2) = i24f8x4::new(-delta.y, delta.x, ..delta)
    pshufd xmm2, xmm2, 0b11100001     ; (x, y, z, w) |-> (y, x, z, w)
    pxor xmm3, xmm3
    vpsubd xmm3, xmm3, xmm2           ; xmm3 = -(y, x, z, w)
    vpblendd xmm2, xmm3, 0b0001       ; xmm2 = (xmm3.x, ..xmm2)

    ; let (current := xmm3) = from.floor() + i24f8x4::splat(i24f8::new(0, 128))
    mov eax, 0xFFFFFF00
    vmovd xmm3, eax
    vpbroadcastd xmm3, xmm3
    pand xmm3, xmm0
    mov eax, U24F8(0, 128)
    vmovd xmm4, eax
    vpbroadcastd xmm4, xmm4
    vpor xmm4, xmm3, xmm4
    vpblendd xmm3, xmm4, 0b0011

    ; let (current := xmm3) = from
    vmovaps xmm3, xmm0

    ; let (from_dot_normal := r12d) = from.dot(normal)
    vpslld xmm14, xmm0, 16       ; (from_lo_x16 := xmm14) = from << 16
    psrld xmm14, 16              ; (from_lo := xmm14) = from_lo_x16 >> 16
    vpslld xmm13, xmm2, 16       ; (normal_lo_x16 := xmm13) = normal << 16
    psrld xmm13, 16              ; (normal_lo := xmm13) = normal_lo_x16 >> 16
    vpsrld xmm12, xmm0, 16       ; (from_hi := xmm12) = from >> 16
    vpsrld xmm11, xmm2, 16       ; (normal_hi := xmm11) = normal >> 16
    vpmulld xmm10, xmm12, xmm11  ; (hi_mul_hi := xmm10) = from_hi * normal_hi
    pslld xmm10, 24              ; (hi_mul_hi_shl := xmm10) = hi_mul_hi << 24
    pmulld xmm12, xmm13          ; (hi_mul_lo := xmm12) = from_hi * normal_lo
    pmulld xmm11, xmm14          ; (lo_mul_hi := xmm11) = from_lo * normal_hi
    paddd xmm11, xmm12           ; (mixed_mul := xmm11) = hi_mul_lo + lo_mul_hi
    pslld xmm11, 8               ; (mixed_mul_shl := xmm11) = mixed_mul << 8
    paddd xmm10, xmm11           ; (hi_mid_sum := xmm10) = hi_mul_hi_shl + mixed_mul_shl
    pmulld xmm14, xmm13          ; (lo_mul_lo := xmm14) = from_lo * normal_lo
    psrld xmm14, 8               ; (lo_mul_lo_shr := xmm14) = lo_mul_lo >> 8
    paddd xmm10, xmm14           ; (result := xmm10) = mixed_mul_shl + lo_mul_lo_shr
    vphaddd xmm10, xmm10, xmm10
    vphaddd xmm10, xmm10, xmm10
    vmovd r12d, xmm10

    ; loop {
    %assign COUNT 1024
    %assign i COUNT
    %rep COUNT

        ; let ((x, y) := r8) = (current.x as u32, current.y as u32)
        pextrd eax, xmm3, 0
        shr rax, 8
        pextrd r8d, xmm3, 1
        shr r8, 8
        shl rax, 32
        or r8, rax

        ; self.set_pixel(color, (x, y))
        mov rdx, r8
        call Image_set_pixel

        ; let (distance := eax) = current.dot(normal) - from_dot_normal
        vpslld xmm14, xmm3, 16       ; (current_lo_x16 := xmm14) = current << 16
        psrld xmm14, 16              ; (current_lo := xmm14) = current_lo_x16 >> 16
        vpslld xmm13, xmm2, 16       ; (normal_lo_x16 := xmm13) = normal << 16
        psrld xmm13, 16              ; (normal_lo := xmm13) = normal_lo_x16 >> 16
        vpsrld xmm12, xmm3, 16       ; (current_hi := xmm12) = current >> 16
        vpsrld xmm11, xmm2, 16       ; (normal_hi := xmm11) = normal >> 16
        vpmulld xmm10, xmm12, xmm11  ; (hi_mul_hi := xmm10) = current_hi * normal_hi
        pslld xmm10, 24              ; (hi_mul_hi_shl := xmm10) = hi_mul_hi << 24
        pmulld xmm12, xmm13          ; (hi_mul_lo := xmm12) = current_hi * normal_lo
        pmulld xmm11, xmm14          ; (lo_mul_hi := xmm11) = current_lo * normal_hi
        paddd xmm11, xmm12           ; (mixed_mul := xmm11) = hi_mul_lo + lo_mul_hi
        pslld xmm11, 8               ; (mixed_mul_shl := xmm11) = mixed_mul << 8
        paddd xmm10, xmm11           ; (hi_mid_sum := xmm10) = hi_mul_hi_shl + mixed_mul_shl
        pmulld xmm14, xmm13          ; (lo_mul_lo := xmm14) = current_lo * normal_lo
        psrld xmm14, 8               ; (lo_mul_lo_shr := xmm14) = lo_mul_lo >> 8
        paddd xmm10, xmm14           ; (result := xmm10) = mixed_mul_shl + lo_mul_lo_shr
        vphaddd xmm10, xmm10, xmm10
        vphaddd xmm10, xmm10, xmm10
        vmovd eax, xmm10
        sub eax, r12d

        ; let (y_increment := eax) = if distance < 0 { 1 } else { 0 }
        cmp eax, 0
        setl al
        movzx eax, al
        shl eax, 8

        ; current.y += y_increment
        pxor xmm4, xmm4
        pinsrd xmm4, eax, 1
        paddd xmm3, xmm4

        ; current.x += 1
        mov eax, U24F8(1, 0)
        pxor xmm4, xmm4
        pinsrd xmm4, eax, 0
        paddd xmm3, xmm4

    ; }
    %assign i i+1
    %endrep

    ; let ((x, y) := r8) = (to.x as u32, to.y as u32)
    pextrd eax, xmm1, 0
    shr rax, 8
    pextrd r8d, xmm1, 1
    shr r8, 8
    shl rax, 32
    or r8, rax

    ; self.set_pixel(color, (x, y))
    mov rdx, r8
    call Image_set_pixel

    .exit:
    POP r12
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
