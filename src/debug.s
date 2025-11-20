%ifndef _DEBUG_INC
%define _DEBUG_INC

%macro DEBUG_HEX 1
    pushf
    push rax
    push rcx
    push rdx
    push rbx
    push rsp
    push rbp
    push rsi
    push rdi

    ; in case we are about to print `rsp`
    add rsp, 8*9
    mov rdi, %1
    sub rsp, 8*9

    call print_uint_hex

    pop rdi
    pop rsi
    pop rbp
    pop rsp
    pop rbx
    pop rdx
    pop rcx
    pop rax
    popf
%endmacro

STDIN                        equ 0
STDOUT                       equ 1
STDERR                       equ 2
LF                           equ 10

extern print_uint_hex

%endif ; !_DEBUG_INC
