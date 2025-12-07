%include "../string.s"
%include "../syscall.s"
%include "../wire.s"
%include "../error.s"
%include "../memory.s"
%include "../debug.s"
%include "../function.s"

section .text

; #[fastcall]
; fn wire_get_next_id() -> usize := rax
wire_get_next_id:
    ; let (id := rax) = if wire_n_reused_ids == 0 {
    cmp qword [wire_n_reused_ids], 0
    jnz .else

        ; wire_last_id += 1
        inc qword [wire_last_id]

        ; id = wire_last_id
        mov rax, qword [wire_last_id]

    ; } else {
    jmp .end_if
    .else:

        ; wire_n_reused_ids -= 1
        dec qword [wire_n_reused_ids]

        ; id = wire_reused_ids[wire_n_reused_ids]
        mov rax, qword [wire_n_reused_ids]
        mov eax, dword [wire_reused_ids + 4 * rax]

    ; }
    .end_if:

    ; assert wire_last_id < WIRE_MAX_N_OBJECTS
    cmp rax, WIRE_MAX_N_OBJECTS
    jae abort

    ; return wire_last_id

    ret

; #[fastcall(rax)]
; fn wire_release_id((id := rdi): u32)
wire_release_id:
    ; wire_reused_ids[wire_n_reused_ids] = id
    mov rax, qword [wire_n_reused_ids]
    mov dword [wire_reused_ids + 4 * rax], edi

    ; wire_n_reused_ids += 1
    inc qword [wire_n_reused_ids]

    ret

; #[systemv]
; fn wire_send_display_sync() -> u32 := rax
FN wire_send_display_sync
    PUSH r12

    ; wire_begin_request(wire_id.wl_display, wire_request.display_sync_opcode)
    mov rdi, wire_id.wl_display
    mov rsi, wire_request.display_sync_opcode
    call wire_begin_request

    ; let (id := r12) = wire_get_next_id()
    call wire_get_next_id
    mov r12, rax

    ; wire_object_types[id] = WlObjectType::Callback
    mov byte [wire_object_types + r12], WL_OBJECT_TYPE_CALLBACK

    ; wire_write_uint(id)
    mov rdi, r12
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r12

    POP r12
END_FN

; #[systemv]
; fn wire_send_display_get_registry() -> u32 := rax
FN wire_send_display_get_registry
    PUSH r12

    ; wire_begin_request(wire_id.wl_display, wire_request.display_get_registry_opcode)
    mov rdi, wire_id.wl_display
    mov rsi, wire_request.display_get_registry_opcode
    call wire_begin_request

    ; let (id := r12) = wire_get_next_id()
    call wire_get_next_id
    mov r12, rax

    ; wire_object_types[id] = WlObjectType::Registry
    mov byte [wire_object_types + r12], WL_OBJECT_TYPE_REGISTRY

    ; wire_write_uint(id)
    mov rdi, r12
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r12

    POP r12
END_FN

; #[systemv]
; fn wire_send_registry_bind(
;     (name := rdi): u32,
;     (version := rsi): u32,
;     (interface := rdx:rcx): Str
; ) -> u32 := rax
FN wire_send_registry_bind
    PUSH r12, r13, r14, r15, rbx

    ; let (name := r12) = name
    mov r12, rdi

    ; let (version := r14) = version
    mov r14, rsi

    ; let (interface := r15:rbx) = interface
    mov r15, rdx
    mov rbx, rcx

    ; wire_begin_request(wire_id.wl_registry, wire_request.registry_bind_opcode)
    mov rdi, wire_id.wl_registry
    mov rsi, wire_request.registry_bind_opcode
    call wire_begin_request

    ; let (id := r13) = wire_get_next_id()
    call wire_get_next_id
    mov r13, rax

    ; wire_object_types[id] = WlObjectType::from_str(interface)
    mov rdi, r15
    mov rsi, rbx
    call WlObjectType_from_str
    mov byte [wire_object_types + r13], al
    movzx rax, al

    ; wire_write_uint(name)
    mov rdi, r12
    call wire_write_uint

    ; // NewId { interface: str, version: u32, id: u32 }

    ; wire_write_str(interface)
    mov rdi, r15
    mov rsi, rbx
    call wire_write_str

    ; wire_write_uint(version)
    mov rdi, r14
    call wire_write_uint

    ; wire_write_uint(id)
    mov rdi, r13
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r13

    POP rbx, r15, r14, r13, r12
