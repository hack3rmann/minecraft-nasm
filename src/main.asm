section .rodata
    SYSCALL_WRITE                equ 1
    SYSCALL_CLOSE                equ 3
    SYSCALL_SOCKET               equ 41
    SYSCALL_CONNECT              equ 42
    SYSCALL_EXIT                 equ 60

    AF_UNIX                      equ 1
    SOCK_STREAM                  equ 1
    SOCK_CLOEXEC                 equ 0x80000

    EXIT_SUCCESS                 equ 0
    EXIT_FAILURE                 equ 1

    STDOUT                       equ 1

    LF                           equ 10

    abort_error                  db "The process has been aborted", LF, 0
    abort_error.len              equ $-abort_error
    cstring                      db "This is a C-string!!!", LF, 0

    xdg_runtime_dir_template     db "XDG_RUNTIME_DIR", 0
    xdg_runtime_dir_template.len equ $-xdg_runtime_dir_template-1
    wayland_socket_path          db "/run/user/1000/wayland-1", 0

    addr:
        .sun_family              dw AF_UNIX
        .sun_path                db "/run/user/1000/wayland-1"
    addr_len                     equ $-addr

section .bss
    ; static argc: usize
    argc resq 1
    ; static argv: *const *const u8
    argv resq 1
    ; static envp: *const *const u8
    envp resq 1
    ; static display_fd: usize
    display_fd resq 1

section .text

%macro PUTCHAR 1
    push %1

    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, rsp
    mov rdx, 1
    syscall

    pop rax
%endmacro

struc sockaddr_un
    .sun_family resw 1
    .sun_path   resb 126
    .sizeof     equ $-.sun_family
endstruc

; #[nocall]
; #[noreturn]
; pub fn start() -> !
global start
start:
    ; Higher addresses
    ; ┌───────────────────┐
    ; │ ...               │
    ; ├───────────────────┤
    ; │ NULL              │ ← End of environment pointers
    ; ├───────────────────┤
    ; │ ...               │
    ; │ envp[2]           │ ← Environment variable strings  
    ; │ envp[1]           │   (each is "NAME=VALUE")
    ; │ envp[0]           │
    ; ├───────────────────┤
    ; │ argv[argc] = NULL │ ← End of argument pointers  
    ; │ ...               │
    ; │ argv[1]           │ ← Command-line arguments
    ; │ argv[0]           │ ← Program name
    ; ├───────────────────┤
    ; │ argc              │ ← Argument count (integer)
    ; └───────────────────┘
    ; Lower addresses

    ; argc = get_argc_from_stack()
    mov rax, qword [rsp]
    mov qword [argc], rax

    ; argv = get_argv_from_stack()
    lea rax, [rsp+8]
    mov qword [argv], rax

    ; envp = get_envp_from_stack()
    mov rax, qword [argc]
    lea rax, [8*rax+16+rsp]
    mov qword [envp], rax

    ; let (exit_code := rax) = main()
    call main

    ; exit(exit_code)
    mov rdi, rax
    mov rax, SYSCALL_EXIT
    syscall

; fn exit_on_error((code := rax): usize)
exit_on_error:
    ; if code != 0 {
    cmp rax, 0
    jge .end_if

        ; write(STDOUT, abort_error, abort_error.len)
        mov rax, SYSCALL_WRITE
        mov rdi, STDOUT
        mov rsi, abort_error
        mov rdx, abort_error.len
        syscall

        ; exit(EXIT_FAILURE)
        mov rax, SYSCALL_EXIT
        mov rdi, EXIT_FAILURE
        syscall

    ; }
    .end_if:

    ret

; #[fastcall(all)]
; pub fn main() -> i64
global main
main:
    ; display_fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0)
    mov rax, SYSCALL_SOCKET
    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM | SOCK_CLOEXEC
    xor rdx, rdx
    syscall
    call exit_on_error
    mov qword [display_fd], rax

    ; connect(display_fd, &const addr, addr_len)
    mov rax, SYSCALL_CONNECT
    mov rdi, qword [display_fd]
    mov rsi, addr
    mov rdx, addr_len
    syscall
    call exit_on_error

    ; close(fd)
    mov rax, SYSCALL_CLOSE
    mov rdi, qword [display_fd]
    syscall
    call exit_on_error

    ; return EXIT_SUCCESS
    xor rax, rax
    ret

; #[fastcall(rbx, rcx, ax)]
; pub unsafe fn get_env((name: rdi): *const u8, (name_len := rdx): usize) -> *const u8 := rsi
global get_env
get_env:
    ; let (i := rbx) = 0
    xor rbx, rbx

    ; for (envp[i] := rsi) != null {
    .while:
    mov rsi, qword [envp]
    mov rsi, qword [rsi+8*rbx]
    test rsi, rsi
    jz .end_while

        ; let (match_len := rcx) = cstr_match_length(envp[i] := rsi, name := rdi)
        call cstr_match_length

        ; if match_len == name_len {
        cmp rcx, rdx
        jne .end_if

            ; return envp[i][match_len + 1..]
            lea rsi, [rsi+rcx+1]
            ret

        ; }
        .end_if:

        ; i += 1
        inc rbx

    ; }
    jmp .while
    .end_while:

    ; return null
    xor rsi, rsi
    ret

; # Safety
;
; - both `source` and `template` should be non-null
;
; #[fastcall(rcx, ax)]
; unsafe fn cstr_match_length(
;     (source := rsi): *const u8,
;     (template := rdi): *const u8,
; ) -> usize := rcx
cstr_match_length:
    ; let (i := rcx) = 0
    xor rcx, rcx

    ; while source[i] != '\0' && template[i] != '\0' && source[i] == template[i] {
    .while:
    mov ah, byte [rsi+rcx]
    mov al, byte [rdi+rcx]
    test ah, ah
    jz .end_while
    test al, al
    jz .end_while
    cmp ah, al
    jne .end_while

        ; i += 1
        inc rcx

    ; }
    jmp .while
    .end_while:

    ret

; # Safety
;
; - `ptr` should be non-null
;
; #[fastcall(al, rdx)]
; unsafe fn cstr_len((ptr := rsi): *const u8) -> usize := rdx
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

; # Safety
;
; - `ptr` should be non-null
;
; #[fastcall(all)]
; fn print_cstr((ptr := rsi): *const u8)
print_cstr:
    ; let (len := rdx) = cstr_len(ptr)
    call cstr_len

    ; write(STDOUT, ptr, len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    syscall

    ret
