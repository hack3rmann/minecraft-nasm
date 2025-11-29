%ifndef _IMAGE_INC
%define _IMAGE_INC

%define RGB(r, g, b) ((b) | ((g) << 8) | ((r) << 16))
%define IMAGE_CLEAR_COLOR RGB(0xF, 0xF, 0xF)

struc Image2d
    ; data: *mut u32
    .data                 resq 1
    ; width: u32
    .width                resd 1
    ; height: u32
    .height               resd 1
    .sizeof               equ $-.data
    .alignof              equ 8
endstruc

extern Image2d_fill

%endif ; !_IMAGE_INC