END_FN

; #[systemv]
; fn wire_flush((display_fd := rdi): Fd)
FN wire_flush
    PUSH r12

    ; let (display_fd := r12) = display_fd
    mov r12, rdi

    ; if wire_message_n_fds == 0 {
    cmp qword [wire_message_n_fds], 0
    jne .else

        ; let (n_bytes := rax) = write(display_fd, &wire_message_buffer, wire_message_buffer_len)
        mov rax, SYSCALL_WRITE
        mov rdi, r12
        mov rsi, wire_message_buffer
        mov rdx, qword [wire_message_buffer_len]
        syscall

        ; assert n_bytes == wire_message_buffer_len
        cmp rax, qword [wire_message_buffer_len]
        jne abort

    ; } else {
    jmp .end_if
    .else:

        ; wire_flush_fds(display_fd)
        mov rdi, r12
        call wire_flush_fds

    ; }
    .end_if:

    ; wire_message_buffer_len = 0
    mov qword [wire_message_buffer_len], 0

    ; wire_current_message_len = 0
    mov qword [wire_current_message_len], 0

    ; wire_message_n_fds = 0
    mov qword [wire_message_n_fds], 0

    POP r12
END_FN

; #[systemv]
; #[private]
; fn wire_flush_fds((display_fd := rdi): Fd)
FN wire_flush_fds
    PUSH r12

    LOCAL .io, iovec.sizeof
    LOCAL .msg, msghdr.sizeof
    STACK .stack_size

    ; let msg: msghdr
    ; let io: iovec
    sub rsp, .stack_size

    ; let (display_fd := r12) = display_fd
    mov r12, rdi

    ; set8(&msg, 0, sizeof(msg))
    lea rdi, [rbp + .msg]
    xor rsi, rsi
    mov rdx, msghdr.sizeof
    call set8

    ; io.iov_base = &wire_message_buffer
    mov qword [rbp + .io + iovec.iov_base], wire_message_buffer

    ; io.iov_len = wire_message_buffer_len
    mov rax, qword [wire_message_buffer_len]
    mov qword [rbp + .io + iovec.iov_len], rax

    ; msg.msg_iov = &io
    lea rax, [rbp + .io]
    mov qword [rbp + .msg + msghdr.msg_iov], rax

    ; msg.msg_iovlen = 1
    mov qword [rbp + .msg + msghdr.msg_iovlen], 1

    ; msg.msg_control = &wire_message_fds_header
    mov qword [rbp + .msg + msghdr.msg_control], wire_message_fds_header

    ; msg.msg_controllen = (sizeof(cmsghdr) + sizeof(Fd) * wire_message_n_fds + 7) & ~7
    mov rax, qword [wire_message_n_fds]
    lea rax, [cmsghdr.sizeof + 4*rax + 7]
    and rax, 0xFFFFFFFFFFFFFFFF - 7
    mov qword [rbp + .msg + msghdr.msg_controllen], rax

    ; wire_message_fds_header.cmsg_len = sizeof(cmsghdr) + sizeof(Fd) * wire_message_n_fds
    mov rax, qword [wire_message_n_fds]
    lea rax, [cmsghdr.sizeof + 4*rax]
    mov qword [wire_message_fds_header + cmsghdr.cmsg_len], rax

    ; wire_message_fds_header.cmsg_level = SOL_SOCKET
    mov dword [wire_message_fds_header + cmsghdr.cmsg_level], SOL_SOCKET

    ; wire_message_fds_header.cmsg_type = SCM_RIGHTS
    mov dword [wire_message_fds_header + cmsghdr.cmsg_type], SCM_RIGHTS

    ; sendmsg(display_fd, &msg, 0)
    mov rax, SYSCALL_SENDMSG
    mov rdi, r12
    lea rsi, [rbp + .msg]
    xor rdx, rdx
    syscall
    call exit_on_error

    add rsp, .stack_size

    POP r12
END_FN

