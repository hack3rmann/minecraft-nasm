%include "../memory.s"
%include "../syscall.s"
%include "../error.s"

section .text

; #[systemv]
; unsafe fn alloc((size := rdi): usize) -> *mut () := rax
alloc:
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

    ; if result == MAP_FAILED { return null }
    cmp rax, MAP_FAILED
    mov rcx, 0
    cmove rax, rcx
    je .exit

    ; *result.cast::<usize>() = size
    mov qword [rax], rsi

    ; result += 16
    add rax, 16

    ; return result
    .exit:
    ret

; #[systemv]
; unsafe fn dealloc((ptr := rdi): *mut ())
dealloc:
    ; ptr -= 16
    sub rdi, 16

    ; let (size := rsi) = *ptr.cast::<usize>()
    mov rsi, qword [rdi]

    ; let (result := rax) = munmap(ptr, size)
    mov rax, SYSCALL_MUNMAP
    ; mov rdi, rdi
    ; mov rsi, rsi
    syscall

    ; if result != 0 { abort() }
    test rax, rax
    jz .exit
    call abort

    .exit:
    ret
