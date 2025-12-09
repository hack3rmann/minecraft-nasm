%include "../syscall.s"
%include "../string.s"
%include "../wire.s"
%include "../debug.s"
%include "../env.s"
%include "../function.s"

section .rodata
    xdg_runtime_dir_str           db "XDG_RUNTIME_DIR"
    xdg_runtime_dir_str.len       equ $-xdg_runtime_dir_str
    wayland_display_str           db "WAYLAND_DISPLAY"
    wayland_display_str.len       equ $-wayland_display_str

    xdg_runtime_dir_default_prefix      db "/run/user/"
    xdg_runtime_dir_default_prefix.len  equ $-xdg_runtime_dir_default_prefix
    wayland_display_default             db "wayland-0"
    wayland_display_default.len         equ $-wayland_display_default

section .text

; #[systemv]
; fn get_wayland_socket_path(($ret := rdi): *mut String) -> String
FN get_wayland_socket_path
    PUSH r12, r13, r14

    ; let ($ret := r12) = $ret
    mov r12, rdi

    ; $ret = String::new()
    mov rdi, r12
    call String_new

    ; let (runtime_dir := r13) = get_env("XDG_RUNTIME_DIR", .len)
    mov rdi, xdg_runtime_dir_str
    mov rdx, xdg_runtime_dir_str.len
    call get_env
    mov r13, rsi

    ; if runtime_dir != null {
    test r13, r13
    jz .runtime_else

        ; let (runtime_dir_len := r14) = cstr_len(runtime_dir)
        mov rsi, r13
        call cstr_len
        mov r14, rdx

        ; $ret.push_str(Str { runtime_dir_len, runtime_dir })
        mov rdi, r12
        mov rsi, r14
        mov rdx, r13
        call String_push_str

    ; } else {
    jmp .runtime_end_if
    .runtime_else:

        ; $ret.push_str(xdg_runtime_dir_default_prefix)
        mov rdi, r12
        mov rsi, xdg_runtime_dir_default_prefix.len
        mov rdx, xdg_runtime_dir_default_prefix
        call String_push_str

        ; let (uid := rax) = getuid()
        mov rax, SYSCALL_GETUID
        syscall

        ; $ret.format_u64(uid)
        mov rdi, r12
        mov rsi, rax
        call String_format_u64

    ; }
    .runtime_end_if:

    ; $ret.push_ascii('/')
    mov rdi, r12
    mov rsi, "/"
    call String_push_ascii

    ; let (wayland_display := r13) = get_env("WAYLAND_DISPLAY", .len)
    mov rdi, wayland_display_str
    mov rdx, wayland_display_str.len
    call get_env
    mov r13, rsi

    ; if wayland_display != null {
    test r13, r13
    jz .display_else

        ; let (wayland_display_len := r14) = cstr_len(wayland_display)
        mov rsi, r13
        call cstr_len
        mov r14, rdx

        ; $ret.push_str(Str { wayland_display_len, wayland_display })
        mov rdi, r12
        mov rsi, r14
        mov rdx, r13
        call String_push_str

    ; } else {
    jmp .display_end_if
    .display_else:

        ; $ret.push_str(wayland_display_default)
        mov rdi, r12
        mov rsi, wayland_display_default.len
        mov rdx, wayland_display_default
        call String_push_str

    ; }
    .display_end_if:
END_FN r14, r13, r12