; #[fastcall(rax)]
; fn wire_write_uint((value := edi): u32)
wire_write_uint:
    ; let (buffer_len := rax) = wire_message_buffer_len
    mov rax, qword [wire_message_buffer_len]

    ; wire_message_buffer[buffer_len .. buffer_len + 4] = value
    mov dword [wire_message_buffer + rax], edi

    ; wire_message_buffer_len += 4
    add qword [wire_message_buffer_len], 4

    ; wire_current_message_len += 4
    add qword [wire_current_message_len], 4

    ret

; #[fastcall(rax)]
; fn wire_write_fd((fd := edi): Fd)
wire_write_fd:
    ; let (n_fds := rax) = wire_message_n_fds
    mov rax, qword [wire_message_n_fds]

    ; wire_message_fds[n_fds] = fd
    mov dword [wire_message_fds + 4*rax], edi

    ; wire_message_n_fds += 1
    inc qword [wire_message_n_fds]

    ret

; #[systemv]
; fn wire_write_str(Str { len := rdi, ptr := rsi })
FN wire_write_str
    PUSH r12, r13

    ; let (len := r12) = len
    mov r12, rdi

    ; let (ptr := r13) = ptr
    mov r13, rsi

    ; wire_write_uint(len + 1)
    lea rdi, [r12 + 1]
    call wire_write_uint

    ; copy(ptr, wire_message_buffer + wire_message_buffer_len, len)
    mov rdi, r13
    mov rsi, wire_message_buffer
    add rsi, qword [wire_message_buffer_len]
    mov rdx, r12
    call copy

    ; wire_message_buffer[wire_message_buffer_len + len] = b'\0'
    mov rax, qword [wire_message_buffer_len]
    mov byte [rax + wire_message_buffer + r12], 0

    ; let (padded_len := rax) = ((len + 1) + 3) / 4 * 4 = (len + 4) & ~0b11
    lea rax, [r12 + 4]
    and rax, 0xFFFFFFFFFFFFFFFF - 3

    ; wire_message_buffer_len += padded_len
    add qword [wire_message_buffer_len], rax

    ; wire_current_message_len += padded_len
    add qword [wire_current_message_len], rax

    POP r13, r12
END_FN

; #[fastcall(rax)]
; fn wire_begin_request((object_id := edi): u32, (opcode := si): u16)
wire_begin_request:
    ; wire_current_message_len = sizeof(WireMessageHeader)
    mov qword [wire_current_message_len], WireMessageHeader.sizeof

    ; let (message := rax): *mut WireMessageHeader
    ;     = &wire_message_buffer + wire_message_buffer_len
    mov rax, qword [wire_message_buffer_len]
    add rax, wire_message_buffer

    ; message->object_id = object_id
    mov dword [rax + WireMessageHeader.object_id], edi

    ; message->opcode = opcode
    mov word [rax + WireMessageHeader.opcode], si

    ; message->size = 0
    mov word [rax + WireMessageHeader.size], 0

    ; wire_message_buffer_len += sizeof(WireMessageHeader)
    add qword [wire_message_buffer_len], WireMessageHeader.sizeof

    ret

; #[fastcall(rax, rdi)]
; fn wire_end_request()
wire_end_request:
    ; let (current_len := rdi) = wire_current_message_len
    mov rdi, qword [wire_current_message_len]

    ; let (header_ptr := rax): *mut WireMessageHeader
    ;     = &wire_message_buffer + wire_message_buffer_len - current_len
    mov rax, wire_message_buffer
    add rax, qword [wire_message_buffer_len]
    sub rax, rdi

    ; header_ptr->size = wire_current_message_len
    mov word [rax + WireMessageHeader.size], di

    ret

; #[systemv]
; fn wire_send_compositor_create_surface((compositor_id := rdi): u32) -> u32 := rax
FN wire_send_compositor_create_surface
    PUSH r12, r13

    ; let (compositor_id := r12) = compositor_id
    mov r12, rdi

    ; wire_begin_request(compositor_id, wire_request.compositor_create_surface_opcode)
    mov rdi, r12
    mov rsi, wire_request.compositor_create_surface_opcode
    call wire_begin_request

    ; let (id := r13) = wire_get_next_id()
    call wire_get_next_id
    mov r13, rax

    ; wire_object_types[id] = WlObjectType::Surface
    mov byte [wire_object_types + r13], WL_OBJECT_TYPE_SURFACE

    ; wire_write_uint(id)
    mov rdi, r13
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r13

    POP r13, r12
