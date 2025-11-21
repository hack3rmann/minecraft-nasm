%ifndef _SYSCALL_INC
%define _SYSCALL_INC

SYSCALL_READ                 equ 0
SYSCALL_WRITE                equ 1
SYSCALL_CLOSE                equ 3
SYSCALL_MMAP                 equ 9
SYSCALL_MUNMAP               equ 11
SYSCALL_GETPID               equ 39
SYSCALL_SOCKET               equ 41
SYSCALL_CONNECT              equ 42
SYSCALL_EXIT                 equ 60
SYSCALL_KILL                 equ 62
SYSCALL_GETUID               equ 102

AF_UNIX                      equ 1
SOCK_STREAM                  equ 1
SOCK_CLOEXEC                 equ 0x80000

SIGHUP                       equ 1
SIGINT                       equ 2
SIGQUIT                      equ 3
SIGILL                       equ 4
SIGABRT                      equ 6
SIGFPE                       equ 8
SIGKILL                      equ 9
SIGSEGV                      equ 11
SIGPIPE                      equ 13
SIGALRM                      equ 14
SIGTERM                      equ 15

%endif ; !_SYSCALL_INC
