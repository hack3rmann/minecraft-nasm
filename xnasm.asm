%define SYSCALL_READ   0
%define SYSCALL_WRITE  1
%define SYSCALL_MMAP   9
%define SYSCALL_MUNMAP 11
%define SYSCALL_GETPID 39
%define SYSCALL_EXIT   60
%define SYSCALL_KILL   62

%define PROT_READ      1
%define PROT_WRITE     2
%define MAP_ANONYMOUS  0x0020
%define MAP_FAILED     0xFFFFFFFFFFFFFFFF
%define MAP_PRIVATE    0x0002
%define MMAP_PAGE_SIZE 4096

%define SIGABRT        6

%define EXIT_FAILURE   1

%define STDIN          0
%define STDOUT         1
%define STDERR         2

%define TAB 9
%define LF 10
%define CR 13

%define READ_LEN       MMAP_PAGE_SIZE

%define ALIGNED(n_bytes) (n_bytes + (8 - (n_bytes % 8)) % 8)

struc StringBuffer
    .len          resq 1
                  resb 32-8 ; padding
    .data         resb READ_LEN
    .sizeof       equ $-.len
    .alignof      equ 32
endstruc

struc String
    .len          resq 1
    .ptr          resq 1
    .cap          resq 1
    .sizeof       equ $-.len
    .alignof      equ 8
endstruc

struc Str
    .len          resq 1
    .ptr          resq 1
    .sizeof       equ $-.len
    .alignof      equ 8
endstruc

struc ContextMacro
    .name         resb Str.sizeof
    .arguments    resb Str.sizeof
    .sizeof       equ $-.name
    .alignof      equ 8
endstruc

section .rodata
    hello_world.ptr   db "Hello, World!", LF
    hello_world.len   equ $-hello_world.ptr

    context_args.ptr  db " __FILE__, __LINE__"
    context_args.len  equ $-context_args.ptr

    comma.ptr         db ","
    comma.len         equ $-comma.ptr

section .data
    argc        dq 0
    argv        dq 0
    stack_align dq 0

    align StringBuffer.alignof
    stdin_buffer      times StringBuffer.sizeof db 0

    align StringBuffer.alignof
    line              times StringBuffer.sizeof db 0

section .bss
    align String.alignof
    file              resb String.sizeof

    align ContextMacro.alignof
    context           resb ContextMacro.sizeof

    align String.alignof
    result            resb String.sizeof

%macro PUSHA 0
    pushf
    push rax
    push rcx
    push rdx
    push rbx
    push rsp
    push rbp
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
%endmacro

%macro POPA 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
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

