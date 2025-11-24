%include "syscall.s"
%include "error.s"
%include "memory.s"
%include "debug.s"
%include "string.s"
%include "env.s"
%include "wire.s"

section .rodata
    display_error_fmt.ptr         db "wayland error: WlDisplayError {{ ", \
                                     "object_id: {usize}, ", \
                                     "code: {usize}, ", \
                                     "message: '{str}' }}", LF
    display_error_fmt.len         equ $-display_error_fmt.ptr

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

    wl_shm_str.ptr        db "wl_shm"
    wl_shm_str.len        equ $-wl_shm_str.ptr

    dev_shm_path.ptr      db "/dev/shm/minecraft", 0
    dev_shm_path.len      equ $-dev_shm_path.ptr-1

    shm_size              equ 4096

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

    ; static wl_shm_global: RegistryGlobal
    wl_shm_global resb RegistryGlobal.sizeof

    ; static wl_compositor_id: u32
    wl_compositor_id resq 1

    ; static wl_shm_id: u32
    wl_shm_id resq 1

    ; static shm_id: key_t
    shm_id resq 1

    ; static shm_fd: Fd
    shm_fd resq 1

    ; static shm_ptr: *mut u8
    shm_ptr resq 1

    ; static wl_surface_id: u32
    wl_surface_id resq 1

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

    ; wl_shm_global = RegistryGlobal::new()
    mov rdi, wl_shm_global
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

    ; shm_fd = open(dev_shm_path.ptr, O_CREAT | O_RDWR | O_EXCL, 0o600)
    mov rax, SYSCALL_OPEN
    mov rdi, dev_shm_path.ptr
    mov rsi, O_CREAT | O_RDWR | O_EXCL
    mov rdx, 0o600
    syscall
    call exit_on_error
    mov qword [shm_fd], rax

    ; ftruncate(shm_fd, shm_size)
    mov rax, SYSCALL_FTRUNCATE
    mov rdi, qword [shm_fd]
    mov rsi, shm_size
    syscall
    call exit_on_error

    ; unlink(dev_shm_path.ptr)
    mov rax, SYSCALL_UNLINK
    mov rdi, dev_shm_path.ptr
    syscall
    call exit_on_error

    ; shm_ptr = mmap(
    ;     null,
    ;     shm_size,
    ;     PROT_READ | PROT_WRITE,
    ;     MAP_SHARED,
    ;     shm_fd,
    ;     0)
    mov rax, SYSCALL_MMAP
    xor rdi, rdi
    mov rsi, shm_size
    mov rdx, PROT_READ | PROT_WRITE
    mov rcx, MAP_SHARED
    mov r8, qword [shm_fd]
    xor r9, r9
    syscall
    mov qword [shm_ptr], rax

    ; assert shm_ptr != MMAP_FAILED
    cmp qword [shm_ptr], MAP_FAILED
    je abort

    ; assert shm_ptr != null
    cmp qword [shm_ptr], 0
    je abort

    ; _ = wire_send_display_get_registry()
    call wire_send_display_get_registry

    ; let (callback_id := r12) = wire_send_display_sync()
    call wire_send_display_sync
    mov r12, rax

    ; wire_flush(display_fd)
    mov rdi, qword [display_fd]
    call wire_flush

    ; loop {
    .loop:
        ; read_event()
        call read_event

        ; let (event_size := rdi) = message.size
        movzx rdi, word [message + WireMessageHeader.size]

        ; let (object_id := rdi) = message.object_id
        xor rdi, rdi
        mov edi, dword [message + WireMessageHeader.object_id]

        ; let (opcode := rsi) = message.opcode
        movzx rsi, word [message + WireMessageHeader.opcode]

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
        ; if event_id == (callback_id << 16) | wire_event.callback_done_opcode
        ; { break }
        mov rax, r12
        shl rax, 16
        or rax, wire_event.callback_done_opcode
        cmp rdi, rax
        je .end_loop

    ; }
    jmp .loop
    .end_loop:

    ; wl_compositor_id = wire_send_registry_bind_global(&wl_compositor_global)
    mov rdi, wl_compositor_global
    call wire_send_registry_bind_global
    mov qword [wl_compositor_id], rax

    ; wl_shm_id = wire_send_registry_bind_global(&wl_shm_global)
    mov rdi, wl_shm_global
    call wire_send_registry_bind_global
    mov qword [wl_shm_id], rax

    ; let (callback_id := r12) = wire_send_display_sync()
    call wire_send_display_sync
    mov r12, rax

    ; wire_flush(display_fd)
    mov rdi, qword [display_fd]
    call wire_flush

    ; loop {
    .loop2:
        ; read_event()
        call read_event

        ; let (event_size := rdi) = message.size
        movzx rdi, word [message + WireMessageHeader.size]

        ; let (object_id := rdi) = message.object_id
        xor rdi, rdi
        mov edi, dword [message + WireMessageHeader.object_id]

        ; let (opcode := rsi) = message.opcode
        movzx rsi, word [message + WireMessageHeader.opcode]

        ; let (event_id := rdi) = (object_id << 16) | opcode
        shl rdi, 16
        or rdi, rsi

        ; // Got wl_display.error
        ; if event_id == (wire_id.wl_display << 16) | wire_event.display_error_opcode
        ; { handle_display_error() }
        cmp rdi, (wire_id.wl_display << 16) | wire_event.display_error_opcode
        je handle_display_error

        ; // Got wl_callback.done
        ; if event_id == (callback_id << 16) | wire_event.callback_done_opcode
        ; { break }
        mov rax, r12
        shl rax, 16
        or rax, wire_event.callback_done_opcode
        cmp rdi, rax
        je .end_loop2

    ; }
    jmp .loop2
    .end_loop2:

    ; wl_surface_id = wire_send_compositor_create_surface(wl_compositor_id)
    mov rdi, qword [wl_compositor_id]
    call wire_send_compositor_create_surface
    mov qword [wl_surface_id], rax

    ; let (callback_id := r12) = wire_send_display_sync()
    call wire_send_display_sync
    mov r12, rax

    ; wire_flush(display_fd)
    mov rdi, qword [display_fd]
    call wire_flush

    ; loop {
    .loop3:
        ; read_event()
        call read_event

        ; let (event_size := rdi) = message.size
        movzx rdi, word [message + WireMessageHeader.size]

        ; let (object_id := rdi) = message.object_id
        xor rdi, rdi
        mov edi, dword [message + WireMessageHeader.object_id]

        ; let (opcode := rsi) = message.opcode
        movzx rsi, word [message + WireMessageHeader.opcode]

        ; let (event_id := rdi) = (object_id << 16) | opcode
        shl rdi, 16
        or rdi, rsi

        ; // Got wl_display.error
        ; if event_id == (wire_id.wl_display << 16) | wire_event.display_error_opcode
        ; { handle_display_error() }
        cmp rdi, (wire_id.wl_display << 16) | wire_event.display_error_opcode
        je handle_display_error

        ; // Got wl_callback.done
        ; if event_id == (callback_id << 16) | wire_event.callback_done_opcode
        ; { break }
        mov rax, r12
        shl rax, 16
        or rax, wire_event.callback_done_opcode
        cmp rdi, rax
        je .end_loop3

    ; }
    jmp .loop3
    .end_loop3:

    ; munmap(shm_ptr, shm_size)
    mov rax, SYSCALL_MUNMAP
    mov rdi, qword [shm_ptr]
    mov rsi, shm_size
    syscall
    call exit_on_error

    ; close(shm_fd)
    mov rax, SYSCALL_CLOSE
    mov rdi, qword [shm_fd]
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

    ; drop(wl_shm_global)
    mov rdi, wl_shm_global
    call RegistryGlobal_drop

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
    mov eax, dword [message + WireMessageHeader.sizeof + RegistryGlobalEvent.name]
    mov qword [rbp + .fmt_args + GlobalFmtArgs.name], rax

    ; fmt_args.interface.len = message.body.interface.len - 1
    xor rax, rax
    mov eax, dword [message + WireMessageHeader.sizeof + RegistryGlobalEvent.interface.len]
    dec rax
    mov qword [rbp + .fmt_args + GlobalFmtArgs.interface + Str.len], rax

    ; let (interface_len := r8) = fmt_args.interface.len - 1
    mov r8, rax

    ; fmt_args.interface.ptr = &message.body.interface
    mov qword [rbp + .fmt_args + GlobalFmtArgs.interface + Str.ptr], \
        message + WireMessageHeader.sizeof + RegistryGlobalEvent.interface

    ; let (string_block_size := r8) = (interface_len + 3) / 4
    add r8, 3
    shr r8, 2

    ; fmt_args.version = message.body.version
    xor rax, rax
    mov eax, dword [message + WireMessageHeader.sizeof + RegistryGlobalEvent.sizeof + 4*r8]
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
    jz .else_if_name

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

    ; } else if interface_name == "wl_shm" {
    jmp .end_if_name
    .else_if_name:
    mov rdi, r12
    mov rsi, r13
    mov rdx, wl_shm_str.len
    mov rcx, wl_shm_str.ptr
    call Str_eq
    test al, al
    movzx rax, al
    jz .end_if_name

        ; wl_shm_global.name = fmt_args.name as u32
        mov rax, qword [rbp + .fmt_args + GlobalFmtArgs.name]
        mov dword [wl_shm_global + RegistryGlobal.name], eax

        ; wl_shm_global.interface.push_str(fmt_args.interface)
        mov rdi, wl_shm_global + RegistryGlobal.interface
        mov rsi, r12
        mov rdx, r13
        call String_push_str

        ; wl_shm_global.version = fmt_args.version as u32
        mov rax, qword [rbp + .fmt_args + GlobalFmtArgs.version]
        mov dword [wl_shm_global + RegistryGlobal.version], eax

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
    push rbp
    mov rbp, rsp

    .fmt_args       equ -32

    .object_id      equ .fmt_args
    .code           equ .fmt_args + 8
    .message.len    equ .fmt_args + 16
    .message.ptr    equ .fmt_args + 24

    .stack_size     equ ALIGNED(-.fmt_args)

    ; let fmt_args: struct {
    ;     object_id: usize,
    ;     code: usize
    ;     message: Str,
    ; }
    sub rsp, .stack_size

    ; message.ptr = &message.body.message
    mov qword [rbp + .message.ptr], \
        message + WireMessageHeader.sizeof + DisplayErrorEvent.message

    ; message.len = message.body.message.len as usize
    xor rax, rax
    mov eax, dword [message + WireMessageHeader.sizeof + DisplayErrorEvent.message.len]
    mov qword [rbp + .message.len], rax

    ; object_id = message.body.object_id
    xor rax, rax
    mov eax, dword [message + WireMessageHeader.sizeof + DisplayErrorEvent.object_id]
    mov qword [rbp + .object_id], rax

    ; code = message.body.code
    xor rax, rax
    mov eax, dword [message + WireMessageHeader.sizeof + DisplayErrorEvent.code]
    mov qword [rbp + .code], rax

    ; format_buffer.clear()
    mov rdi, format_buffer
    call String_clear

    ; format_buffer.format_array(display_error_fmt, &fmt_args)
    mov rdi, format_buffer
    mov rsi, display_error_fmt.len
    mov rdx, display_error_fmt.ptr
    lea rcx, [rbp + .fmt_args]
    call String_format_array

    ; write(STDOUT, format_buffer.ptr, format_buffer.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, qword [format_buffer + String.ptr]
    mov rdx, qword [format_buffer + String.len]
    syscall
    call exit_on_error

    ; abort()
    jmp abort

; #[systemv]
; fn read_event()
read_event:
    ; let (n_read := rax) = read(display_fd, &message, WireMessageHeader::HEADER_SIZE)
    mov rax, SYSCALL_READ
    mov rdi, qword [display_fd]
    mov rsi, message
    mov rdx, WireMessageHeader.sizeof
    syscall
    call exit_on_error

    ; assert n_read == WireMessageHeader::HEADER_SIZE
    cmp rax, WireMessageHeader.sizeof
    jne abort

    ; let (body_size := rdx) = message.size
    movzx rdx, word [message + WireMessageHeader.size]

    ; body_size -= WireMessageHeader::HEADER_SIZE
    sub rdx, WireMessageHeader.sizeof

    ; let (n_read := rax) = read(display_fd, &message + WireMessageHeader::HEADER_SIZE, body_size)
    mov rax, SYSCALL_READ
    mov rdi, qword [display_fd]
    mov rsi, message + WireMessageHeader.sizeof
    ; mov rdx, rdx
    syscall
    call exit_on_error

    ; assert n_read == body_size
    cmp rax, rdx
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