END_FN

; #[systemv]
; fn wire_send_registry_bind_global((global := rdi): &RegistryGlobal) -> u32 := rax
FN wire_send_registry_bind_global
    PUSH r12, r13, r14, r15

    ; let (global := r12) = global
    mov r12, rdi

    ; return wire_send_registry_bind(global.name, global.version, global.interface)
    xor rdi, rdi
    xor rsi, rsi
    mov edi, dword [r12 + RegistryGlobal.name]
    mov esi, dword [r12 + RegistryGlobal.version]
    mov rdx, qword [r12 + RegistryGlobal.interface + Str.len]
    mov r14, rdx
    mov rcx, qword [r12 + RegistryGlobal.interface + Str.ptr]
    mov r15, rcx
    call wire_send_registry_bind

    POP r15, r14, r13, r12
END_FN

; #[systemv]
; fn wire_send_shm_create_pool(
;     (shm_id := rdi): u32,
;     (fd := rsi): u32,
;     (size := rdx): u32
; ) -> u32 := rax
FN wire_send_shm_create_pool
    PUSH r12, r13, r14, r15

    ; let (shm_id := r12) = shm_id
    mov r12, rdi

    ; let (fd := r13) = fd
    mov r13, rsi

    ; let (size := r14) = size
    mov r14, rdx

    ; wire_begin_request(shm, wire_request.shm_create_pool_opcode)
    mov rdi, r12
    mov rsi, wire_request.shm_create_pool_opcode
    call wire_begin_request

    ; let (id := r15) = wire_get_next_id()
    call wire_get_next_id
    mov r15, rax

    ; wire_object_types[id] = WlObjectType::ShmPool
    mov byte [wire_object_types + r15], WL_OBJECT_TYPE_SHM_POOL

    ; wire_write_uint(id)
    mov rdi, r15
    call wire_write_uint

    ; wire_write_fd(fd)
    mov rdi, r13
    call wire_write_fd

    ; wire_write_uint(size)
    mov rdi, r14
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r15

    POP r15, r14, r13, r12
END_FN

; #[systemv]
; fn wire_send_shm_pool_destroy((shm_pool_id := rdi): u32)
FN wire_send_shm_pool_destroy
    ; wire_begin_request(shm_pool_id, wire_request.shm_pool_destroy_opcode)
    ; mov rdi, rdi
    mov rsi, wire_request.shm_pool_destroy_opcode
    call wire_begin_request

    ; wire_end_request()
    call wire_end_request
END_FN

; #[systemv]
; fn wire_send_shm_pool_create_buffer(
;     (shm_pool_id := rdi): u32,
;     (offset := rsi): u32,
;     (width := rdx): u32,
;     (height := rcx): u32,
;     (stride := r8): u32,
;     (format := r9): WlShmFormat
; ) -> u32 := rax
FN wire_send_shm_pool_create_buffer
    PUSH r12

    LOCAL .format, 4
    LOCAL .stride, 4
    LOCAL .height, 4
    LOCAL .width, 4
    LOCAL .offset, 4
    LOCAL .shm_pool_id, 4
    STACK .stack_size

    sub rsp, .stack_size

    ; args = get_fn_args()
    mov dword [rbp + .shm_pool_id], edi
    mov dword [rbp + .offset], esi
    mov dword [rbp + .width], edx
    mov dword [rbp + .height], ecx
    mov dword [rbp + .stride], r8d
    mov dword [rbp + .format], r9d

    ; wire_begin_request(shm_pool_id, wire_request.shm_pool_create_buffer_opcode)
    xor rdi, rdi
    mov edi, dword [rbp + .shm_pool_id]
    mov rsi, wire_request.shm_pool_create_buffer_opcode
    call wire_begin_request

    ; let (id := r12) = wire_get_next_id()
    call wire_get_next_id
    mov r12, rax

    ; wire_object_types[id] = WlObjectType::Buffer
    mov byte [wire_object_types + r12], WL_OBJECT_TYPE_BUFFER

    ; wire_write_uint(id)
    mov rdi, r12
    call wire_write_uint

    ; wire_write_uint(offset)
    xor rdi, rdi
    mov edi, dword [rbp + .offset]
    call wire_write_uint

    ; wire_write_uint(width)
    xor rdi, rdi
    mov edi, dword [rbp + .width]
    call wire_write_uint

    ; wire_write_uint(height)
    xor rdi, rdi
    mov edi, dword [rbp + .height]
    call wire_write_uint

    ; wire_write_uint(stride)
    xor rdi, rdi
    mov edi, dword [rbp + .stride]
    call wire_write_uint

    ; wire_write_uint(format)
    xor rdi, rdi
    mov edi, dword [rbp + .format]
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r12

    add rsp, .stack_size
    
    POP r12
