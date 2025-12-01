%ifndef _ARITH_INC
%define _ARITH_INC

%macro VPMULL_U24F8 3
    vpmulld %1, %2, %3
    psrld %1, 8
%endmacro

%macro PMULL_U24F8 2
    pmulld %1, %2
    psrld %1, 8
%endmacro

%endif ; !_ARITH_INC
