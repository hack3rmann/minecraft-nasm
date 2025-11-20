%ifndef _SYSCALL_INC
%define _SYSCALL_INC

SYSCALL_WRITE                equ 1
SYSCALL_CLOSE                equ 3
SYSCALL_MMAP                 equ 9
SYSCALL_MUNMAP               equ 11
SYSCALL_SOCKET               equ 41
SYSCALL_CONNECT              equ 42
SYSCALL_EXIT                 equ 60

AF_UNIX                      equ 1
SOCK_STREAM                  equ 1
SOCK_CLOEXEC                 equ 0x80000

%endif ; !_SYSCALL_INC
