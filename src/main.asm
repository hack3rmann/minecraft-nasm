%include "syscall.s"
%include "error.s"
%include "memory.s"
%include "debug.s"
%include "string.s"
%include "env.s"
%include "wire.s"
%include "shm.s"

section .rodata
    minecraft_str.ptr             db "Minecraft"
    minecraft_str.len             equ $-minecraft_str.ptr

    wl_compositor_str.ptr db "wl_compositor"
    wl_compositor_str.len equ $-wl_compositor_str.ptr

    wl_shm_str.ptr        db "wl_shm"
    wl_shm_str.len        equ $-wl_shm_str.ptr

    xdg_wm_base_str.ptr   db "xdg_wm_base"
    xdg_wm_base_str.len   equ $-xdg_wm_base_str.ptr

    window_width          equ 640
    window_height         equ 480
    shm_size              equ 4 * window_width * window_height

section .data
    ; static is_window_open: bool
    is_window_open dq 1

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

    ; static stack_align: usize
    stack_align resq 1

    ; static display_fd: usize
    display_fd resq 1

    ; static socket_path: String
    socket_path resb String.sizeof

    addr:
        .sun_family resw 1
        .sun_path   resb 254
    addr_max_len    equ $-addr

    ; static shm: Shm
    align Shm.alignof
    shm resb Shm.sizeof

section .text

