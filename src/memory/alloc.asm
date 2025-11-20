%include "../memory.inc.asm"
%include "../syscall.inc.asm"
%include "../error.inc.asm"

section .text

; #[fastcall(rax, rcx, r11, rdi, rdx, r10, r8, r9)]
; unsafe fn alloc((size := rsi): usize) -> *mut () := rax
alloc:
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

; #[fastcall(rax, rcx, r11, rdi, rsi)]
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
