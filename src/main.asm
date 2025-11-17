section .rodata
    SYSCALL_WRITE   equ 1
    SYSCALL_EXIT    equ 60

    EXIT_SUCCESS    equ 0
    EXIT_FAILURE    equ 1

    STDOUT          equ 1

    LF              equ 10

    hello_world     db "Hello, World!", LF
    hello_world.len equ $-hello_world
    cstring         db "This is a C-string!!!", LF, 0

section .bss
    argc resq 1
    argc_string resb 16

section .text

; #[fastcall(al, rdx)]
; fn cstr_len((ptr := rsi): *const u8) -> usize := rdx
cstr_len:
    ; let (result := rdx) = 0
    xor rdx, rdx

    ; while *(ptr + result) != null {
    .while:
    mov al, byte [rsi+rdx]
    test al, al
    jz .end_while

        ; result += 1
        inc rdx

    ; }
    jmp .while
    .end_while:

    ret

; #[fastcall]
; fn print_cstr((ptr := rsi): *const u8)
print_cstr:
    ; let (len := rdx) = cstr_len(ptr)
    call cstr_len

    ; write(STDOUT, ptr, len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    syscall

    ret

; #[fastcall]
; #[noreturn]
; fn start() -> !
global start
start:
    ; argc = get_argc_from_stack()
    mov rax, qword [rsp]
    mov qword [argc], rax

    ; let (exit_code := rax) = main()
    call main

    ; exit(exit_code)
    mov rdi, rax
    mov rax, SYSCALL_EXIT
    syscall

; #[fastcall]
; fn main() -> i32
global main
main:
    ; print_cstr(cstring)
    mov rsi, cstring
    call print_cstr

    ; return EXIT_SUCCESS
    xor rax, rax
    ret