%macro DEBUG_STR 2
    PUSHA

    ; write(STDOUT, ptr, len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, %2
    mov rdx, %1
    syscall

    DEBUG_NEWLINE

    POPA
%endmacro

%macro DEBUG_NEWLINE 0
    PUSHA

    ; let newline = '\n'
    push LF

    ; write(STDOUT, &newline, 1)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, rsp
    mov rdx, 1
    syscall

    ; pop
    add rsp, 8

    POPA
%endmacro

section .text

; #[systemv]
; fn main() -> i64 := rax
main:
    push r12
    push r13

    ; file = String::new()
    mov rdi, file
    call String_new

    ; result = String::new()
    mov rdi, result
    call String_new

    ; fd_read_to_string(STDIN, &mut file)
    mov edi, STDIN
    mov rsi, file
    call fd_read_to_string

    ; let (cur_source := r12:r13) = file.as_str()
    mov r12, qword [file + String.len]
    mov r13, qword [file + String.ptr]

    ; let (unmatched := r14:r15) = cur_source[..0]
    xor r14, r14
    mov r15, r13

    ; let push_result = [&mut unmatched, &cur_source] || {
    jmp .end_push_result
    align 16
    .push_result:

        ; result.push_str(unmatched)
        mov rdi, result
        mov rsi, r14
        mov rdx, r15
        call String_push_str

        ; unmatched = cur_source[..0]
        xor r14, r14
        mov r15, r13

    ; }
    ret
    .end_push_result:

    ; while cur_source.len() as isize > 0 {
    .while:
    cmp r12, 0
    jle .end_while

        ; (context, success := al) = cur_source.parse_context_macro()
        mov rdi, context
        mov rsi, r12
        mov rdx, r13
        call Str_parse_context_macro

        ; if success {
        test al, al
        jz .end_if_success

            ; let (len := rax) = context.name.len + 1 + context.arguments.len
            mov rax, qword [context + ContextMacro.name + Str.len]
            add rax, qword [context + ContextMacro.arguments + Str.len]
            inc rax

            ; cur_source = cur_source[len..]
            sub r12, rax
            add r13, rax

            ; push_result()
            call .push_result

            ; result.push_str(context.name)
            mov rdi, result
            mov rsi, qword [context + ContextMacro.name + Str.len]
            mov rdx, qword [context + ContextMacro.name + Str.ptr]
            call String_push_str

            ; result.push_str(" __FILE__, __LINE__")
            mov rdi, result
            mov rsi, context_args.len
            mov rdx, context_args.ptr
            call String_push_str

            ; if context.arguments.trim().len != 0 {
            mov rdi, qword [context + ContextMacro.arguments + Str.len]
            mov rsi, qword [context + ContextMacro.arguments + Str.ptr]
            call Str_trim
            test rax, rax
            jz .end_if_arguments
            DEBUG_STR rax, rdx

                ; result.push_str(",")
                mov rdi, result
                mov rsi, comma.len
                mov rdx, comma.ptr
                call String_push_str

            ; }
            .end_if_arguments:

            ; result.push_str(context.arguments)
            mov rdi, result
            mov rsi, qword [context + ContextMacro.arguments + Str.len]
            mov rdx, qword [context + ContextMacro.arguments + Str.ptr]
            call String_push_str

            ; continue
            jmp .while

        ; }
        .end_if_success:

        ; cur_source = cur_source[1..]
        dec r12
        inc r13

        ; unmatched.len += 1
        inc r14

    ; }
    jmp .while
    .end_while:

    ; push_result()
    call .push_result

    ; let (n_bytes := rax) = write(STDOUT, result.ptr, result.len)
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    mov rsi, qword [result + String.ptr]
    mov rdx, qword [result + String.len]
    syscall

    ; assert n_bytes == result.len
    cmp rax, qword [result + String.len]
    jne abort

    ; drop(result)
    mov rdi, result
    call String_drop

    ; drop(file)
    mov rdi, file
    call String_drop

    ; return EXIT_SUCCESS
    xor rax, rax

    pop r13
    pop r12
    ret

; #[systemv]
; fn Str::parse_context_macro($ret := rdi, self := rsi:rdx)
;     -> (ContextMacro | undefined, (success := al): bool)
Str_parse_context_macro:
    push r12
    push r13
    push r14

    ; let ($ret := r12) = $ret
    mov r12, rdi

    ; let (self := r13:r14) = self
    mov r13, rsi
    mov r14, rdx

    ; let (ident := r8:r9) = self.parse_ident()
    mov rdi, r13
    mov rsi, r14
    call Str_parse_ident
    mov r8, rax
    mov r9, rdx

    ; if ident.len == 0 { return (undefined, false) }
    xor al, al
    test r8, r8
    jz .exit

    ; if ident.len == self.len { return (undefined, false) }
    xor al, al
    cmp r8, r13
    je .exit

    ; if ident[ident.len] != '!' { return (undefined, false) }
    xor al, al
    cmp byte [r9 + r8], "!"
    jne .exit

    ; $ret->name = ident
    mov qword [r12 + ContextMacro.name + Str.len], r8
    mov qword [r12 + ContextMacro.name + Str.ptr], r9
    
    ; self = self[ident.len + 1..]
    sub r13, r8
    dec r13
    lea r14, [r14 + r8 + 1]

    ; $ret->arguments = self.parse_until_newline()
    mov rdi, r13
    mov rsi, r14
    call Str_parse_until_newline
    mov qword [r12 + ContextMacro.arguments + Str.len], rax
    mov qword [r12 + ContextMacro.arguments + Str.ptr], rdx

    ; return ($ret, true)
    mov al, 1

    .exit:
    pop r14
    pop r13
    pop r12
    ret

; #[systemv]
; fn Str::parse_until_newline(self := rdi:rsi) -> Str := rax:rdx
Str_parse_until_newline:
    ; $result = self[..0]
    xor rax, rax
    mov rdx, rsi

    ; while $result.len < self.len {
    .while:
    cmp rax, rdi
    jae .end_while

        ; let (cur := cl) = $result[$result.len]
        mov cl, byte [rdx + rax]

        ; if cur == '\n' || cur == '\r' { break }
        cmp cl, LF
        je .end_while
        cmp cl, CR
        je .end_while

        ; $result.len += 1
        inc rax

    ; }
    jmp .while
    .end_while:

    ret

; #[systemv]
; fn Str::parse_until_space(self := rdi:rsi) -> Str := rax:rdx
Str_parse_until_space:
    ; $result = self[..0]
    xor rax, rax
    mov rdx, rsi

    ; while $result.len < self.len {
    .while:
    cmp rax, rdi
    jae .end_while

        ; let (cur := cl) = $result[$result.len]
        mov cl, byte [rdx + rax]

        ; if cur == '\n' || cur == '\r' || cur == '\t' { break }
        cmp cl, LF
        je .end_while
        cmp cl, CR
        je .end_while
        cmp cl, TAB
        je .end_while

        ; $result.len += 1
        inc rax

    ; }
    jmp .while
    .end_while:

    ret

; #[systemv]
; fn Str::trim(self := rdi:rsi) -> Str := rax:rdx
Str_trim:
    ; while self.len != 0 {
    .while_start:
    test rdi, rdi
    jz .end_while_start

        ; let (cur := cl) = self[0]
        mov cl, byte [rsi]

        ; if cur != '\n' && cur != '\r' && cur != '\t' { break }
        cmp cl, LF
        setne ah
        cmp cl, CR
        setne al
        and ah, al
        cmp cl, TAB
        setne al
        test ah, al
        jnz .end_while_start

        ; self = self[1..]
        dec rdi
        inc rsi

    ; }
    jmp .while_start
    .end_while_start:

    ; while self.len != 0 {
    .while_end:
    test rdi, rdi
    jz .end_while_end

        ; let (cur := cl) = self[self.len - 1]
        mov cl, byte [rsi + rdi - 1]

        ; if cur != '\n' && cur != '\r' && cur != '\t' { break }
        cmp cl, LF
        setne ah
        cmp cl, CR
        setne al
        and ah, al
        cmp cl, TAB
        setne al
        test ah, al
        jnz .end_while_end

        ; self.len -= 1
        dec rdi

    ; }
    jmp .while_end
    .end_while_end:

    ; return self
    mov rax, rdi
    mov rdx, rsi
    
    ret

; #[systemv]
; fn Str::parse_ident(self := rdi:rsi) -> Str := rax:rdx
Str_parse_ident:
    push r12
    push r13

    ; let (self := r12:r13) = self
    mov r12, rdi
    mov r13, rsi

    ; let ($result := rax:rdx): Str = self[..0]
    xor rax, rax
    mov rdx, r13

    ; while $result.len < self.len {
    .while:
    cmp rax, r12
    jae .end_while

        ; let (cur := r8b) = self.ptr[$result.len]
        mov r8b, byte [r13 + rax]

        ; let (non_lowercase := cl) = cur < 'a' || cur > 'z'
        cmp r8b, "a"
        setb cl
        cmp r8b, "z"
        setg ch
        or cl, ch

        ; let (non_uppercase := r9b) = cur < 'A' || cur > 'Z'
        cmp r8b, "A"
        setb r10b
        cmp r8b, "Z"
        setg r9b
        or r9b, r10b

        ; let (non_alpha := cl) = non_lowercase && non_uppercase
        and cl, r9b

        ; if non_alpha && cur != '_' { break }
        cmp r8b, "_"
        setne ch
        test cl, ch
        jnz .end_while

        ; $result.len += 1
        inc rax

    ; }
    jmp .while
    .end_while:

    .exit:
    pop r13
    pop r12
    ret

; #[systemv]
; fn fd_read_to_string((fd := edi): Fd, (dest := rsi): &mut String)
fd_read_to_string:
    push r12
    push r13
    push rbp
    mov rbp, rsp

    .buffer         equ -StringBuffer.sizeof
    .stack_size     equ ALIGNED(-.buffer)

    ; let (fd := r12d) = fd
    mov r12d, edi

    ; let (dest := r13) = dest
    mov r13, rsi

    ; let buffer: StringBuffer
    sub rsp, .stack_size

    ; buffer = StringBuffer::new()
    lea rdi, [rbp + .buffer]
    call StringBuffer_new

    ; do {
    .do:
        
        ; buffer.clear()
        lea rdi, [rbp + .buffer]
        call StringBuffer_clear

        ; let (error := rax) = buffer.fill_from(fd)
        lea rdi, [rbp + .buffer]
        mov esi, r12d
        call StringBuffer_fill_from

        ; assert error == 0
        test rax, rax
        jnz abort

        ; dest.push_str(buffer.as_str())
        mov rdi, r13
        mov rsi, qword [rbp + .buffer + StringBuffer.len]
        lea rdx, [rbp + .buffer + StringBuffer.data]
        call String_push_str

    ; } while buffer.len == READ_LEN
    cmp qword [rbp + .buffer + StringBuffer.len], READ_LEN
    je .do

    add rsp, .stack_size

    pop rbp
    pop r13
    pop r12
    ret

; #[fastcall]
; fn String::new($ret := rdi) -> String
String_new:
    ; return mem::zeroed()
    mov qword [rdi + String.len], 0
    mov qword [rdi + String.ptr], 0
    mov qword [rdi + String.cap], 0

    ret

; #[systemv]
; fn String::drop(&mut self := rdi)
String_drop:
    push r12

    ; let (self := r12) = self
    mov r12, rdi

    ; dealloc(self.ptr)
    mov rdi, qword [r12 + String.ptr]
    call dealloc

    ; *self = mem::zeroed()
    mov qword [r12 + String.len], 0
    mov qword [r12 + String.ptr], 0
    mov qword [r12 + String.cap], 0

    pop r12
    ret

; #[systemv]
; fn String::push_ascii(&mut self := rdi, (value := rsi): u8)
String_push_ascii:
    push r12
    push r13

    ; let (self := r12) = self
    mov r12, rdi

    ; let (value := r13) = value
    mov r13, rsi

    ; if self.cap == 0 {
    cmp qword [r12 + String.cap], 0
    jne .else_if
        
        ; self.ptr = alloc(16)
        mov rdi, 16
        call alloc
        mov qword [r12 + String.ptr], rax

        ; self.cap = 16
        mov qword [r12 + String.cap], 16

    ; } else if (self.cap := rax) == self.len {
    jmp .end_if
    .else_if:
    mov rax, qword [r12 + String.cap]
    cmp rax, qword [r12 + String.len]
    jne .end_if

        ; self.cap += self.cap / 2
        shr rax, 1
        add qword [r12 + String.cap], rax

        ; self.ptr = realloc(self.ptr, self.cap)
        mov rdi, qword [r12 + String.ptr]
        mov rsi, qword [r12 + String.cap]
        call realloc
        mov qword [r12 + String.ptr], rax

    ; }
    .end_if:

    ; self.ptr[self.len] = value
    mov rax, qword [r12 + String.len]
    add rax, qword [r12 + String.ptr]
    mov rdx, r13
    mov byte [rax], dl

    ; self.len += 1
    inc qword [r12 + String.len]

    pop r13
    pop r12
    ret

; #[systemv]
; fn String::push_str(&mut self := rdi, Str { len := rsi, ptr := rdx }: Str)
String_push_str:
    push r12
    push r13
    push r14

    ; let (self := r12) = self
    mov r12, rdi

    ; let (str_len := r13) = len
    mov r13, rsi

    ; let (str_ptr := r14) = ptr
    mov r14, rdx

    ; if self.cap == 0 {
    cmp qword [r12 + String.cap], 0
    jne .else_if

        ; let (new_cap := rax) = max(16, str_len)
        mov rax, 16
        cmp rax, r13
        cmovb rax, r13

        ; self.cap = new_cap
        mov qword [r12 + String.cap], rax

        ; self.ptr = alloc(new_cap)
        mov rdi, rax
        call alloc
        mov qword [r12 + String.ptr], rax

    ; } else if self.cap - self.len < str_len {
    jmp .end_if
    .else_if:
    mov rax, qword [r12 + String.cap]
    sub rax, qword [r12 + String.len]
    cmp rax, r13
    jae .end_if

        ; let (predicted_cap := rax) = self.cap + self.cap / 2
        mov rax, qword [r12 + String.cap]
        shr rax, 1
        add rax, qword [r12 + String.cap]

        ; let (next_cap := rax) = if predicted_cap - self.len >= str_len
        ; { predicted_cap } else { self.len + str_len }
        mov rdx, qword [r12 + String.len]
        add rdx, r13
        mov rdi, rax
        sub rdi, qword [r12 + String.len]
        cmp rdi, r13
        cmovb rax, rdx

        ; self.cap = next_cap
        mov qword [r12 + String.cap], rax

        ; self.ptr = realloc(self.ptr, next_cap)
        mov rdi, qword [r12 + String.ptr]
        mov rsi, rax
        call realloc
        mov qword [r12 + String.ptr], rax

    ; }
    .end_if:

    ; copy(str_ptr, self.ptr + self.len, str_len)
    mov rdi, r14
    mov rsi, qword [r12 + String.ptr]
    add rsi, qword [r12 + String.len]
    mov rdx, r13
    call copy

    ; self.len += str_len
    add qword [r12 + String.len], r13

    pop r14
    pop r13
    pop r12
    ret

; #[fastcall]
; fn StringBuffer::new($ret := rdi) -> StringBuffer
StringBuffer_new:
    ; $ret->len = 0
    mov qword [rdi + StringBuffer.len], 0
    ret

; #[systemv]
; fn StringBuffer::fill_from(&mut self := rdi, (fd := esi): Fd) -> ErrorCode := rax
StringBuffer_fill_from:
    push r12
    push r13

    ; let (self := r12) = self
    mov r12, rdi

    ; let (fd := r13d) = esi
    mov r13d, esi

    ; let (n_bytes := rax) = read(fd, &self.data, READ_LEN)
    mov rax, SYSCALL_READ
    mov edi, r13d
    lea rsi, [r12 + StringBuffer.data]
    mov rdx, READ_LEN
    syscall

    ; if n_bytes < 0 { return n_bytes }
    cmp rax, 0
    jl .exit

    ; if n_bytes > READ_LEN { return n_bytes }
    cmp rax, READ_LEN
    jg .exit

    ; self.len = n_bytes
    mov qword [r12 + StringBuffer.len], rax

    ; return 0
    xor rax, rax

    .exit:
    pop r13
    pop r12
    ret

; #[systemv]
; fn StringBuffer::read_line_from(&mut self := rdi, (from := rsi:rdx): Str)
StringBuffer_read_line_from:
    push r12
    push r13
    push r14

    ; let (self := r12) = self
    mov r12, rdi

    ; let (from := r13:r14) = from
    mov r13, rsi
    mov r14, rdx

    ; let (index := rcx) = 0
    xor rcx, rcx

    ; while index < READ_LEN && index < from.len {
    .while:
    cmp rcx, READ_LEN
    jae .end_while
    cmp rcx, r13
    jae .end_while

        ; let (cur := al) = from.ptr[index]
        mov al, byte [r14 + rcx]

        ; if cur == '\n' { break }
        cmp al, LF
        je .end_while

        ; self.data[index] = cur
        mov byte [r12 + StringBuffer.data + rcx], al

        ; index += 1
        inc rcx

    ; }
    jmp .while
    .end_while:

    ; self.len = index
    mov qword [r12 + StringBuffer.len], rcx

    pop r14
    pop r13
    pop r12
    ret

; #[fastcall]
; fn StringBuffer::clear(&mut self := rdi)
StringBuffer_clear:
    mov qword [rdi + StringBuffer.len], 0
    ret

; #[fastcall(rcx, al)]
; fn StringBuffer::push_str(&mut self := rdi, (src := rsi:rdx): Str)
StringBuffer_push_str:
    ; for (i := rcx) in 0..src.len {
    xor rcx, rcx
    .for:
    cmp rcx, rsi
    jae .end_for

        ; if i >= READ_LEN { break }
        cmp rcx, READ_LEN
        jae .end_for

        ; self.data[i] = src.ptr[i]
        mov al, byte [rdx + rcx]
        mov byte [rdi + StringBuffer.data + rcx], al

    ; }
    inc rcx
    jmp .for
    .end_for:

    ; self.len = i
    mov qword [rdi + StringBuffer.len], rcx

    ret

; #[systemv]
; #[noreturn]
; #[jumpable]
; fn abort() -> !
abort:
    ; let (pid := rax) = getpid()
    mov rax, SYSCALL_GETPID
    syscall

    ; kill(pid, SIGABRT)
    mov rdi, rax
    mov rax, SYSCALL_KILL
    mov rsi, SIGABRT
    syscall

    ; // do exit in case if SIGABRT have been handled
    ; exit(EXIT_FAILURE)
    mov rax, SYSCALL_EXIT
    mov rdi, EXIT_FAILURE
    syscall

    ; // loop forever just in case
    .loop:
    jmp .loop

; #[systemv]
; unsafe fn alloc((size := rdi): usize) -> *mut () := rax
alloc:
    ; let (size := rsi) = size
    mov rsi, rdi

    ; // meta info
    ; rsi += 16
    add rsi, 16

    ; let (result := rax): *mut () = mmap(
    ;     addr = null,
    ;     length = size,
    ;     prot = PROT_READ | PROT_WRITE,
    ;     flags = MAP_ANONYMOUS | MAP_PRIVATE,
    ;     fd = -1,
    ;     offset = 0)
    mov rax, SYSCALL_MMAP
    xor rdi, rdi
    ; mov rsi, rsi
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_ANONYMOUS | MAP_PRIVATE
    mov r8, -1
    xor r9, r9
    syscall

    ; if result == MAP_FAILED { return null }
    cmp rax, MAP_FAILED
    mov rcx, 0
    cmove rax, rcx
    je .exit

    ; *result.cast::<usize>() = size
    mov qword [rax], rsi

    ; result += 16
    add rax, 16

    ; return result
    .exit:
    ret

; #[systemv]
; unsafe fn dealloc((ptr := rdi): *mut ())
dealloc:
    ; if ptr == null { return }
    test rdi, rdi
    jz .exit

    ; ptr -= 16
    sub rdi, 16

    ; let (size := rsi) = *ptr.cast::<usize>()
    mov rsi, qword [rdi]

    ; let (result := rax) = munmap(ptr, size)
    mov rax, SYSCALL_MUNMAP
    ; mov rdi, rdi
    ; mov rsi, rsi
    syscall

    ; assert result == 0
    test rax, rax
    jnz abort

    .exit:
    ret

; #[systemv]
; unsafe fn realloc((ptr := rdi): *mut (), (size := rsi): usize) -> *mut () := rax
realloc:
    push r12
    push r13
    push r14

    ; let (ptr := r12) = ptr
    mov r12, rdi

    ; let (size := r13) = size
    mov r13, rsi

    ; if size < MMAP_PAGE_SIZE - 16 {
    cmp r13, MMAP_PAGE_SIZE - 16
    jae .end_if

        ; *(ptr - 16).cast::<usize>() = size + 16
        lea rax, [rsi + 16]
        mov qword [r12 - 16], rax

        ; return ptr
        mov rax, r12
        jmp .exit

    ; }
    .end_if:

    ; let (result := r14) = alloc(size)
    mov rdi, r13
    call alloc
    mov r14, rax

    ; let (prev_size := rax) = *(ptr - 16).cast::<usize>()
    mov rax, qword [r12 - 16]

    ; let (copy_size := rdx) = min(size, prev_size)
    cmp r13, rax
    mov rdx, r13
    cmovb rdx, rax

    ; copy(ptr, result, copy_size)
    mov rdi, r12
    mov rsi, r14
    ; mov rdx, rdx
    call copy

    ; dealloc(ptr)
    mov rdi, r12
    call dealloc

    ; return result
    mov rax, r14

    .exit:
    pop r14
    pop r13
    pop r12
    ret

; #[fastcall(rdi, rsi, rdx, al)]
; fn copy((source := rdi): *mut u8, (dest := rsi): *mut u8, (size := rdx): usize)
copy:
    ; while (size as isize) >= 0 {
    .while:
    cmp rdx, 0
    jl .end_while

        ; *dest = *source
        mov al, byte [rdi]
        mov byte [rsi], al

        ; dest += 1
        inc rsi

        ; source += 1
        inc rdi

        ; size -= 1
        dec rdx

    ; }
    jmp .while
    .end_while:

    ret

global start
start:
    ; argc = get_argc_from_stack()
    mov rax, qword [rsp]
    mov qword [argc], rax

    ; argv = get_argv_from_stack()
    lea rax, [rsp + 8]
    mov qword [argv], rax

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

    ; exit(0)
    mov rax, SYSCALL_EXIT
    xor rdi, rdi
    syscall