END_FN

; #[systemv]
; fn wire_send_wm_base_get_xdg_surface(
;     (wm_base_id := rdi): u32, (wl_surface_id := rsi): u32,
; ) -> u32 := rax
FN wire_send_wm_base_get_xdg_surface
    PUSH r12, r13, r14

    ; let (wm_base_id := r12) = wm_base_id
    mov r12, rdi

    ; let (wl_surface_id := r13) = wl_surface_id
    mov r13, rsi

    ; wire_begin_request(wm_base_id, wire_request.wm_base_get_xdg_surface_opcode)
    mov rdi, r12
    mov rsi, wire_request.wm_base_get_xdg_surface_opcode
    call wire_begin_request

    ; let (id := r14) = wire_get_next_id()
    call wire_get_next_id
    mov r14, rax

    ; wire_object_types[id] = WlObjectType::XdgSurface
    mov byte [wire_object_types + r14], WL_OBJECT_TYPE_XDG_SURFACE

    ; wire_write_uint(id)
    mov rdi, r14
    call wire_write_uint

    ; wire_write_uint(wl_surface_id)
    mov rdi, r13
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r14

    POP r14, r13, r12
END_FN

; #[systemv]
; fn wire_send_xdg_surface_get_toplevel((xdg_surface_id := rdi): u32) -> u32 := rax
FN wire_send_xdg_surface_get_toplevel
    PUSH r12, r13

    ; let (xdg_surface_id := r12) = xdg_surface_id
    mov r12, rdi

    ; wire_begin_request(xdg_surface_id, wire_request.xdg_surface_get_toplevel_opcode)
    mov rdi, r12
    mov rsi, wire_request.xdg_surface_get_toplevel_opcode
    call wire_begin_request

    ; let (id := r13) = wire_get_next_id()
    call wire_get_next_id
    mov r13, rax

    ; wire_object_types[id] = WlObjectType::Toplevel
    mov byte [wire_object_types + r13], WL_OBJECT_TYPE_TOPLEVEL

    ; wire_write_uint(id)
    mov rdi, r13
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r13

    POP r13, r12
END_FN

; NOTE(hack3rmann): the behavior exactly matches
;
; #[systemv]
; fn wire_send_xdg_toplevel_set_app_id(
;     (xdg_toplevel_id := rdi): u32,
;     Str { app_id_len := rsi, app_id_ptr := rdx } @ app_id,
; )
; #[systemv]
; fn wire_send_xdg_toplevel_set_title(
;     (xdg_toplevel_id := rdi): u32,
;     Str { title_len := rsi, title_ptr := rdx } @ title,
; )
wire_send_xdg_toplevel_set_app_id:
FN wire_send_xdg_toplevel_set_title
    PUSH r12, r13, r14

    ; let (xdg_toplevel_id := r12) = xdg_toplevel_id
    mov r12, rdi

    ; let (title_len := r13) = title_len
    mov r13, rsi
    
    ; let (title_ptr := r14) = title_len
    mov r14, rdx

    ; wire_begin_request(xdg_toplevel_id, wire_request.xdg_toplevel_set_title_opcode)
    mov rdi, r12
    mov rsi, wire_request.xdg_toplevel_set_title_opcode
    call wire_begin_request

    ; wire_write_str(title)
    mov rdi, r13
    mov rsi, r14
    call wire_write_str

    ; wire_end_request()
    call wire_end_request

    POP r14, r13, r12
END_FN

