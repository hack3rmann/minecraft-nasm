%include "syscall.s"
%include "error.s"
%include "memory.s"
%include "debug.s"
%include "string.s"
%include "env.s"
%include "wire.s"

section .rodata
    display_error_string          db "wayland error: "
    display_error_string.len      equ $-display_error_string

    xdg_runtime_dir_str           db "XDG_RUNTIME_DIR"
    xdg_runtime_dir_str.len       equ $-xdg_runtime_dir_str
    wayland_display_str           db "WAYLAND_DISPLAY"
    wayland_display_str.len       equ $-wayland_display_str

    xdg_runtime_dir_default_prefix      db "/run/user/"
    xdg_runtime_dir_default_prefix.len  equ $-xdg_runtime_dir_default_prefix
    wayland_display_default             db "wayland-0"
    wayland_display_default.len         equ $-wayland_display_default

    global_fmt      db "RegistryGlobalEvent {{", LF
                    db "    name: {usize},", LF
                    db "    interface: '{str}',", LF
                    db "    version: {usize},", LF
                    db "}}", LF
    global_fmt.len  equ $-global_fmt

    wl_compositor_str.ptr db "wl_compositor"
    wl_compositor_str.len equ $-wl_compositor_str.ptr

struc DisplayError
    .object_id      resd 1
    .code           resd 1
    .message.len    resd 1
    .message        resb 0
    .sizeof         equ $-.object_id
endstruc

struc RegistryGlobalEvent
    .name           resd 1
    .interface.len  resd 1
    .interface      resb 0
    .version        resd 0
    .sizeof         equ $-.name
endstruc

struc RegistryGlobal
    ; name: u32
    .name           resd 1
    ; version: u32
    .version        resd 1
    ; interface: String
    .interface      resb String.sizeof
    .sizeof         equ $-.name
endstruc

section .bss
    ; pub static argc: usize
    global argc
    argc resq 1

    ; pub static argv: *const *const u8
    global argv
    argv resq 1

    ; pub static envp: *const *const u8
    global envp
    envp resq 1

    ; static display_fd: usize
    display_fd resq 1

    ; static stack_align: usize
    stack_align resq 1

    ; static socket_path: String
    socket_path resb String.sizeof

    ; static message: [u32; 512]
    message resd 512

    ; static format_buffer: String
    format_buffer resb String.sizeof

    addr:
        .sun_family resw 1
        .sun_path   resb 254
    addr_max_len    equ $-addr

    ; static wl_compositor_global: RegistryGlobal
    wl_compositor_global resb RegistryGlobal.sizeof

    wl_compositor_global_args resq 4

section .text

; fn RegistryGlobal::new(($ret := rdi): *mut Self) -> Self
RegistryGlobal_new:
    ; $ret->name = 0
    mov dword [rdi + RegistryGlobal.name], 0

    ; $ret->version = 0
    mov dword [rdi + RegistryGlobal.version], 0

    ; $ret->interface = String::new()
    lea rdi, [rdi + RegistryGlobal.interface]
    call String_new

    ret

; fn RegistryGlobal::drop(&mut self := rdi)
RegistryGlobal_drop:
    push r12

    ; let (self := r12) = self
    mov r12, rdi

    ; drop(self.interface)
    lea rdi, [r12 + RegistryGlobal.interface]
    call String_drop

    ; *self = RegistryGlobal::new()
    mov rdi, r12
    call RegistryGlobal_new

    pop r12
    ret

