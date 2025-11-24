%ifndef _WIRE_INC
%define _WIRE_INC

%define MESSAGE_BUFFER_SIZE (4 * 64)

section .data
    wire_last_id  dq 1

section .bss
    wire_id:
        .wl_display                       equ 1
        .wl_registry                      equ 2

    wire_request:
        .display_sync_opcode              equ 0
        .display_get_registry_opcode      equ 1

        .registry_bind_opcode             equ 0

        .compositor_create_surface_opcode equ 0

    wire_event:
        .display_error_opcode             equ 0
        .callback_done_opcode             equ 0
        .registry_global_opcode           equ 0

    ; static wire_message_buffer_len: usize
    wire_message_buffer_len               resq 1

    ; static wire_current_message_len: usize
    wire_current_message_len              resq 1

    ; static wire_message_buffer: [u8; MESSAGE_BUFFER_SIZE]
    wire_message_buffer                   resb MESSAGE_BUFFER_SIZE

struc WireMessageHeader
    ; object_id: u32
    .object_id    resd 1
    ; opcode: u16
    .opcode       resw 1
    ; size: u16
    .size         resw 1
    .sizeof       equ $-.object_id
endstruc

struc DisplayErrorEvent
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

extern wire_flush, wire_get_next_id, wire_write_uint, wire_write_str, \
       wire_begin_request, wire_end_request

extern wire_send_display_sync, wire_send_display_get_registry

extern wire_send_registry_bind, wire_send_registry_bind_global

extern wire_send_compositor_create_surface

%endif ; !_WIRE_INC
