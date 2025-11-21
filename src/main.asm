%include "syscall.s"
%include "error.s"
%include "memory.s"
%include "debug.s"
%include "string.s"
%include "env.s"
%include "wire.s"

section .rodata
    addr:
        .sun_family              dw AF_UNIX
        .sun_path                db "/run/user/1000/wayland-1"
    addr_len                     equ $-addr

    display_error_string         db "wayland error: "
    display_error_string.len     equ $-display_error_string

    global_string1               db "RegistryGlobal {", LF, "    name: "
    global_string1.len           equ $-global_string1
    global_string2               db ",", LF, "    interface: '"
    global_string2.len           equ $-global_string2
    global_string3               db "',", LF, "    version: "
    global_string3.len           equ $-global_string3
    global_string4               db ",", LF, "}", LF
    global_string4.len           equ $-global_string4

struc DisplayError
    .object_id      resd 1
    .code           resd 1
    .message.len    resd 1
    .message        resb 0
    .sizeof         equ $-.object_id
endstruc

struc RegistryGlobal
    .name           resd 1
    .interface.len  resd 1
    .interface      resb 0
    .version        resd 0
    .sizeof         equ $-.name
endstruc

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

    ; static message: [u32; 512]
    message resd 512
    ; static last_id: u32
    last_id resd 1
    string resb String.sizeof

section .text

; #[systemv]
; fn main() -> i64
main:
    ; string = String::new()
    mov rdi, string
    call String_new

    mov rdi, string
    mov rsi, "H"
    call String_push_ascii

    mov rdi, string
    mov rsi, "e"
    call String_push_ascii

    mov rdi, string
    mov rsi, "l"
    call String_push_ascii

    mov rdi, string
    mov rsi, "l"
    call String_push_ascii

    mov rdi, string
    mov rsi, "o"
    call String_push_ascii

    mov rdi, string
    mov rsi, ","
    call String_push_ascii

    mov rdi, string
    mov rsi, " "
    call String_push_ascii

    mov rdi, string
    mov rsi, "W"
    call String_push_ascii

    mov rdi, string
    mov rsi, "o"
    call String_push_ascii

    mov rdi, string
    mov rsi, "r"
    call String_push_ascii

    mov rdi, string
    mov rsi, "l"
    call String_push_ascii

    mov rdi, string
    mov rsi, "d"
    call String_push_ascii

    mov rdi, string
    mov rsi, "!"
    call String_push_ascii

    mov rdi, string
    mov rsi, LF
    call String_push_ascii

    mov rdi, string
    mov rsi, "H"
    call String_push_ascii

    mov rdi, string
    mov rsi, "e"
    call String_push_ascii

    mov rdi, string
    mov rsi, "l"
    call String_push_ascii

    mov rdi, string
    mov rsi, "l"
    call String_push_ascii

    mov rdi, string
    mov rsi, "o"
    call String_push_ascii

    mov rdi, string
    mov rsi, ","
    call String_push_ascii

    mov rdi, string
    mov rsi, " "
    call String_push_ascii

    mov rdi, string
    mov rsi, "W"
    call String_push_ascii

    mov rdi, string
    mov rsi, "o"
    call String_push_ascii

    mov rdi, string
    mov rsi, "r"
    call String_push_ascii

    mov rdi, string
    mov rsi, "l"
    call String_push_ascii

    mov rdi, string
    mov rsi, "d"
    call String_push_ascii

    mov rdi, string
    mov rsi, "!"
    call String_push_ascii

    mov rdi, string
    mov rsi, LF
    call String_push_ascii

    ; write(STDOUT, string.ptr, string.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, qword [string + String.ptr]
    mov rdx, qword [string + String.len]
    syscall
    call exit_on_error

    ; drop(string)
    mov rdi, string
    call String_drop

    ret

    ; display_fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0)
    mov rax, SYSCALL_SOCKET
    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM | SOCK_CLOEXEC
    xor rdx, rdx
    syscall
    call exit_on_error
    mov qword [display_fd], rax

    ; connect(display_fd, &const addr, addr_len)
    mov rax, SYSCALL_CONNECT
    mov rdi, qword [display_fd]
    mov rsi, addr
    mov rdx, addr_len
    syscall
    call exit_on_error

    ; message.object_id = wire_id.wl_display
    mov dword [message + WireMessage.object_id], wire_id.wl_display

    ; message.opcode = wire_request.get_registry_opcode
    mov word [message + WireMessage.opcode], wire_request.display_get_registry_opcode

    ; message.size = WireMessage::HEADER_SIZE + 4
    .message_size equ WireMessage.HEADER_SIZE + 4
    mov word [message + WireMessage.size], .message_size

    ; message.body.id = wire_id.wl_registry
    mov dword [message + WireMessage.body + 0], wire_id.wl_registry

    ; last_id = wire_id.wl_registry
    mov dword [last_id], wire_id.wl_registry

    ; let (n_bytes := rax) = write(display_fd, &message, message.size)
    mov rax, SYSCALL_WRITE
    mov rdi, qword [display_fd]
    mov rsi, message
    mov rdx, .message_size
    syscall
    call exit_on_error

    ; assert n_bytes == message.size
    cmp rax, .message_size
    jne abort

    ; send_sync()
    call send_sync

    ; loop {
    .loop:
        ; read_event()
        call read_event

        ; let (event_size := rdi) = message.size
        movzx rdi, word [message + WireMessage.size]

        ; let (object_id := rdi) = message.object_id
        xor rdi, rdi
        mov edi, dword [message + WireMessage.object_id]

        ; let (opcode := rsi) = message.opcode
        movzx rsi, word [message + WireMessage.opcode]

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
        ; if event_id == (wire_id.wl_callback << 16) | wire_event.callback_done_opcode
        ; { break }
        cmp rdi, (wire_id.wl_callback << 16) | wire_event.callback_done_opcode
        je .end_loop

    ; }
    jmp .loop
    .end_loop:

    ; close(fd)
    mov rax, SYSCALL_CLOSE
    mov rdi, qword [display_fd]
    syscall
    call exit_on_error

    ; return EXIT_SUCCESS
    xor rax, rax
    ret