; #[systemv]
; fn main() -> i64
main:
    ; init_format()
    call init_format

    ; wire_init()
    call wire_init

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

    ; connect(display_fd, &addr, 2 + socket_path.len)
    mov rax, SYSCALL_CONNECT
    mov rdi, qword [display_fd]
    mov rsi, addr
    mov rdx, qword [socket_path + String.len]
    add rdx, 2
    syscall
    call exit_on_error

    ; shm = Shm::new(shm_size)
    mov rdi, shm
    mov rsi, shm_size
    call Shm_new

    ; wire_set_dispatcher(
    ;     WlObjectType::Registry,
    ;     wire_event.registry_global_opcode,
    ;     handle_registry_global)
    mov rdi, WL_OBJECT_TYPE_REGISTRY
    mov rsi, wire_event.registry_global_opcode
    mov rdx, handle_registry_global
    call wire_set_dispatcher

    ; wire_set_dispatcher(
    ;     WlObjectType::XdgSurface,
    ;     wire_event.xdg_surface_configure_opcode,
    ;     handle_xdg_surface_configure)
    mov rdi, WL_OBJECT_TYPE_XDG_SURFACE
    mov rsi, wire_event.xdg_surface_configure_opcode
    mov rdx, handle_xdg_surface_configure
    call wire_set_dispatcher

    ; wire_set_dispatcher(
    ;     WlObjectType::WmBase,
    ;     wire_event.wm_base_ping_opcode,
    ;     handle_wm_base_ping)
    mov rdi, WL_OBJECT_TYPE_WM_BASE
    mov rsi, wire_event.wm_base_ping_opcode
    mov rdx, handle_wm_base_ping
    call wire_set_dispatcher

    ; wire_set_dispatcher(
    ;     WlObjectType::Toplevel,
    ;     wire_event.xdg_toplevel_close_opcode,
    ;     handle_toplevel_close)
    mov rdi, WL_OBJECT_TYPE_TOPLEVEL
    mov rsi, wire_event.xdg_toplevel_close_opcode
    mov rdx, handle_toplevel_close
    call wire_set_dispatcher

    ; wire_set_dispatcher(
    ;     WlObjectType::Toplevel,
    ;     wire_event.xdg_toplevel_configure_opcode,
    ;     handle_toplevel_configure)
    mov rdi, WL_OBJECT_TYPE_TOPLEVEL
    mov rsi, wire_event.xdg_toplevel_configure_opcode
    mov rdx, handle_toplevel_configure
    call wire_set_dispatcher

    ; wire_set_dispatcher(
    ;     WlObjectType::Buffer,
    ;     wire_event.buffer_release_opcode,
    ;     handle_buffer_release)
    mov rdi, WL_OBJECT_TYPE_BUFFER
    mov rsi, wire_event.buffer_release_opcode
    mov rdx, handle_buffer_release
    call wire_set_dispatcher

    ; _ = wire_send_display_get_registry()
    call wire_send_display_get_registry

    ; wire_display_roundtrip(display_fd)
    mov rdi, qword [display_fd]
    call wire_display_roundtrip

    ; wl_compositor_id = wire_send_registry_bind_global(&wl_compositor_global)
    mov rdi, wl_compositor_global
    call wire_send_registry_bind_global
    mov qword [wl_compositor_id], rax

    ; wl_shm_id = wire_send_registry_bind_global(&wl_shm_global)
    mov rdi, wl_shm_global
    call wire_send_registry_bind_global
    mov qword [wl_shm_id], rax

    ; xdg_wm_base_id = wire_send_registry_bind_global(&xdg_wm_base_global)
    mov rdi, xdg_wm_base_global
    call wire_send_registry_bind_global
    mov qword [xdg_wm_base_id], rax

    ; wl_surface_id = wire_send_compositor_create_surface(wl_compositor_id)
    mov rdi, qword [wl_compositor_id]
    call wire_send_compositor_create_surface
    mov qword [wl_surface_id], rax

    ; xdg_surface_id = wire_send_wm_base_get_xdg_surface(xdg_wm_base_id, wl_surface_id)
    mov rdi, qword [xdg_wm_base_id]
    mov rsi, qword [wl_surface_id]
    call wire_send_wm_base_get_xdg_surface
    mov qword [xdg_surface_id], rax

    ; xdg_toplevel_id = wire_send_xdg_surface_get_toplevel(xdg_surface_id)
    mov rdi, qword [xdg_surface_id]
    call wire_send_xdg_surface_get_toplevel
    mov qword [xdg_toplevel_id], rax

    ; wire_send_surface_commit(wl_surface_id)
    mov rdi, qword [wl_surface_id]
    call wire_send_surface_commit

    ; wire_send_xdg_toplevel_set_title(xdg_toplevel_id, "Minecraft")
    mov rdi, qword [xdg_toplevel_id]
    mov rsi, minecraft_str.len
    mov rdx, minecraft_str.ptr
    call wire_send_xdg_toplevel_set_title

    ; wire_send_xdg_toplevel_set_app_id(xdg_toplevel_id, "Minecraft")
    mov rdi, qword [xdg_toplevel_id]
    mov rsi, minecraft_str.len
    mov rdx, minecraft_str.ptr
    call wire_send_xdg_toplevel_set_app_id

    ; wl_shm_pool_id = wire_send_shm_create_pool(wl_shm_id, shm.fd, shm_size)
    mov rdi, qword [wl_shm_id]
    mov rsi, qword [shm + Shm.fd]
    mov rdx, shm_size
    call wire_send_shm_create_pool
    mov qword [wl_shm_pool_id], rax

    ; wl_buffer_id = wire_send_shm_pool_create_buffer(
    ;     wl_shm_pool_id,
    ;     offset = 0,
    ;     width = window_width,
    ;     height = window_height,
    ;     stride = .width * sizeof(u32),
    ;     format = SHM_FORMAT_XRGB8888)
    mov rdi, qword [wl_shm_pool_id]
    xor rsi, rsi
    mov rdx, window_width
    mov rcx, window_height
    lea r8, [4 * rdx]
    mov r9, SHM_FORMAT_XRGB8888
    call wire_send_shm_pool_create_buffer
    mov qword [wl_buffer_id], rax

    ; while is_window_open {
    .while:
    cmp byte [is_window_open], 0
    je .end_while

        ; wire_send_surface_attach(wl_surface_id, wl_buffer_id, 0, 0)
        mov rdi, qword [wl_surface_id]
        mov rsi, qword [wl_buffer_id]
        xor rdx, rdx
        xor rcx, rcx
        call wire_send_surface_attach
    
        ; wire_send_surface_damage(wl_surface_id, 0, 0, u32::MAX, u32::MAX)
        mov rdi, qword [wl_surface_id]
        xor rsi, rsi
        xor rdx, rdx
        mov rcx, 0xFFFFFFFF
        mov r8, 0xFFFFFFFF
        call wire_send_surface_damage

        ; wire_send_surface_commit(wl_surface_id)
        mov rdi, qword [wl_surface_id]
        call wire_send_surface_commit

        ; wire_display_roundtrip(display_fd)
        mov rdi, qword [display_fd]
        call wire_display_roundtrip

    ; }
    jmp .while
    .end_while:

    ; drop(shm)
    mov rdi, shm
    call Shm_drop

    ; close(fd)
    mov rax, SYSCALL_CLOSE
    mov rdi, qword [display_fd]
    syscall
    call exit_on_error

    ; drop(socket_path)
    mov rdi, socket_path
    call String_drop

    ; wire_deinit()
    call wire_deinit

    ; deinit_format()
    call deinit_format

    ; return EXIT_SUCCESS
    xor rax, rax
    ret

