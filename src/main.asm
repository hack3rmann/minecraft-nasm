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

section .text

; #[systemv]
; fn main() -> i64
main:
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
    jmp .end_loop
        ; read_event()
        call read_event

        ; let (object_id := rdi) = message.object_id
        xor rdi, rdi
        mov edi, dword [message + WireMessage.object_id]
        DEBUG_HEX rdi

        ; let (opcode := rsi) = message.opcode
        movzx rsi, word [message + WireMessage.opcode]

        ; if object_id == wire_id.wl_callback
        ;     && opcode == wire_event.callback_done_opcode
        ; { break }
        xor rax, rax
        cmp rdi, wire_id.wl_callback
        sete ah
        cmp rsi, wire_event.callback_done_opcode
        sete al
        test al, ah
        jnz .end_loop

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

    ; message.body.id = wire_id.wl_registry
    mov dword [message + WireMessage.body + 0], wire_id.wl_registry

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
