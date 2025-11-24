%ifndef _WIRE_INC
%define _WIRE_INC

%define WIRE_MESSAGE_BUFFER_SIZE (4 * 512)
%define WIRE_MESSAGE_MAX_N_FDS   64

%define SHM_FORMAT_ARGB8888 0

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

        .surface_destroy_opcode           equ 0
        .surface_attach_opcode            equ 1
        .surface_damage_opcode            equ 2
        .surface_frame_opcode             equ 3
        .surface_set_opaque_region_opcode equ 4
        .surface_set_input_region_opcode  equ 5
        .surface_commit_opcode            equ 6

        .shm_create_pool_opcode           equ 0

        .shm_pool_create_buffer_opcode    equ 0

        .wm_base_get_xdg_surface_opcode   equ 2
        .wm_base_pong_opcode              equ 3

        .xdg_surface_get_toplevel_opcode  equ 1
        .xdg_surface_ack_configure_opcode equ 4

        .xdg_toplevel_set_title_opcode    equ 2

    wire_event:
        .display_error_opcode             equ 0
        .callback_done_opcode             equ 0
        .registry_global_opcode           equ 0

        .xdg_toplevel_close_opcode        equ 1

        .wm_base_ping_opcode              equ 0

        .xdg_surface_configure_opcode     equ 0

    ; static wire_message_buffer_len: usize
    wire_message_buffer_len               resq 1

    ; static wire_current_message_len: usize
    wire_current_message_len              resq 1

    ; static wire_message_buffer: [u8; WIRE_MESSAGE_BUFFER_SIZE]
    wire_message_buffer                   resb WIRE_MESSAGE_BUFFER_SIZE

    ; static wire_message_n_fds: usize
    wire_message_n_fds                    resq 1

    ; static wire_message_fds_header: cmsghdr
                                          align 8
    wire_message_fds_header               resb cmsghdr.sizeof

    ; static wire_message_fds: [u32; WIRE_MESSAGE_MAX_N_FDS]
    wire_message_fds                      resd WIRE_MESSAGE_MAX_N_FDS

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

struc WmBasePingEvent
    .serial         resd 1
    .sizeof         equ $-.serial
endstruc

struc XdgSurfaceConfigureEvent
    .serial         resd 1
    .sizeof         equ $-.serial
endstruc

struc XdgToplevelCloseEvent
    .pad            resb 0
    .sizeof         equ $-.pad
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
       wire_begin_request, wire_end_request, wire_write_fd

extern wire_send_display_sync, wire_send_display_get_registry

extern wire_send_registry_bind, wire_send_registry_bind_global

extern wire_send_compositor_create_surface

extern wire_send_surface_attach, wire_send_surface_damage, wire_send_surface_commit

extern wire_send_shm_create_pool

extern wire_send_shm_pool_create_buffer

extern wire_send_wm_base_get_xdg_surface, wire_send_wm_base_pong

extern wire_send_xdg_surface_get_toplevel, wire_send_xdg_surface_ack_configure

extern wire_send_xdg_toplevel_set_title

%endif ; !_WIRE_INC
