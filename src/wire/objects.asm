%include "../syscall.s"
%include "../string.s"
%include "../wire.s"
%include "../debug.s"
%include "../function.s"

struc WlObjectNameMap
    .type           resb 1
    .name_len       resb 1
    .name           resb 256-2
    .sizeof         equ $-.type
endstruc

section .rodata
    %assign WL_N_NAMES 0

    align WlObjectNameMap.sizeof

    wl_names:

    %assign WL_N_NAMES WL_N_NAMES+1
    wl_object_name_display:
             db WL_OBJECT_TYPE_DISPLAY
             db wl_object_name_display.len
        .ptr db "wl_display"
        .len equ $-wl_object_name_display.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_registry:
             db WL_OBJECT_TYPE_REGISTRY
             db wl_object_name_registry.len
        .ptr db "wl_registry"
        .len equ $-wl_object_name_registry.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_compositor:
             db WL_OBJECT_TYPE_COMPOSITOR
             db wl_object_name_compositor.len
        .ptr db "wl_compositor"
        .len equ $-wl_object_name_compositor.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_shm:
             db WL_OBJECT_TYPE_SHM
             db wl_object_name_shm.len
        .ptr db "wl_shm"
        .len equ $-wl_object_name_shm.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_shm_pool:
             db WL_OBJECT_TYPE_SHM_POOL
             db wl_object_name_shm_pool.len
        .ptr db "wl_shm_pool"
        .len equ $-wl_object_name_shm_pool.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_wm_base:
             db WL_OBJECT_TYPE_WM_BASE
             db wl_object_name_wm_base.len
        .ptr db "xdg_wm_base"
        .len equ $-wl_object_name_wm_base.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_surface:
             db WL_OBJECT_TYPE_SURFACE
             db wl_object_name_surface.len
        .ptr db "wl_surface"
        .len equ $-wl_object_name_surface.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_xdg_surface:
             db WL_OBJECT_TYPE_XDG_SURFACE
             db wl_object_name_xdg_surface.len
        .ptr db "xdg_surface"
        .len equ $-wl_object_name_xdg_surface.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_xdg_toplevel:
             db WL_OBJECT_TYPE_TOPLEVEL
             db wl_object_name_xdg_toplevel.len
        .ptr db "xdg_toplevel"
        .len equ $-wl_object_name_xdg_toplevel.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_buffer:
             db WL_OBJECT_TYPE_BUFFER
             db wl_object_name_buffer.len
        .ptr db "wl_buffer"
        .len equ $-wl_object_name_buffer.ptr

    %assign WL_N_NAMES WL_N_NAMES+1
             align WlObjectNameMap.sizeof
    wl_object_name_callback:
             db WL_OBJECT_TYPE_CALLBACK
             db wl_object_name_callback.len
        .ptr db "wl_callback"
        .len equ $-wl_object_name_callback.ptr

section .text

; #[systemv]
; fn wire_init()
FN wire_init
    ; for i in 0..WIRE_MAX_N_OBJECTS {
    %assign i 0
    %rep WIRE_MAX_N_OBJECTS

        ; wire_all_objects[i] = RegistryGlobal::new()
        mov rdi, wire_all_objects + i * RegistryGlobal.sizeof
        call RegistryGlobal_new

    ; }
    %assign i i+1
    %endrep

    ; wire_object_types[wire_id.wl_display] = WlObjectType::Display
    mov byte [wire_object_types + wire_id.wl_display], WL_OBJECT_TYPE_DISPLAY

    ; wire_object_types[wire_id.wl_registry] = WlObjectType::Registry
    mov byte [wire_object_types + wire_id.wl_registry], WL_OBJECT_TYPE_REGISTRY

    ; wire_set_dispatcher(
    ;     WlObjectType::Display,
    ;     wire_event.display_error_opcode
    ;     wire_handle_display_error)
    mov rdi, WL_OBJECT_TYPE_DISPLAY
    mov rsi, wire_event.display_error_opcode
    mov rdx, wire_handle_display_error
    call wire_set_dispatcher

    ; wire_set_dispatcher(
    ;     WlObjectType::Display,
    ;     wire_event.display_delete_id_opcode,
    ;     wire_handle_delete_id)
    mov rdi, WL_OBJECT_TYPE_DISPLAY
    mov rsi, wire_event.display_delete_id_opcode
    mov rdx, wire_handle_delete_id
    call wire_set_dispatcher
END_FN

; #[systemv]
; fn wire_deinit()
FN wire_deinit
    ; for i in 0..WIRE_MAX_N_OBJECTS {
    %assign i 0
    %rep WIRE_MAX_N_OBJECTS

        ; drop(wire_all_objects[i])
        mov rdi, wire_all_objects + i * RegistryGlobal.sizeof
        call RegistryGlobal_drop

    ; }
    %assign i i+1
    %endrep
END_FN

; fn RegistryGlobal::new(($ret := rdi): *mut Self) -> Self
FN RegistryGlobal_new
    ; $ret->name = 0
    mov dword [rdi + RegistryGlobal.name], 0

    ; $ret->version = 0
    mov dword [rdi + RegistryGlobal.version], 0

    ; $ret->interface = String::new()
    lea rdi, [rdi + RegistryGlobal.interface]
    call String_new
END_FN

; fn RegistryGlobal::drop(&mut self := rdi)
FN RegistryGlobal_drop
    PUSH r12

    ; let (self := r12) = self
    mov r12, rdi

    ; drop(self.interface)
    lea rdi, [r12 + RegistryGlobal.interface]
    call String_drop

    ; *self = RegistryGlobal::new()
    mov rdi, r12
    call RegistryGlobal_new
END_FN r12

; fn WlObjectType::from_str((src := rdi:rsi): Str) -> WlObjectType := al
FN WlObjectType_from_str
    PUSH r12, r13

    ; let (src := r12:r13) = src
    mov r12, rdi
    mov r13, rsi

    ; for i in 0..WL_N_NAMES {
    %assign i 0
    %rep WL_N_NAMES

        ; let (type := r8b) = wl_names[i].type
        xor r8, r8
        mov r8b, byte [wl_names + WlObjectNameMap.sizeof * i + WlObjectNameMap.type]

        ; if src == wl_names[i].name { return type }
        mov rdi, r12
        mov rsi, r13
        xor rdx, rdx
        mov dl, byte [wl_names + WlObjectNameMap.sizeof * i + WlObjectNameMap.name_len]
        mov rcx, wl_names + WlObjectNameMap.sizeof * i + WlObjectNameMap.name
        call Str_eq
        test al, al
        mov al, r8b
        jnz .exit

    ; }
    %assign i i+1
    %endrep

    ; return WlObjectType::Invalid
    mov al, WL_OBJECT_TYPE_INVALID

    .exit:
END_FN r13, r12
