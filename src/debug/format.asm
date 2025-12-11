%include "../debug.s"
%include "../string.s"
%include "../function.s"

section .bss
    align 8
    format_buffer resb String.sizeof

section .text

; #[systemv]
; fn format_init()
FN format_init
    ; format_buffer = String::new()
    mov rdi, format_buffer
    call String_new
END_FN

; #[systemv]
; fn format_uninit()
FN format_uninit
    ; drop(format_buffer)
    mov rdi, format_buffer
    call String_drop
END_FN
