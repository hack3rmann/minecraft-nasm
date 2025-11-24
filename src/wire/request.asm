%include "../wire.s"
%include "../syscall.s"
%include "../error.s"
%include "../memory.s"
%include "../debug.s"
%include "../string.s"

section .text

; #[fastcall]
; fn wire_get_next_id() -> usize := rax
wire_get_next_id:
    ; wire_last_id += 1
    inc qword [wire_last_id]

    ; return wire_last_id
    mov rax, qword [wire_last_id]

    ret

; #[systemv]
; fn wire_send_display_sync() -> u32 := rax
wire_send_display_sync:
    push r12

    ; wire_begin_request(wire_id.wl_display, wire_request.display_sync_opcode)
    mov rdi, wire_id.wl_display
    mov rsi, wire_request.display_sync_opcode
    call wire_begin_request

    ; let (id := r12) = wire_get_next_id()
    call wire_get_next_id
    mov r12, rax

    ; wire_write_uint(id)
    mov rdi, r12
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r12

    pop r12
    ret

; #[systemv]
; fn wire_send_display_get_registry() -> u32 := rax
wire_send_display_get_registry:
    push r12

    ; wire_begin_request(wire_id.wl_display, wire_request.display_get_registry_opcode)
    mov rdi, wire_id.wl_display
    mov rsi, wire_request.display_get_registry_opcode
    call wire_begin_request

    ; let (id := r12) = wire_get_next_id()
    call wire_get_next_id
    mov r12, rax

    ; wire_write_uint(id)
    mov rdi, r12
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r12

    pop r12
    ret

; #[systemv]
; fn wire_send_registry_bind(
;     (name := rdi): u32,
;     (version := rsi): u32,
;     (interface := rdx:rcx): Str
; ) -> u32 := rax
wire_send_registry_bind:
    push r12
    push r13
    push r14

    ; let (name := r12) = name
    mov r12, rdi

    ; let (version := r14) = version
    mov r14, rsi

    ; let (interface := r10:r11) = interface
    mov r10, rdx
    mov r11, rcx

    ; wire_begin_request(wire_id.wl_registry, wire_request.registry_bind_opcode)
    mov rdi, wire_id.wl_registry
    mov rsi, wire_request.registry_bind_opcode
    call wire_begin_request

    ; let (id := r13) = wire_get_next_id()
    call wire_get_next_id
    mov r13, rax

    ; wire_write_uint(name)
    mov rdi, r12
    call wire_write_uint

    ; // NewId { interface: str, version: u32, id: u32 }

    ; wire_write_str(interface)
    mov rdi, r10
    mov rsi, r11
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

    pop r14
    pop r13
    pop r12
    ret

; #[systemv]
; fn wire_flush((display_fd := rdi): Fd)
wire_flush:
    push r12

    ; let (display_fd := r12) = display_fd
    mov r12, rdi

    ; let (n_bytes := rax) = write(display_fd, &wire_message_buffer, wire_message_buffer_len)
    mov rax, SYSCALL_WRITE
    mov rdi, r12
    mov rsi, wire_message_buffer
    mov rdx, qword [wire_message_buffer_len]
    syscall

    ; assert n_bytes == wire_message_buffer_len
    cmp rax, qword [wire_message_buffer_len]
    jne abort

    ; wire_message_buffer_len = 0
    mov qword [wire_message_buffer_len], 0

    ; wire_current_message_len = 0
    mov qword [wire_current_message_len], 0

    pop r12
    ret

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

; #[systemv]
; fn wire_write_str(Str { len := rdi, ptr := rsi })
wire_write_str:
    push r12
    push r13

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

    pop r13
    pop r12
    ret

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
wire_send_compositor_create_surface:
    push r12
    push r13

    ; let (compositor_id := r12) = compositor_id
    mov r12, rdi

    ; wire_begin_request(compositor_id, wire_request.compositor_create_surface_opcode)
    mov rdi, r12
    mov rsi, wire_request.compositor_create_surface_opcode
    call wire_begin_request

    ; let (id := r13) = wire_get_next_id()
    call wire_get_next_id
    mov r13, rax

    ; wire_write_uint(id)
    mov rdi, r13
    call wire_write_uint

    ; wire_end_request()
    call wire_end_request

    ; return id
    mov rax, r13

    pop r13
    pop r12
    ret

; #[systemv]
; fn wire_send_registry_bind_global((global := rdi): &RegistryGlobal) -> u32 := rax
wire_send_registry_bind_global:
    push r12
    push r13

    ; let (global := r12) = global
    mov r12, rdi

    ; return wire_send_registry_bind(global.name, global.version, global.interface)
    xor rdi, rdi
    xor rsi, rsi
    mov edi, dword [r12 + RegistryGlobal.name]
    mov esi, dword [r12 + RegistryGlobal.version]
    mov rdx, qword [r12 + RegistryGlobal.interface + Str.len]
    mov rcx, qword [r12 + RegistryGlobal.interface + Str.ptr]
    call wire_send_registry_bind

    pop r13
    pop r12
    ret
