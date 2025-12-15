%include "../string.s"
%include "../debug.s"
%include "../syscall.s"
%include "../error.s"
%include "../function.s"
%include "../panic.s"

section .rodata
    STR arg_type_usize, "usize"
    STR arg_type_isize, "isize"
    STR arg_type_str, "str"
    STR arg_type_cstr, "cstr"

section .text

; #[continuous = range(0..4)]
; enum ArgType
%define ARGTYPE_USIZE   0
%define ARGTYPE_ISIZE   1
%define ARGTYPE_STR     2
%define ARGTYPE_CSTR    3
%define ARGTYPE_INVALID 0xFF

; {usize}
; {isize}
; {usize:h}?
; {isize:h}?
; {str}
; {cstr}
; {{}}

; #[systemv]
; fn parse_arg_type(Str { len := rdi, ptr := rsi }) -> ArgType := al
FN! parse_arg_type
    PUSH r12, r13

    ; let (len := r12) = len
    mov r12, rdi

    ; let (ptr := r13) = ptr
    mov r13, rsi

    ; if value == "usize" { return ArgType::Usize }
    mov rdi, r12
    mov rsi, r13
    mov rdx, arg_type_usize.len
    mov rcx, arg_type_usize.ptr
    call Str_eq
    test al, al
    mov al, ARGTYPE_USIZE
    jnz .exit

    ; if value == "isize" { return ArgType::Isize }
    mov rdi, r12
    mov rsi, r13
    mov rdx, arg_type_isize.len
    mov rcx, arg_type_isize.ptr
    call Str_eq
    test al, al
    mov al, ARGTYPE_ISIZE
    jnz .exit

    ; if value == "str" { return ArgType::Str }
    mov rdi, r12
    mov rsi, r13
    mov rdx, arg_type_str.len
    mov rcx, arg_type_str.ptr
    call Str_eq
    test al, al
    mov al, ARGTYPE_STR
    jnz .exit

    ; if value == "cstr" { return ArgType::Cstr }
    mov rdi, r12
    mov rsi, r13
    mov rdx, arg_type_cstr.len
    mov rcx, arg_type_cstr.ptr
    call Str_eq
    test al, al
    mov al, ARGTYPE_CSTR
    jnz .exit

    ; return ArgType::Invalid
    mov al, ARGTYPE_INVALID

    .exit:
END_FN r13, r12

; /// Parses until first `({|})`
; #[systemv]
; fn parse_raw_string(Str { len := rdi, ptr := rsi }) -> usize := rax
FN! parse_raw_string
    ; let (i := rax) = 0
    xor rax, rax

    ; while i < len {
    .while:
    cmp rax, rdi
    jae .end_while

        ; if ptr[i] == b'{' { break }
        cmp byte [rsi + rax], "{"
        je .end_while

        ; if ptr[i] == b'}' { break }
        cmp byte [rsi + rax], "}"
        je .end_while

        ; i += 1
        inc rax

    ; }
    jmp .while
    .end_while:

    ; return i
END_FN

; /// Parses first `({{|}})`
; #[systemv]
; fn parse_arg_escape(Str { len := rdi, ptr := rsi }) -> usize := rax
FN! parse_arg_escape
    ; let (result := rax) = 0
    xor rax, rax

    ; if len < 2 { return 0 }
    cmp rdi, 2
    jb .exit

    ; result = 2
    mov rax, 2

    ; if ptr[0..2] == b"{{" { return 2 }
    cmp word [rsi], "{{"
    je .exit

    ; if ptr[0..2] == b"}}" { return 2 }
    cmp word [rsi], "}}"
    je .exit

    ; return 0
    mov rax, 0

    .exit:
END_FN

; /// Parses first `{.*}`
; #[systemv]
; fn parse_arg_string(Str { len := rdi, ptr := rsi }) -> usize := rax
FN! parse_arg_string
    ; let (result := rax) = 0
    xor rax, rax

    ; if len < 2 { return 0 }
    cmp rdi, 2
    jb .exit

    ; if ptr[0] != b'{' { return 0 }
    cmp byte [rsi], "{"
    jne .exit

    ; let (i := rax) = 1
    inc rax

    ; while i < len {
    .while:
    cmp rax, rdi
    jae .end_while

        ; if i + 1 < len && ptr[i..=i + 1] == b"}}" {
        lea rdx, [rax + 1]
        cmp rdx, rdi
        jae .end_if
        cmp word [rsi + rax], "}}"
        jne .end_if

            ; i += 2
            add rax, 2

            ; continue
            jmp .while

        ; }
        .end_if:

        ; if ptr[i] == b'}' { break }
        cmp byte [rsi + rax], "}"
        je .end_while

        ; i += 1
        inc rax

    ; }
    jmp .while
    .end_while:

    ; if ptr[i] != b'}' { return 0 }
    xor rdx, rdx
    cmp byte [rsi + rax], "}"
    cmovne rax, rdx
    jne .exit

    ; return i + 1
    inc rax

    .exit:
END_FN

