section .rodata
    SYSCALL_WRITE                equ 1
    SYSCALL_EXIT                 equ 60

    EXIT_SUCCESS                 equ 0
    EXIT_FAILURE                 equ 1

    STDOUT                       equ 1

    LF                           equ 10

    hello_world                  db "Hello, World!", LF
    hello_world.len              equ $-hello_world
    cstring                      db "This is a C-string!!!", LF, 0

    xdg_runtime_dir_template     db "XDG_RUNTIME_DIR", 0
    xdg_runtime_dir_template.len equ $-xdg_runtime_dir_template-1

section .bss
    ; static argc: usize
    argc resq 1
    ; static argv: *const *const u8
    argv resq 1
    ; static envp: *const *const u8
    envp resq 1

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

; #[fastcall(all)]
; pub fn main() -> i64
global main
main:
    ; let (xdg_runtime_dir := rsi) = get_env("XDG_RUNTIME_DIR", "XDG_RUNTIME_DIR".len)
    mov rdi, xdg_runtime_dir_template
    mov rdx, xdg_runtime_dir_template.len
    call get_env

    ; print_cstr(xdg_runtime_dir)
    call print_cstr

    ; newline()
    PUTCHAR LF

    ; return EXIT_SUCCESS
    xor rax, rax
    ret

; #[fastcall(rbx, rcx, ax, rdx)]
; pub unsafe fn get_env((name: rdi): *const u8, (name_len := rdx): usize) -> *const u8 := rsi
global get_env
get_env:
    ; let (i := rbx) = 0
    xor rbx, rbx

    ; for (envp[i] := rsi) != null, i += 1 {
    sub rbx, 1 ; overflow rbx i bit
    .while:
    inc rbx
    mov rsi, qword [envp]
    mov rsi, qword [rsi+8*rbx]
    test rsi, rsi
    jz .end_while

        ; let (match_len := rcx) = cstr_match_length(envp[i], name)
        call cstr_match_length

        ; if match_len != name_len { continue }
        cmp rcx, rdx
        jne .while

        ; return envp[i][match_len + 1..]
        lea rsi, [rsi+rcx+1]
        ret

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
