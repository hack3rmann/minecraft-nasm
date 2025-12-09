%ifndef _PANIC_INC
%define _PANIC_INC

; #[align(usize)]
; struct UnwindHeader {
struc UnwindHeader
    ; offset: usize
    .offset             resq 1
    .alignof            equ 8
    .sizeof             equ $-.offset
endstruc

%define UNWIND_OFFSET_END   0xFFFFFFFFFFFFFFFF

struc UnwindInfoHeader
    ; next_offset: usize
    .next_offset        resq 1
    ; drop_and_flags: fn(*mut anytype) | u4
    .drop_and_flags     resq 1
    .alignof            equ 8
    .sizeof             equ $-.next_offset
endstruc

%define UnwindInfoHeader_FLAGS_BITMASK 0xF
%define UnwindInfoHeader_DROP_BITMASK 0xFFFFFFFFFFFFFFF0

struc UnwindInfoSinglePtr
    .header             resb UnwindInfoHeader.sizeof
    .value_offset       resq 1
    .alignof            equ 8
    .sizeof             equ $-.header
endstruc

; #[bitflags]
; struct UnwindInfoFlags {
    ; // Set if the droppable IS IN the unwind info
    %define UnwindInfoFlags_EMPTY 0x0
    %define UnwindInfoFlags_NOT_INPLACE 0x1
; }

extern panic_drop_frame, panic_start_unwind, panic

%endif ; !_PANIC_INC
