%ifndef _STRING_INC
%define _STRING_INC

extern cstr_match_length, cstr_len, print_cstr

struc String
    .len    resq 1
    .ptr    resq 1
    .cap    resq 1
    .sizeof equ $-.len
endstruc

extern String_new, String_drop, String_push_ascii, String_push_str, String_with_capacity, \
       String_clear

struc Str
    .len    resq 1
    .ptr    resq 1
    .sizeof equ $-.len
endstruc

%endif ; !_STRING_INC
