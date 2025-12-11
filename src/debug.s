%ifndef _DEBUG_INC
%define _DEBUG_INC

%macro DEBUG_HEX 1
    PUSHA

    ; in case we care about `rsp`
    add rsp, 8 * N_PUSHAS
    mov rdi, %1
    sub rsp, 8 * N_PUSHAS

    call print_uint_hex

    POPA
%endmacro

%macro DEBUG_UINT 1
    PUSHA

    ; in case we care about `rsp`
    add rsp, 8 * N_PUSHAS
    mov rdi, %1
    sub rsp, 8 * N_PUSHAS

    call print_uint
    call print_newline

    POPA
%endmacro

%macro DEBUG_INT 1
    PUSHA

    ; in case we care about `rsp`
    add rsp, 8 * N_PUSHAS
    mov rdi, %1
    sub rsp, 8 * N_PUSHAS

    call print_int
    call print_newline

    POPA
%endmacro

%macro DEBUG_I32X4 1
    PUSHA

    sub rsp, 32
    vmovups [rsp], xmm0
    
    vmovaps xmm0, %1
    call print_i32x4

    vmovups xmm0, [rsp]
    add rsp, 32

    POPA
%endmacro

%macro DEBUG_STR 2
    PUSHA
    
    ; write(STDERR, str.ptr, str.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDERR
    mov rsi, %2
    mov rdx, %1
    syscall

    call print_newline

    POPA
%endmacro

; macro DEBUG_CSTR(cstr: *mut u8)
%macro DEBUG_CSTR 1
%push
    PUSHA

    ; if cstr == null { return }
    mov rax, %1
    test rax, rax
    jz %$.exit

    ; let (len := rdx) = cstr_len(cstr)
    mov rsi, %1
    call cstr_len

    ; write(STDOUT, cstr, len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, %1
    syscall

    ; print_newline()
    call print_newline

    %$.exit:

    POPA
%push
%endmacro

%macro DEBUG_NEWLINE 0
    PUSHA
    call print_newline
    POPA
%endmacro

%macro DEBUG_STR_INLINE 1
%push
%push
    section .rodata
        %$str     db %1
        %$str.len equ $ - %$str

    section .text
        DEBUG_STR %$str.len, %$str
%pop
%pop
%endmacro

STDIN                        equ 0
STDOUT                       equ 1
STDERR                       equ 2
LF                           equ 10

extern newline

extern format_buffer

extern format_init, format_uninit

extern print_uint_hex, print_uint, print_int, print_newline, print_i32x4

%endif ; !_DEBUG_INC