; #[systemv]
; fn handle_registry_global()
handle_registry_global:
    ; write(STDOUT, global_string1, global_string1.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, global_string1
    mov rdx, global_string1.len
    syscall

    ; let (name := rdi) = message.body.name
    xor rdi, rdi
    mov edi, dword [message + WireMessage.body + RegistryGlobal.name]
    call print_uint

    ; write(STDOUT, global_string2, global_string2.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, global_string2
    mov rdx, global_string2.len
    syscall

    ; let (interface := rsi) = &message.body.interface
    mov rsi, message + WireMessage.body + RegistryGlobal.interface

    ; let (interface_size := r8) = message.body.interface.len
    xor rax, rax
    mov eax, dword [message + WireMessage.body + RegistryGlobal.interface.len]
    mov r8, rax

    ; // remove null terminator
    ; let (interface_len := rdi) = interface_size - 1
    lea rdx, [r8 - 1]

    ; write(STDOUT, interface, interface_len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    ; mov rsi, rsi
    ; mov rdx, rdx
    syscall

    ; write(STDOUT, global_string3, global_string3.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, global_string3
    mov rdx, global_string3.len
    syscall

    ; let (string_block_size := r8) = (interface_len + 3) / 4
    add r8, 3
    shr r8, 2

    ; let (version := rdi) = message.body.version
    xor rdi, rdi
    mov edi, dword [message + WireMessage.body + RegistryGlobal.sizeof + 4*r8]
    call print_uint

    ; write(STDOUT, global_string4, global_string4.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, global_string4
    mov rdx, global_string4.len
    syscall

    ret

; #[jumpable]
; #[noreturn]
; fn handle_display_error()
handle_display_error:
    ; write(STDOUT, display_error_string, display_error_string.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, display_error_string
    mov rdx, display_error_string.len
    syscall

    ; let (error_message := rsi) = &message.body.message
    mov rsi, message + WireMessage.body + DisplayError.message

    ; let (error_message_len := rdx) = message.body.message.len
    xor rdx, rdx
    mov edx, dword [message + WireMessage.body + DisplayError.message.len]

    ; write(STDOUT, error_message, error_message_len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    ; mov rsi, rsi
    ; mov rdx, rdx
    syscall

    ; write(STDOUT, &newline, 1)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, newline
    mov rdx, 1
    syscall

    ; abort()
    jmp abort

; #[systemv]
; fn read_event()
read_event:
    ; let (n_read := rax) = read(display_fd, &message, WireMessage::HEADER_SIZE)
    mov rax, SYSCALL_READ
    mov rdi, qword [display_fd]
    mov rsi, message
    mov rdx, WireMessage.HEADER_SIZE
    syscall
    call exit_on_error

    ; assert n_read == WireMessage::HEADER_SIZE
    cmp rax, WireMessage.HEADER_SIZE
    jne abort

    ; let (body_size := rdx) = message.size
    movzx rdx, word [message + WireMessage.size]

    ; body_size -= WireMessage::HEADER_SIZE
    sub rdx, WireMessage.HEADER_SIZE

    ; let (n_read := rax) = read(display_fd, &message + WireMessage::HEADER_SIZE, body_size)
    mov rax, SYSCALL_READ
    mov rdi, qword [display_fd]
    mov rsi, message + WireMessage.HEADER_SIZE
    ; mov rdx, rdx
    syscall
    call exit_on_error

    ; assert n_read == body_size
    cmp rax, rdx
    jne abort

    ret

; #[systemv]
; fn send_sync()
send_sync:
    ; message.object_id = wire_id.wl_display
    mov dword [message + WireMessage.object_id], wire_id.wl_display

    ; message.opcode = wire_request.display_sync
    mov word [message + WireMessage.opcode], wire_request.display_sync_opcode

    ; message.size = WireMessage::HEADER_SIZE + 4
    .message_size equ WireMessage.HEADER_SIZE + 4
    mov word [message + WireMessage.size], .message_size

    ; message.body.id = wire_id.wl_callback
    mov dword [message + WireMessage.body + 0], wire_id.wl_callback

    ; last_id = wire_id.wl_callback
    mov dword [last_id], wire_id.wl_callback

    ; let (n_bytes := rax) = write(display_fd, &message, message.size)
    mov rax, SYSCALL_WRITE
    mov rdi, qword [display_fd]
    mov rsi, message
    mov rdx, .message_size
    syscall
    call exit_on_error

    ; assert n_bytes == message.size
    cmp rax, .message_size
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