; #[systemv]
; fn String::format_once(
;     &mut self := rdi,
;     (arg_type := rsi): ArgType,
;     (args := rdx): *mut usize,
; ) -> usize := rax
FN! String_format_once
    PUSH r12, r13, r14

    ; let (self := r12) = self
    mov r12, rdi

    ; let (arg_type := r13) = arg_type
    mov r13, rsi

    ; let (args := r14) = args
    mov r14, rdx

    ; if arg_type == ArgType::Usize {
    cmp r13, ARGTYPE_USIZE
    jne .else_if_isize

        ; self.format_u64(args[0])
        mov rdi, r12
        mov rsi, qword [r14]
        call String_format_u64

        ; return 1
        mov rax, 1
        jmp .exit

    ; } else if arg_type == ArgType::Isize {
    jmp .end_if
    .else_if_isize:
    cmp r13, ARGTYPE_ISIZE
    jne .else_if_str

        ; self.format_i64(args[0])
        mov rdi, r12
        mov rsi, qword [r14]
        call String_format_i64

        ; return 1
        mov rax, 1
        jmp .exit

    ; } else if arg_type == ArgType::Str {
    jmp .end_if
    .else_if_str:
    cmp r13, ARGTYPE_STR
    jne .else_if_cstr

        ; self.push_str(args[0], args[1])
        mov rdi, r12
        mov rsi, qword [r14 + 0]
        mov rdx, qword [r14 + 8]
        call String_push_str

        ; return 2
        mov rax, 2
        jmp .exit

    ; } else if arg_type == ArgType::Cstr {
    jmp .end_if
    .else_if_cstr:
    cmp r13, ARGTYPE_CSTR
    jne .else

        ; self.push_cstr(args[0])
        mov rdi, r12
        mov rsi, qword [r14]
        call String_push_cstr

        ; return 1
        mov rax, 1
        jmp .exit

    ; } else {
    jmp .end_if
    .else:

        ; abort()
        call abort

    ; }
    .end_if:

    ; return 0
    xor rax, rax

    .exit:
END_FN r14, r13, r12

; #[systemv]
; fn String::format_array(
;     &mut self := rdi,
;     Str { fmt.len := rsi, fmt.ptr := rdx }: Str,
;     (args := rcx): *mut usize,
; )
FN! String_format_array
    PUSH r12, r13, r14, r15, rbx

    ; let (self := r12) = self
    mov r12, rdi

    ; let (fmt.len := r13) = fmt.len
    mov r13, rsi

    ; let (fmt.ptr := r14) = fmt.ptr
    mov r14, rdx

    ; let (args := r15) = args
    mov r15, rcx

    ; while (fmt.len as isize) >= 0 {
    .while:
    cmp r13, 0
    jl .end_while

        ; let (parse_len := rbx) = parse_raw_string(fmt)
        mov rdi, r13
        mov rsi, r14
        call parse_raw_string
        mov rbx, rax
        
        ; if parse_len != 0 {
        test rbx, rbx
        jz .end_raw_if

            ; self.push_str(fmt[..parse_len])
            mov rdi, r12
            mov rsi, rbx
            mov rdx, r14
            call String_push_str

            ; fmt = fmt[parse_len..]
            sub r13, rbx
            add r14, rbx

            ; continue
            jmp .while

        ; }
        .end_raw_if:

        ; let (parse_len := rbx) = parse_arg_escape(fmt)
        mov rdi, r13
        mov rsi, r14
        call parse_arg_escape
        mov rbx, rax

        ; if parse_len != 0 {
        test rbx, rbx
        jz .end_escape_if

            ; self.push_ascii(*fmt.ptr)
            mov rdi, r12
            mov al, byte [r14]
            movzx rsi, al
            call String_push_ascii

            ; fmt = fmt[parse_len..]
            sub r13, rbx
            add r14, rbx

            ; continue
            jmp .while

        ; }
        .end_escape_if:

        ; let (parse_len := rbx) = parse_arg_string(fmt)
        mov rdi, r13
        mov rsi, r14
        call parse_arg_string
        mov rbx, rax

        ; if parse_len != 0 {
        test rbx, rbx
        jz .end_arg_if

            ; let (arg_type := al) = parse_arg_type(Str { fmt.len - 2, fmt.ptr + 1 })
            lea rdi, [rbx - 2]
            lea rsi, [r14 + 1]
            call parse_arg_type

            ; assert arg_type != ArgType::Invalid
            cmp al, ARGTYPE_INVALID
            je panic

            ; let (n_args := rax) = self.format_once(arg_type, args)
            mov rdi, r12
            movzx rsi, al
            mov rdx, r15
            call String_format_once

            ; args += n_args
            lea r15, [r15 + 8*rax]

            ; fmt = fmt[parse_len..]
            sub r13, rbx
            add r14, rbx

            ; continue
            jmp .while

        ; }
        .end_arg_if:

        jmp .exit

    ; }
    jmp .while
    .end_while:

    .exit:
END_FN rbx, r15, r14, r13, r12
