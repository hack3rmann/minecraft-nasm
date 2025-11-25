%include "../syscall.s"
%include "../string.s"
%include "../wire.s"

section .data
    wire_last_id          dq 1

    ; static wire_all_objects: [RegistryGlobal; WIRE_MAX_N_OBJECTS]
    ;     = mem::zeroed()
                          align 16
    wire_all_objects      times WIRE_MAX_N_OBJECTS * RegistryGlobal.sizeof \
                          db 0

    ; static wire_object_types: [WlObjectType; WIRE_MAX_N_OBJECTS]
    wire_object_types     times WIRE_MAX_N_OBJECTS db WL_OBJECT_TYPE_INVALID

    ; static wire_n_reused_ids: usize = 0
    wire_n_reused_ids     dq 0

    ; static wire_callbacks: [[fn(u32); WIRE_MAX_N_CALLBACKS]; WL_OBJECT_TYPE_COUNT]
    ;     = mem::zeroed()
    wire_callbacks        times WIRE_MAX_N_CALLBACKS * WL_OBJECT_TYPE_COUNT dq 0

section .bss
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

    ; static wire_reused_ids: [u32; WIRE_MAX_N_OBJECTS]
    wire_reused_ids                       resd WIRE_MAX_N_OBJECTS

    ; static wire_message: [u32; 512]
    wire_message                          resd WIRE_MAX_MESSAGE_LEN
