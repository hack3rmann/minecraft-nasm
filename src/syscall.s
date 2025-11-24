%ifndef _SYSCALL_INC
%define _SYSCALL_INC

SYSCALL_READ                 equ 0
SYSCALL_WRITE                equ 1
SYSCALL_OPEN                 equ 2
SYSCALL_CLOSE                equ 3
SYSCALL_MMAP                 equ 9
SYSCALL_MUNMAP               equ 11
SYSCALL_SHMGET               equ 29
SYSCALL_SHMAT                equ 30
SYSCALL_SHMCTL               equ 31
SYSCALL_GETPID               equ 39
SYSCALL_SOCKET               equ 41
SYSCALL_CONNECT              equ 42
SYSCALL_SENDMSG              equ 46
SYSCALL_EXIT                 equ 60
SYSCALL_KILL                 equ 62
SYSCALL_SHMDT                equ 67
SYSCALL_FTRUNCATE            equ 77
SYSCALL_UNLINK               equ 87
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

IPC_PRIVATE                  equ 0
IPC_CREAT                    equ 0o1000
IPC_EXCL                     equ 0o2000
IPC_NOWAIT                   equ 0o4000

IPC_RMID                     equ 0
IPC_SET                      equ 1
IPC_STAT                     equ 2
IPC_INFO                     equ 3
MSG_STAT                     equ 11
MSG_INFO                     equ 12
MSG_NOTIFICATION             equ 0x8000

O_RDONLY                     equ 0
O_WRONLY                     equ 1
O_RDWR                       equ 2
O_CREAT                      equ 64
O_EXCL                       equ 128

SOL_SOCKET                   equ 1
SCM_RIGHTS                   equ 1

struc msghdr
    ; msg_name: *mut ()       // Optional address
    .msg_name                 resq 1
    ; msg_name_len: u32       // Size of address
    .msg_name_len             resq 1
    ; msg_iov: *mut iovec     // Scatter/gather array
    .msg_iov                  resq 1
    ; msg_iovlen: usize       // # elements in `msg_iov`
    .msg_iovlen               resq 1
    ; msg_control: *mut ()    // Ancilliary data
    .msg_control              resq 1
    ; msg_controllen: usize   // Ancilliary data buffer len
    .msg_controllen           resq 1
    ; msg_flags: u32          // Flags (unused)
    .msg_flags                resq 1
    .sizeof                   equ $-.msg_name
endstruc

struc cmsghdr
    ; cmsg_len: usize
    .cmsg_len                 resq 1
    ; cmsg_level: u32
    .cmsg_level               resd 1
    ; cmsg_type: u32
    .cmsg_type                resd 1
    .sizeof                   equ $-.cmsg_len
endstruc

struc iovec
    ; iov_base: *mut ()       // Starting address
    .iov_base                 resq 1
    ; iov_len: usize          // Size of the memory pointed to by iov_base.
    .iov_len                  resq 1
    .sizeof                   resq $-.iov_base
endstruc

%endif ; !_SYSCALL_INC
