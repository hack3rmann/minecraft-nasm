%include "../memory.s"
%include "../syscall.s"
%include "../error.s"
%include "../debug.s"
%include "../function.s"
%include "../panic.s"

section .text

; #[systemv]
; unsafe fn alloc((size := rdi): usize) -> *mut () := rax
FN alloc
    ; let (size := rsi) = size
    mov rsi, rdi

    ; // meta info
    ; rsi += 16
    add rsi, 16

    ; let (result := rax): *mut () = mmap(
    ;     addr = null,
    ;     length = size,
    ;     prot = PROT_READ | PROT_WRITE,
    ;     flags = MAP_ANONYMOUS | MAP_PRIVATE,
    ;     fd = -1,
    ;     offset = 0)
    mov rax, SYSCALL_MMAP
    xor rdi, rdi
    ; mov rsi, rsi
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_ANONYMOUS | MAP_PRIVATE
    mov r8, -1
    xor r9, r9
    syscall

    ; if -4095 <= result <= -1 { return null }
    cmp rax, -4095
    setge cl
    cmp rax, -1
    setle ch
    xor rdx, rdx
    test ch, cl
    cmovnz rax, rdx
    jnz .exit

    ; *result.cast::<usize>() = size
    mov qword [rax], rsi

    ; result += 16
    add rax, 16

    ; return result
    .exit:
END_FN

; #[systemv]
; unsafe fn dealloc((ptr := rdi): *mut ())
FN dealloc
    ; if ptr == null { return }
    test rdi, rdi
    jz .exit

    ; ptr -= 16
    sub rdi, 16

    ; let (size := rsi) = *ptr.cast::<usize>()
    mov rsi, qword [rdi]

    ; let (result := rax) = munmap(ptr, size)
    mov rax, SYSCALL_MUNMAP
    ; mov rdi, rdi
    ; mov rsi, rsi
    syscall

    ; assert result == 0
    test rax, rax
    jnz panic

    .exit:
END_FN

; #[systemv]
; unsafe fn realloc((ptr := rdi): *mut (), (size := rsi): usize) -> *mut () := rax
FN realloc
    PUSH r12, r13, r14

    ; let (ptr := r12) = ptr
    mov r12, rdi

    ; let (size := r13) = size
    mov r13, rsi

    ; if size < MMAP_PAGE_SIZE - 16 {
    cmp r13, MMAP_PAGE_SIZE - 16
    jae .end_if

        ; *(ptr - 16).cast::<usize>() = size + 16
        lea rax, [rsi + 16]
        mov qword [r12 - 16], rax

        ; return ptr
        mov rax, r12
        jmp .exit

    ; }
    .end_if:

    ; let (result := r14) = alloc(size)
    mov rdi, r13
    call alloc
    mov r14, rax

    ; let (prev_size := rax) = *(ptr - 16).cast::<usize>()
    mov rax, qword [r12 - 16]

    ; let (copy_size := rdx) = min(size, prev_size)
    cmp r13, rax
    mov rdx, r13
    cmova rdx, rax

    ; copy(ptr, result, copy_size)
    mov rdi, r12
    mov rsi, r14
    ; mov rdx, rdx
    call copy

    ; dealloc(ptr)
    mov rdi, r12
    call dealloc

    ; return result
    mov rax, r14

    .exit:
END_FN r14, r13, r12