; #[systemv]
; fn handle_registry_global((_registry_id := rdi): u32)
handle_registry_global:
    PUSH r12, r13, rbp
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

    ; fmt_args.name = wire_message.body.name
    xor rax, rax
    mov eax, dword [wire_message + WireMessageHeader.sizeof + RegistryGlobalEvent.name]
    mov qword [rbp + .fmt_args + GlobalFmtArgs.name], rax

    ; fmt_args.interface.len = wire_message.body.interface.len - 1
    xor rax, rax
    mov eax, dword [wire_message + WireMessageHeader.sizeof + RegistryGlobalEvent.interface.len]
    dec rax
    mov qword [rbp + .fmt_args + GlobalFmtArgs.interface + Str.len], rax

    ; let (interface_len := r8) = fmt_args.interface.len - 1
    mov r8, rax

    ; fmt_args.interface.ptr = &wire_message.body.interface
    mov qword [rbp + .fmt_args + GlobalFmtArgs.interface + Str.ptr], \
        wire_message + WireMessageHeader.sizeof + RegistryGlobalEvent.interface

    ; let (string_block_size := r8) = (interface_len + 3) / 4
    add r8, 3
    shr r8, 2

    ; fmt_args.version = wire_message.body.version
    xor rax, rax
    mov eax, dword [wire_message + WireMessageHeader.sizeof + RegistryGlobalEvent.sizeof + 4*r8]
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
    jz .else_if_shm

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
    .else_if_shm:
    mov rdi, r12
    mov rsi, r13
    mov rdx, wl_shm_str.len
    mov rcx, wl_shm_str.ptr
    call Str_eq
    test al, al
    movzx rax, al
    jz .else_if_wm_base

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

    ; } else if interface_name == "xdg_wm_base" {
    jmp .end_if_name
    .else_if_wm_base:
    mov rdi, r12
    mov rsi, r13
    mov rdx, xdg_wm_base_str.len
    mov rcx, xdg_wm_base_str.ptr
    call Str_eq
    test al, al
    movzx rax, al
    jz .end_if_name

        ; xdg_wm_base_global.name = fmt_args.name as u32
        mov rax, qword [rbp + .fmt_args + GlobalFmtArgs.name]
        mov dword [xdg_wm_base_global + RegistryGlobal.name], eax

        ; xdg_wm_base_global.interface.push_str(fmt_args.interface)
        mov rdi, xdg_wm_base_global + RegistryGlobal.interface
        mov rsi, r12
        mov rdx, r13
        call String_push_str

        ; xdg_wm_base_global.version = fmt_args.version as u32
        mov rax, qword [rbp + .fmt_args + GlobalFmtArgs.version]
        mov dword [xdg_wm_base_global + RegistryGlobal.version], eax

    ; }
    .end_if_name:

    add rsp, .stack_size

    POP rbp, r13, r12
    ret

