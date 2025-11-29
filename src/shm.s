%ifndef _SHM_INC
%define _SHM_INC

%define SHM_INITIAL_VALUE 0

struc Shm
    .fd                     resq 1
    .size                   resq 1
    .ptr                    resq 1
    .sizeof                 equ $-.fd
    .alignof                equ 8
endstruc

extern Shm_new, Shm_drop

%endif ; !_SHM_INC
