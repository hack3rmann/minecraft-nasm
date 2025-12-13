%define SYSCALL_READ   0
%define SYSCALL_WRITE  1
%define SYSCALL_MMAP   9
%define SYSCALL_MUNMAP 11
%define SYSCALL_GETPID 39
%define SYSCALL_EXIT   60
%define SYSCALL_KILL   62

%define PROT_READ      1
%define PROT_WRITE     2
%define MAP_ANONYMOUS  0x0020
%define MAP_FAILED     0xFFFFFFFFFFFFFFFF
%define MAP_PRIVATE    0x0002
%define MMAP_PAGE_SIZE 4096

%define SIGABRT        6

%define EXIT_FAILURE   1

%define STDIN          0
%define STDOUT         1
%define STDERR         2

%define LF 10

%define READ_LEN       4096

struc StringBuffer
    .len          resq 1
                  resb 32-8 ; padding
    .data         resb READ_LEN
    .sizeof       equ $-.len
    .alignof      equ 32
endstruc

struc String
    .len          resq 1
    .ptr          resq 1
    .cap          resq 1
    .sizeof       equ $-.len
    .alignof      equ 8
endstruc

section .rodata
    hello_world.ptr   db "Hello, World!", LF
    hello_world.len   equ $-hello_world.ptr

section .data
    argc        dq 0
    argv        dq 0
    stack_align dq 0

    align StringBuffer.alignof
    stdin_buffer      times StringBuffer.sizeof db 0

    align StringBuffer.alignof
    line              times StringBuffer.sizeof db 0

section .text

; #[systemv]
; #[noreturn]
; #[jumpable]
; fn abort() -> !
abort:
    ; let (pid := rax) = getpid()
    mov rax, SYSCALL_GETPID
    syscall

    ; kill(pid, SIGABRT)
    mov rdi, rax
    mov rax, SYSCALL_KILL
    mov rsi, SIGABRT
    syscall

    ; // do exit in case if SIGABRT have been handled
    ; exit(EXIT_FAILURE)
    mov rax, SYSCALL_EXIT
    mov rdi, EXIT_FAILURE
    syscall

    ; // loop forever just in case
    .loop:
    jmp .loop

; #[syscall]
; fn StringBuffer::fill_from(&mut self := rdi, (fd := esi): Fd) -> ErrorCode := rax
StringBuffer_fill_from:
    push r12
    push r13

    ; let (self := r12) = self
    mov r12, rdi

    ; let (fd := r13d) = esi
    mov r13d, esi

    ; let (n_bytes := rax) = read(fd, &self.data, READ_LEN)
    mov rax, SYSCALL_READ
    mov edi, r13d
    lea rsi, [r12 + StringBuffer.data]
    mov rdx, READ_LEN
    syscall

    ; if n_bytes < 0 { return n_bytes }
    cmp rax, 0
    jl .exit

    ; if n_bytes > READ_LEN { return n_bytes }
    cmp rax, READ_LEN
    jg .exit

    ; self.len = n_bytes
    mov qword [r12 + StringBuffer.len], rax

    ; return 0
    xor rax, rax

    .exit:
    pop r13
    pop r12
    ret

; #[systemv]
; fn StringBuffer::read_line_from(&mut self := rdi, (from := rsi:rdx): Str)
StringBuffer_read_line_from:
    push r12
    push r13
    push r14

    ; let (self := r12) = self
    mov r12, rdi

    ; let (from := r13:r14) = from
    mov r13, rsi
    mov r14, rdx

    ; let (index := rcx) = 0
    xor rcx, rcx

    ; while index < READ_LEN && index < from.len {
    .while:
    cmp rcx, READ_LEN
    jae .end_while
    cmp rcx, r13
    jae .end_while

        ; let (cur := al) = from.ptr[index]
        mov al, byte [r14 + rcx]

        ; if cur == '\n' { break }
        cmp al, LF
        je .end_while

        ; self.data[index] = cur
        mov byte [r12 + StringBuffer.data + rcx], al

        ; index += 1
        inc rcx

    ; }
    jmp .while
    .end_while:

    ; self.len = index
    mov qword [r12 + StringBuffer.len], rcx

    pop r14
    pop r13
    pop r12
    ret

; #[fastcall]
; fn StringBuffer::clear(&mut self := rdi)
StringBuffer_clear:
    mov qword [rdi + StringBuffer.len], 0
    ret

; #[fastcall(rcx, al)]
; fn StringBuffer::push_str(&mut self := rdi, (src := rsi:rdx): Str)
StringBuffer_push_str:
    ; for (i := rcx) in 0..src.len {
    xor rcx, rcx
    .for:
    cmp rcx, rsi
    jae .end_for

        ; if i >= READ_LEN { break }
        cmp rcx, READ_LEN
        jae .end_for

        ; self.data[i] = src.ptr[i]
        mov al, byte [rdx + rcx]
        mov byte [rdi + StringBuffer.data + rcx], al

    ; }
    inc rcx
    jmp .for
    .end_for:

    ; self.len = i
    mov qword [rdi + StringBuffer.len], rcx

    ret

; #[systemv]
; fn main() -> i64 := rax
main:
    ; let (error := rax) = stdin_buffer.fill_from(STDIN)
    mov rdi, stdin_buffer
    mov esi, STDIN
    call StringBuffer_fill_from

    ; assert error == 0
    test rax, rax
    jnz abort

    ; loop {
    .loop:

        ; line.read_line_from(stdin_buffer.as_str())
        mov rdi, line
        mov rsi, qword [stdin_buffer + StringBuffer.len]
        mov rdx, stdin_buffer + StringBuffer.data
        call StringBuffer_read_line_from

        ; write(STDOUT, &line.data, line.len)
        mov rax, SYSCALL_WRITE
        mov rdi, STDOUT
        mov rsi, line + StringBuffer.data
        mov rdx, qword [line + StringBuffer.len]
        syscall

    ; }
    jmp .loop

    ; return 0
    xor rax, rax

    ret

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
    jnz abort

    .exit:
    ret

; #[systemv]
; unsafe fn realloc((ptr := rdi): *mut (), (size := rsi): usize) -> *mut () := rax
realloc:
    push r12
    push r13
    push r14

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
    cmovb rdx, rax

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
    pop r14
    pop r13
    pop r12
    ret

; #[fastcall(rdi, rsi, rdx, al)]
; fn copy((source := rdi): *mut u8, (dest := rsi): *mut u8, (size := rdx): usize)
copy:
    ; while (size as isize) >= 0 {
    .while:
    cmp rdx, 0
    jl .end_while

        ; *dest = *source
        mov al, byte [rdi]
        mov byte [rsi], al

        ; dest += 1
        inc rsi

        ; source += 1
        inc rdi

        ; size -= 1
        dec rdx

    ; }
    jmp .while
    .end_while:

    ret

global start
start:
    ; argc = get_argc_from_stack()
    mov rax, qword [rsp]
    mov qword [argc], rax

    ; argv = get_argv_from_stack()
    lea rax, [rsp + 8]
    mov qword [argv], rax

    ; let stack_align = rsp % 16
    mov rax, rsp
    and rax, 0xF
    mov qword [stack_align], rax

    ; align(16) stack before `main()`
    sub rsp, rax

    ; let (exit_code := rax) = main()
    call main

    ; unalign the stack
    add rsp, qword [stack_align]

    ; exit(0)
    mov rax, SYSCALL_EXIT
    xor rdi, rdi
    syscall
