%include "../debug.s"
%include "../string.s"

section .bss
    align 8
    format_buffer resb String.sizeof

section .text

; #[systemv]
; fn init_format()
init_format:
    ; format_buffer = String::new()
    mov rdi, format_buffer
    call String_new

    ret

; #[systemv]
; fn deinit_format()
deinit_format:
    ; drop(format_buffer)
    mov rdi, format_buffer
    call String_drop

    ret
