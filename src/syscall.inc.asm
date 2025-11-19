%ifndef _SYSCALL_INC
%define _SYSCALL_INC

SYSCALL_WRITE                equ 1
SYSCALL_CLOSE                equ 3
SYSCALL_MMAP                 equ 9
SYSCALL_MUNMAP               equ 11
SYSCALL_SOCKET               equ 41
SYSCALL_CONNECT              equ 42
SYSCALL_EXIT                 equ 60

%endif ; !_SYSCALL_INC
