section .bss
    wire_id:
        .wl_display                       equ 1
        .wl_registry                      equ 2
        .wl_callback                      equ 3

    wire_request:
        .display_sync_opcode              equ 0
        .display_get_registry_opcode      equ 1

    wire_event:
        .display_error_opcode             equ 0
        .callback_done_opcode             equ 0
        .registry_global_opcode           equ 0

struc WireMessage
    ; object_id: u32
    .object_id                    resd 1
    ; opcode: u16
    .opcode                       resw 1
    ; size: u16
    .size                         resw 1
    ; body: [u32]
    .body                         equ $-.object_id
    .HEADER_SIZE                  equ .body
endstruc
