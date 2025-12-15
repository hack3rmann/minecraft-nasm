%include "../memory.s"
%include "../syscall.s"
%include "../shm.s"
%include "../error.s"
%include "../function.s"
%include "../panic.s"
%include "../string.s"

section .rodata
    CSTR dev_shm_path, "/dev/shm/minecraft"

section .text

; #[systemv]
; fn Shm::new(($ret := rdi): *mut Shm, (shm_size := rsi): usize) -> Shm
FN Shm_new
    PUSH r12, r13

    ; mov ($ret := r12) = $ret
    mov r12, rdi

    ; mov (shm_size := r13) = shm_size
    mov r13, rsi

    ; $ret.fd = open(dev_shm_path.ptr, O_CREAT | O_RDWR | O_EXCL, 0o600)
    mov rax, SYSCALL_OPEN
    mov rdi, dev_shm_path.ptr
    mov rsi, O_CREAT | O_RDWR | O_EXCL
    mov rdx, 0o600
    syscall
    call exit_on_error
    mov qword [r12 + Shm.fd], rax

    ; ftruncate($ret->fd, shm_size)
    mov rax, SYSCALL_FTRUNCATE
    mov rdi, qword [r12 + Shm.fd]
    mov rsi, r13
    syscall
    call exit_on_error

    ; $ret->ptr = mmap(
    ;     null,
    ;     shm_size,
    ;     PROT_READ | PROT_WRITE,
    ;     MAP_SHARED,
    ;     $ret->fd,
    ;     0)
    mov rax, SYSCALL_MMAP
    xor rdi, rdi
    mov rsi, r13
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_SHARED
    mov r8, qword [r12 + Shm.fd]
    xor r9, r9
    syscall
    mov qword [r12 + Shm.ptr], rax

    ; assert $ret->ptr != MMAP_FAILED
    cmp qword [r12 + Shm.ptr], MAP_FAILED
    je panic

    ; assert $ret->ptr != null
    cmp qword [r12 + Shm.ptr], 0
    je panic

    ; unlink(dev_shm_path.ptr)
    mov rax, SYSCALL_UNLINK
    mov rdi, dev_shm_path.ptr
    syscall
    call exit_on_error

    ; assert $ret->ptr % sizeof(u256) == 0
    test qword [r12 + Shm.ptr], 255
    jnz panic

    ; set256($ret->ptr, 0 := ymm0, shm_size / sizeof(u256))
    mov rdi, qword [r12 + Shm.ptr]
    vpxor ymm0, ymm0, ymm0
    mov rdx, r13
    shr rdx, 5
    call set256
    
    ; $ret->size = shm_size
    mov qword [r12 + Shm.size], r13
END_FN r13, r12

; #[systemv]
; fn Shm::drop(&mut self := rdi)
FN Shm_drop
    PUSH r12

    ; let (self := r12) = self
    mov r12, rdi

    ; if self.ptr == null { return }
    cmp qword [r12 + Shm.ptr], 0
    je .exit

    ; munmap(self.ptr, self.size)
    mov rax, SYSCALL_MUNMAP
    mov rdi, qword [r12 + Shm.ptr]
    mov rsi, qword [r12 + Shm.size]
    syscall
    CALL! exit_on_error

    ; close(self.fd)
    mov rax, SYSCALL_CLOSE
    mov rdi, qword [r12 + Shm.fd]
    syscall
    call exit_on_error

    ; self.ptr = null
    mov qword [r12 + Shm.ptr], 0

    ; self.fd = 0
    mov qword [r12 + Shm.fd], 0

    .exit:
END_FN r12