; #[systemv]
; fn handle_buffer_release((buffer_id := rdi): u32)
handle_buffer_release:
    ret

; #[systemv]
; fn handle_xdg_surface_configure((xdg_surface_id := rdi): u32)
handle_xdg_surface_configure:
    ; let (serial := rsi) = wire_message.body.serial
    xor rsi, rsi
    mov esi, dword [wire_message + WireMessageHeader.sizeof + XdgSurfaceConfigureEvent.serial]

    ; wire_send_xdg_surface_ack_configure(xdg_surface_id, serial)
    ; mov rdi, rdi
    ; mov rsi, rsi
    call wire_send_xdg_surface_ack_configure
    
    ret

; #[systemv]
; fn handle_wm_base_ping((wm_base_id := rdi): u32)
handle_wm_base_ping:
    ; let (serial := rsi) = wire_message.body.serial
    xor rsi, rsi
    mov esi, dword [wire_message + WireMessageHeader.sizeof + WmBasePingEvent.serial]

    ; wire_send_wm_base_pong(wm_base_id, serial)
    ; mov rdi, rdi
    ; mov rsi, rsi
    call wire_send_wm_base_pong
    
    ret

; #[systemv]
; fn handle_toplevel_configure((toplevel_id := rdi): u32)
handle_toplevel_configure:
    PUSH r12

    ; if wire_message.width == 0 { return }
    cmp dword [wire_message + WireMessageHeader.sizeof + XdgToplevelConfigureEvent.width], 0
    je .exit

    ; if wire_message.height == 0 { return }
    cmp dword [wire_message + WireMessageHeader.sizeof + XdgToplevelConfigureEvent.height], 0
    je .exit

    ; let (shm_size := r12) = sizeof(u32) * width * height
    mov eax, dword [wire_message + WireMessageHeader.sizeof + XdgToplevelConfigureEvent.width]
    mov esi, dword [wire_message + WireMessageHeader.sizeof + XdgToplevelConfigureEvent.height]
    mul rsi
    lea r12, [4 * rax]

    ; wire_send_buffer_destroy(wl_buffer_id)
    mov rdi, qword [wl_buffer_id]
    call wire_send_buffer_destroy

    ; wire_send_shm_pool_destroy(wl_shm_pool_id)
    mov rdi, qword [wl_shm_pool_id]
    call wire_send_shm_pool_destroy

    ; wire_flush(display_fd)
    mov rdi, qword [display_fd]
    call wire_flush

    ; drop(shm)
    mov rdi, shm
    call Shm_drop

    ; shm = Shm::new(shm_size)
    mov rdi, shm
    mov rsi, r12
    call Shm_new

    ; wl_shm_pool_id = wire_send_shm_create_pool(wl_shm_id, shm.fd, shm_size)
    mov rdi, qword [wl_shm_id]
    mov rsi, qword [shm + Shm.fd]
    mov rdx, r12
    call wire_send_shm_create_pool
    mov qword [wl_shm_pool_id], rax

    ; wl_buffer_id = wire_send_shm_pool_create_buffer(
    ;     wl_shm_pool_id,
    ;     offset = 0,
    ;     width = wire_message.width,
    ;     height = wire_message.height,
    ;     stride = .width * sizeof(u32),
    ;     format = SHM_FORMAT_XRGB8888)
    mov rdi, qword [wl_shm_pool_id]
    xor rsi, rsi
    mov edx, dword [wire_message + WireMessageHeader.sizeof + XdgToplevelConfigureEvent.width]
    mov ecx, dword [wire_message + WireMessageHeader.sizeof + XdgToplevelConfigureEvent.height]
    lea r8, [4 * rdx]
    mov r9, SHM_FORMAT_XRGB8888
    call wire_send_shm_pool_create_buffer
    mov qword [wl_buffer_id], rax

    .exit:
    POP r12
    ret

; #[systemv]
; fn handle_toplevel_close((_toplevel_id := rdi): u32)
handle_toplevel_close:
    ; is_window_open = false
    mov byte [is_window_open], 0

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
