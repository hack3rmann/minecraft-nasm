%ifndef _MEMORY_INC
%define _MEMORY_INC

PROT_NONE       equ 0
PROT_READ       equ 1
PROT_WRITE      equ 2
PROT_EXEC       equ 4

MAP_HUGETLB     equ 0x040000
MAP_LOCKED      equ 0x02000
MAP_NORESERVE   equ 0x04000
MAP_32BIT       equ 0x0040
MAP_ANON        equ 0x0020
MAP_ANONYMOUS   equ 0x0020
MAP_DENYWRITE   equ 0x0800
MAP_EXECUTABLE  equ 0x01000
MAP_POPULATE    equ 0x08000
MAP_NONBLOCK    equ 0x010000
MAP_STACK       equ 0x020000
MAP_SYNC        equ 0x080000
MAP_FAILED      equ 0xFFFFFFFFFFFFFFFF

MAP_FILE        equ 0x0000
MAP_SHARED      equ 0x0001
MAP_PRIVATE     equ 0x0002
MAP_FIXED       equ 0x0010

%define ALIGNED(n_bytes) (n_bytes + (8 - (n_bytes % 8)) % 8)

extern alloc, dealloc

%endif ; !_MEMORY_INC