; fn wire_send_surface_attach(
;     (wl_surface_id := rdi): u32,
;     (wl_buffer_id := rsi): u32,
;     (x := rdx): u32,
;     (y := rcx): u32,
; )
FN wire_send_surface_attach
    PUSH r12, r13, r14, r15

    ; let (wl_surface_id := r12) = wl_surface_id
    mov r12, rdi

    ; let (wl_buffer_id := r13) = wl_buffer_id
    mov r13, rsi

    ; let (x := r14) = x
    mov r14, rdx

    ; let (y := r15) = y
    mov r15, rcx

    ; wire_begin_request(wl_surface_id, wire_request.surface_attach_opcode)
    mov rdi, r12
    mov rsi, wire_request.surface_attach_opcode
    call wire_begin_request

    ; wire_write_uint(wl_buffer_id)
    mov rdi, r13
    call wire_write_uint

    ; wire_write_uint(x)
    mov rdi, r14
    call wire_write_uint

    ; wire_write_uint(y)
    mov rdi, r15
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    POP r15, r14, r13, r12
END_FN

; fn wire_send_surface_damage(
;     (wl_surface_id := rdi): u32,
;     (x := rsi): u32,
;     (y := rdx): u32,
;     (width := rcx): u32,
;     (height := r8): u32,
; )
FN wire_send_surface_damage
    PUSH r12, r13, r14, r15, rbx

    ; let (wl_surface_id := r12) = wl_surface_id
    mov r12, rdi

    ; let (x := r13) = x
    mov r13, rsi

    ; let (y := r14) = y
    mov r14, rdx

    ; let (width := r15) = width
    mov r15, rcx

    ; let (height := rbx) = height
    mov rbx, r8

    ; wire_begin_request(wl_surface_id, wire_request.surface_damage_opcode)
    mov rdi, r12
    mov rsi, wire_request.surface_damage_opcode
    call wire_begin_request

    ; wire_write_uint(x)
    mov rdi, r13
    call wire_write_uint

    ; wire_write_uint(y)
    mov rdi, r14
    call wire_write_uint

    ; wire_write_uint(width)
    mov rdi, r15
    call wire_write_uint

    ; wire_write_uint(height)
    mov rdi, rbx
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    POP rbx, r15, r14, r13, r12
END_FN

; #[systemv]
; fn wire_send_surface_commit((wl_surface_id := rdi): u32)
FN wire_send_surface_commit
    ; wire_begin_request(wl_surface_id, wire_request.surface_commit_opcode)
    ; mov rdi, rdi
    mov rsi, wire_request.surface_commit_opcode
    call wire_begin_request

    ; wire_end_request()
    call wire_end_request
END_FN

; #[systemv]
; fn wire_send_xdg_surface_ack_configure((xdg_surface_id := rdi): u32, (serial := rsi): u32)
FN wire_send_xdg_surface_ack_configure
    PUSH r12, r13

    ; let (xdg_surface_id := r12) = xdg_surface_id
    mov r12, rdi

    ; let (serial := r13) = serial
    mov r13, rsi

    ; wire_begin_request(xdg_surface_id, wire_request.xdg_surface_ack_configure_opcode)
    mov rdi, r12
    mov rsi, wire_request.xdg_surface_ack_configure_opcode
    call wire_begin_request

    ; wire_write_uint(serial)
    mov rdi, r13
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    POP r13, r12
END_FN

; fn wire_send_wm_base_pong((wm_base_id := rdi): u32, (serial := rsi): u32)
FN wire_send_wm_base_pong
    PUSH r12, r13

    ; let (wm_base_id := r12) = wm_base_id
    mov r12, rdi

    ; let (serial := r13) = serial
    mov r13, rsi

    ; wire_begin_request(wm_base_id, wire_request.wm_base_pong_opcode)
    mov rdi, r12
    mov rsi, wire_request.wm_base_pong_opcode
    call wire_begin_request

    ; wire_write_uint(serial)
    mov rdi, r13
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    POP r13, r12
END_FN

; #[systemv]
; fn wire_send_buffer_destroy((wl_buffer_id := rdi): u32)
FN wire_send_buffer_destroy
    ; wire_begin_request(wl_buffer_id, wire_request.buffer_destroy_opcode)
    ; mov rdi, rdi
    mov rsi, wire_request.buffer_destroy_opcode
    call wire_begin_request

    ; wire_end_request()
    call wire_end_request
END_FN