; #[systemv]
; fn main() -> i64
main:
    ; format_buffer = String::new()
    mov rdi, format_buffer
    call String_new

    ; wl_compositor_global = RegistryGlobal::new()
    mov rdi, wl_compositor_global
    call RegistryGlobal_new

    ; socket_path = get_wayland_socket_path()
    mov rdi, socket_path
    call get_wayland_socket_path

    ; addr.sun_family = AF_UNIX
    mov word [addr.sun_family], AF_UNIX

    ; assert socket_path.len <= addr_max_len - 2
    cmp qword [socket_path + String.len], addr_max_len - 2
    ja abort

    ; copy(socket_path.ptr, &addr.sun_path, socket_path.len)
    mov rdi, qword [socket_path + String.ptr]
    mov rsi, addr.sun_path
    mov rdx, qword [socket_path + String.len]
    call copy

    ; display_fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0)
    mov rax, SYSCALL_SOCKET
    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM | SOCK_CLOEXEC
    xor rdx, rdx
    syscall
    call exit_on_error
    mov qword [display_fd], rax

    ; connect(display_fd, &const addr, 2 + socket_path.len)
    mov rax, SYSCALL_CONNECT
    mov rdi, qword [display_fd]
    mov rsi, addr
    mov rdx, qword [socket_path + String.len]
    add rdx, 2
    syscall
    call exit_on_error

    ; message.object_id = wire_id.wl_display
    mov dword [message + WireMessage.object_id], wire_id.wl_display

    ; message.opcode = wire_request.get_registry_opcode
    mov word [message + WireMessage.opcode], wire_request.display_get_registry_opcode

    ; message.size = WireMessage::HEADER_SIZE + 4
    .message_size equ WireMessage.HEADER_SIZE + 4
    mov word [message + WireMessage.size], .message_size

    ; message.body.id = wire_id.wl_registry
    mov dword [message + WireMessage.body + 0], wire_id.wl_registry

    ; let (n_bytes := rax) = write(display_fd, &message, message.size)
    mov rax, SYSCALL_WRITE
    mov rdi, qword [display_fd]
    mov rsi, message
    mov rdx, .message_size
    syscall
    call exit_on_error

    ; assert n_bytes == message.size
    cmp rax, .message_size
    jne abort

    ; send_sync()
    call send_sync

    ; loop {
    .loop:
        ; read_event()
        call read_event

        ; let (event_size := rdi) = message.size
        movzx rdi, word [message + WireMessage.size]

        ; let (object_id := rdi) = message.object_id
        xor rdi, rdi
        mov edi, dword [message + WireMessage.object_id]

        ; let (opcode := rsi) = message.opcode
        movzx rsi, word [message + WireMessage.opcode]

        ; let (event_id := rdi) = (object_id << 16) | opcode
        shl rdi, 16
        or rdi, rsi

        ; // Got wl_display.error
        ; if event_id == (wire_id.wl_display << 16) | wire_event.display_error_opcode
        ; { handle_display_error() }
        cmp rdi, (wire_id.wl_display << 16) | wire_event.display_error_opcode
        je handle_display_error

        ; // Got wl_registry.global
        ; if event_id == (wire_id.wl_registry << 16) | wire_event.registry_global_opcode {
        cmp rdi, (wire_id.wl_registry << 16) | wire_event.registry_global_opcode
        jne .end_if

            ; handle_registry_global()
            call handle_registry_global

        ; }
        .end_if:

        ; // Got wl_callback.done
        ; if event_id == (wire_id.wl_callback << 16) | wire_event.callback_done_opcode
        ; { break }
        cmp rdi, (wire_id.wl_callback << 16) | wire_event.callback_done_opcode
        je .end_loop

    ; }
    jmp .loop
    .end_loop:

    ; wl_compositor_global_args.name = wl_compositor_global.name as usize
    xor rax, rax
    mov eax, dword [wl_compositor_global + RegistryGlobal.name]
    mov qword [wl_compositor_global_args + 0], rax

    ; wl_compositor_global_args.interface = wl_compositor_global.interface
    mov rax, qword [wl_compositor_global + RegistryGlobal.interface + Str.len]
    mov qword [wl_compositor_global_args + 8], rax
    mov rax, qword [wl_compositor_global + RegistryGlobal.interface + Str.ptr]
    mov qword [wl_compositor_global_args + 16], rax

    ; wl_compositor_global_args.version = wl_compositor_global.version as usize
    xor rax, rax
    mov eax, dword [wl_compositor_global + RegistryGlobal.version]
    mov qword [wl_compositor_global_args + 24], rax

    ; format_buffer.clear()
    mov rdi, format_buffer
    call String_clear

    ; format_buffer.format_array(global_fmt, &wl_compositor_global_args)
    mov rdi, format_buffer
    mov rsi, global_fmt.len
    mov rdx, global_fmt
    mov rcx, wl_compositor_global_args
    call String_format_array

    ; write(STDOUT, format_buffer.ptr, format_buffer.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, qword [format_buffer + String.ptr]
    mov rdx, qword [format_buffer + String.len]
    syscall
    call exit_on_error

    ; close(fd)
    mov rax, SYSCALL_CLOSE
    mov rdi, qword [display_fd]
    syscall
    call exit_on_error

    ; drop(socket_path)
    mov rdi, socket_path
    call String_drop

    ; drop(wl_compositor_global)
    mov rdi, wl_compositor_global
    call RegistryGlobal_drop

    ; drop(format_buffer)
    mov rdi, format_buffer
    call String_drop

    ; return EXIT_SUCCESS
    xor rax, rax
    ret

; #[systemv]
; fn get_wayland_socket_path(($ret := rdi): *mut String) -> String
get_wayland_socket_path:
    push r12
    push r13
    push r14

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

    pop r14
    pop r13
    pop r12
    ret

; #[systemv]
; fn handle_registry_global()
handle_registry_global:
    push r12
    push r13
    push rbp
    mov rbp, rsp

    struc GlobalFmtArgs
        ; name: usize
        .name               resq 1
        ; interface: Str
        .interface          resb Str.sizeof
        ; version: usize
        .version            resq 1
        .sizeof             equ $-.name
    endstruc

    .fmt_args       equ -GlobalFmtArgs.sizeof
    .stack_size     equ ALIGNED(-.fmt_args)

    ; let fmt_args: struct {
    ;     name: usize,
    ;     interface: Str,
    ;     version: usize,
    ; }
    sub rsp, .stack_size

    ; fmt_args.name = message.body.name
    xor rax, rax
    mov eax, dword [message + WireMessage.body + RegistryGlobalEvent.name]
    mov qword [rbp + .fmt_args + GlobalFmtArgs.name], rax

    ; fmt_args.interface.len = message.body.interface.len - 1
    xor rax, rax
    mov eax, dword [message + WireMessage.body + RegistryGlobalEvent.interface.len]
    dec rax
    mov qword [rbp + .fmt_args + GlobalFmtArgs.interface + Str.len], rax

    ; let (interface_len := r8) = fmt_args.interface.len - 1
    mov r8, rax

    ; fmt_args.interface.ptr = &message.body.interface
    mov qword [rbp + .fmt_args + GlobalFmtArgs.interface + Str.ptr], \
        message + WireMessage.body + RegistryGlobalEvent.interface

    ; let (string_block_size := r8) = (interface_len + 3) / 4
    add r8, 3
    shr r8, 2

    ; fmt_args.version = message.body.version
    xor rax, rax
    mov eax, dword [message + WireMessage.body + RegistryGlobalEvent.sizeof + 4*r8]
    mov qword [rbp + .fmt_args + GlobalFmtArgs.version], rax

    ; let (interface_name := r12:r13) = fmt_args.interface
    mov r12, qword [rbp + .fmt_args + GlobalFmtArgs.interface + Str.len]
    mov r13, qword [rbp + .fmt_args + GlobalFmtArgs.interface + Str.ptr]

    ; if interface_name == "wl_compositor" {
    mov rdi, r12
    mov rsi, r13
    mov rdx, wl_compositor_str.len
    mov rcx, wl_compositor_str.ptr
    call Str_eq
    test al, al
    movzx rax, al
    jz .end_if_name

        ; wl_compositor_global.name = fmt_args.name as u32
        mov rax, qword [rbp + .fmt_args + GlobalFmtArgs.name]
        mov dword [wl_compositor_global + RegistryGlobal.name], eax

        ; wl_compositor_global.interface.push_str(fmt_args.interface)
        mov rdi, wl_compositor_global + RegistryGlobal.interface
        mov rsi, r12
        mov rdx, r13
        call String_push_str

        ; wl_compositor_global.version = fmt_args.version as u32
        mov rax, qword [rbp + .fmt_args + GlobalFmtArgs.version]
        mov dword [wl_compositor_global + RegistryGlobal.version], eax

    ; }
    .end_if_name:

    add rsp, .stack_size

    pop rbp
    pop r13
    pop r12
    ret

; #[jumpable]
; #[noreturn]
; fn handle_display_error()
handle_display_error:
    ; write(STDOUT, display_error_string, display_error_string.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, display_error_string
    mov rdx, display_error_string.len
    syscall

    ; let (error_message := rsi) = &message.body.message
    mov rsi, message + WireMessage.body + DisplayError.message

    ; let (error_message_len := rdx) = message.body.message.len
    xor rdx, rdx
    mov edx, dword [message + WireMessage.body + DisplayError.message.len]

    ; write(STDOUT, error_message, error_message_len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    ; mov rsi, rsi
    ; mov rdx, rdx
    syscall

    ; write(STDOUT, &newline, 1)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, newline
    mov rdx, 1
    syscall

    ; abort()
    jmp abort

; #[systemv]
; fn read_event()
read_event:
    ; let (n_read := rax) = read(display_fd, &message, WireMessage::HEADER_SIZE)
    mov rax, SYSCALL_READ
    mov rdi, qword [display_fd]
    mov rsi, message
    mov rdx, WireMessage.HEADER_SIZE
    syscall
    call exit_on_error

    ; assert n_read == WireMessage::HEADER_SIZE
    cmp rax, WireMessage.HEADER_SIZE
    jne abort

    ; let (body_size := rdx) = message.size
    movzx rdx, word [message + WireMessage.size]

    ; body_size -= WireMessage::HEADER_SIZE
    sub rdx, WireMessage.HEADER_SIZE

    ; let (n_read := rax) = read(display_fd, &message + WireMessage::HEADER_SIZE, body_size)
    mov rax, SYSCALL_READ
    mov rdi, qword [display_fd]
    mov rsi, message + WireMessage.HEADER_SIZE
    ; mov rdx, rdx
    syscall
    call exit_on_error

    ; assert n_read == body_size
    cmp rax, rdx
    jne abort

    ret

; #[systemv]
; fn send_sync()
send_sync:
    ; message.object_id = wire_id.wl_display
    mov dword [message + WireMessage.object_id], wire_id.wl_display

    ; message.opcode = wire_request.display_sync
    mov word [message + WireMessage.opcode], wire_request.display_sync_opcode

    ; message.size = WireMessage::HEADER_SIZE + 4
    .message_size equ WireMessage.HEADER_SIZE + 4
    mov word [message + WireMessage.size], .message_size

    ; message.body.id = wire_id.wl_callback
    mov dword [message + WireMessage.body + 0], wire_id.wl_callback

    ; let (n_bytes := rax) = write(display_fd, &message, message.size)
    mov rax, SYSCALL_WRITE
    mov rdi, qword [display_fd]
    mov rsi, message
    mov rdx, .message_size
    syscall
    call exit_on_error

    ; assert n_bytes == message.size
    cmp rax, .message_size
    jne abort

    ret

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

    ; exit(exit_code)
    mov rdi, rax
    mov rax, SYSCALL_EXIT
    syscall
