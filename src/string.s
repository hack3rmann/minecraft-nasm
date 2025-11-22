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
       String_clear, String_format_u64, String_reserve, String_reserve_exact, \
       String_format_array, String_push_cstr, String_format_i64

extern parse_raw_string, parse_arg_escape, parse_arg_string, parse_arg_type

struc Str
    .len    resq 1
    .ptr    resq 1
    .sizeof equ $-.len
endstruc

extern Str_eq

%endif ; !_STRING_INC
