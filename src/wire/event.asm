%include "../syscall.s"
%include "../string.s"
%include "../wire.s"
%include "../debug.s"
%include "../error.s"
%include "../memory.s"
%include "../function.s"
%include "../panic.s"

section .rodata
    display_error_fmt.ptr         db "wayland error: WlDisplayError {{ ", \
                                     "object_id: {usize}, ", \
                                     "code: {usize}, ", \
                                     "message: '{str}' }}", LF
    display_error_fmt.len         equ $-display_error_fmt.ptr

section .text

; #[systemv]
; fn wire_read_event((display_fd := rdi): Fd)
FN wire_read_event
    PUSH r12

    ; let (display_fd := r12) = display_fd
    mov r12, rdi

    ; let (n_read := rax) = read(display_fd, &wire_message, WireMessageHeader::HEADER_SIZE)
    mov rax, SYSCALL_READ
    mov rdi, r12
    mov rsi, wire_message
    mov rdx, WireMessageHeader.sizeof
    syscall
    call exit_on_error

    ; assert n_read == WireMessageHeader::HEADER_SIZE
    cmp rax, WireMessageHeader.sizeof
    jne panic

    ; let (body_size := rdx) = wire_message.size - WireMessageHeader::HEADER_SIZE
    movzx rdx, word [wire_message + WireMessageHeader.size]
    sub rdx, WireMessageHeader.sizeof

    ; if body_size != 0 {
    test rdx, rdx
    jz .end_if

        ; let (n_read := rax) = read(display_fd, &wire_message + WireMessageHeader::HEADER_SIZE, body_size)
        mov rax, SYSCALL_READ
        mov rdi, r12
        mov rsi, wire_message + WireMessageHeader.sizeof
        ; mov rdx, rdx
        syscall
        call exit_on_error

        ; assert n_read == body_size
        cmp rax, rdx
        jne panic

    ; }
    .end_if:
END_FN r12

; #[systemv]
; fn wire_dispatch_event()
FN wire_dispatch_event
    PUSH r12

    ; let (object_id := r12) = wire_message.object_id
    xor r12, r12
    mov r12d, dword [wire_message + WireMessageHeader.object_id]

    ; let (dispatch := rax) = wire_get_dispatcher(
    ;     wire_object_types[object_id],
    ;     wire_message.opcode)
    movzx rdi, byte [wire_object_types + r12]
    movzx rsi, word [wire_message + WireMessageHeader.opcode]
    call wire_get_dispatcher

    movzx r8, byte [wire_object_types + r12]
    movzx r9, word [wire_message + WireMessageHeader.opcode]

    ; if dispatch == null { return }
    test rax, rax
    jz .exit

    ; dispatch(object_id)
    mov rdi, r12
    call rax

    .exit:
END_FN r12

; #[systemv]
; fn wire_display_roundtrip((display_fd := rdi): Fd)
FN wire_display_roundtrip
    PUSH r12, r13

    ; mov (display_fd := r12) = display_fd
    mov r12, rdi

    ; let (callback_id := r13) = wire_send_display_sync()
    call wire_send_display_sync
    mov r13, rax

    ; wire_flush(display_fd)
    mov rdi, r12
    call wire_flush

    ; loop {
    .loop:
        ; wire_read_event(display_fd)
        mov rdi, r12
        call wire_read_event

        ; let (object_id := rdi) = wire_message.object_id
        xor rdi, rdi
        mov edi, dword [wire_message + WireMessageHeader.object_id]

        ; let (opcode := rsi) = wire_message.opcode
        movzx rsi, word [wire_message + WireMessageHeader.opcode]

        ; if object_id == callback_id && opcode == wire_event.callback_done_opcode
        ; { break }
        cmp rdi, r13
        sete ah
        cmp rsi, wire_event.callback_done_opcode
        sete al
        test ah, al
        jnz .end_loop

        ; wire_dispatch_event()
        call wire_dispatch_event

    ; }
    jmp .loop
    .end_loop:
END_FN r13, r12

; #[systemv]
; fn wire_set_dispatcher(
;     (type := rdi): WlObjectType,
;     (opcode := rsi): u32,
;     (dispatch := rdx): fn(u32),
; )
FN wire_set_dispatcher
    ; wire_callbacks[type][opcode] = dispatch
    mov rax, rdi
    shl rax, WIRE_MAX_N_CALLBACKS_LOG2
    mov qword [wire_callbacks + rax + 8 * rsi], rdx
END_FN

; #[systemv]
; fn wire_get_dispatcher((type := rdi): WlObjectType, (opcode := rsi): u32) -> fn(u32) := rax
FN wire_get_dispatcher
    ; wire_callbacks[type][opcode] = dispatch
    mov rax, rdi
    shl rax, WIRE_MAX_N_CALLBACKS_LOG2
    mov rax, qword [wire_callbacks + rax + 8 * rsi]
END_FN

; #[jumpable]
; #[noreturn]
; fn wire_handle_display_error((_display_id := rdi): u32)
FN wire_handle_display_error
    ; let fmt_args: struct {
    LOCAL .fmt_args, 32

    ;     object_id: usize,
    .object_id      equ .fmt_args

    ;     code: usize
    .code           equ .fmt_args + 8

    ;     message: Str,
    .message.len    equ .fmt_args + 16
    .message.ptr    equ .fmt_args + 24

    ; }
    ALLOC_STACK

    ; message.ptr = &wire_message.body.message
    mov qword [rbp + .message.ptr], \
        wire_message + WireMessageHeader.sizeof + DisplayErrorEvent.message

    ; message.len = wire_message.body.message.len as usize
    xor rax, rax
    mov eax, dword [wire_message + WireMessageHeader.sizeof + DisplayErrorEvent.message.len]
    mov qword [rbp + .message.len], rax

    ; object_id = wire_message.body.object_id
    xor rax, rax
    mov eax, dword [wire_message + WireMessageHeader.sizeof + DisplayErrorEvent.object_id]
    mov qword [rbp + .object_id], rax

    ; code = wire_message.body.code
    xor rax, rax
    mov eax, dword [wire_message + WireMessageHeader.sizeof + DisplayErrorEvent.code]
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
    jmp panic
END_FN

; #[systemv]
; fn wire_handle_delete_id((_display_id := rdi): u32)
FN wire_handle_delete_id
    ; wire_release_id(wire_message.body.id)
    xor rdi, rdi
    mov edi, dword [wire_message + WireMessageHeader.sizeof + DisplayDeleteIdEvent.id]
    call wire_release_id
END_FN
