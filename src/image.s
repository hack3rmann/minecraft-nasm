%ifndef _IMAGE_INC
%define _IMAGE_INC

%define RGB(r, g, b) ((b) | ((g) << 8) | ((r) << 16))
%define IMAGE_CLEAR_COLOR RGB(0xF, 0xF, 0xF)

struc Image
    ; data: *mut u32
    .data                 resq 1
    ; width: u32
    .width                resd 1
    ; height: u32
    .height               resd 1
    .sizeof               equ $-.data
    .alignof              equ 8
endstruc

extern Image_fill, Image_slice, Image_fill_rect, Image_fill_triangle, \
       Image_draw_line, Image_set_pixel, Image_draw_line_better

struc ImageSlice
    ; data: *mut u32
    .data                 resq 1
    ; total_width: u32
    .total_width          resd 1
    ; total_height: u32
    .total_height         resd 1
    ; width: u32
    .width                resd 1
    ; height: u32
    .height               resd 1
    ; height: u32
    .sizeof               equ $-.data
    .alignof              equ 8
endstruc

extern ImageSlice_fill

%endif ; !_IMAGE_INC
