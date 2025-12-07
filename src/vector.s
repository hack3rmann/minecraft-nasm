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

%macro DOT_I24F8X4 3
    vpslld xmm15, %2, 16         ; (a_lo_x16 := xmm15) = a << 16
    psrld xmm15, 16              ; (a_lo := xmm15) = a_lo_x16 >> 16
    vpslld xmm14, %3, 16         ; (b_lo_x16 := xmm14) = b << 16
    psrld xmm14, 16              ; (b_lo := xmm14) = b_lo_x16 >> 16
    vpsrld xmm13, %2, 16         ; (a_hi := xmm13) = a >> 16
    vpsrld xmm12, %3, 16         ; (b_hi := xmm12) = b >> 16
    vpmulld xmm11, xmm13, xmm12  ; (hi_mul_hi := xmm11) = a_hi * b_hi
    pslld xmm11, 24              ; (hi_mul_hi_shl := xmm11) = hi_mul_hi << 24
    pmulld xmm13, xmm14          ; (hi_mul_lo := xmm13) = a_hi * b_lo
    pmulld xmm12, xmm15          ; (lo_mul_hi := xmm12) = a_lo * b_hi
    paddd xmm12, xmm13           ; (mixed_mul := xmm12) = hi_mul_lo + lo_mul_hi
    pslld xmm12, 8               ; (mixed_mul_shl := xmm12) = mixed_mul << 8
    paddd xmm11, xmm12           ; (hi_mid_sum := xmm11) = hi_mul_hi_shl + mixed_mul_shl
    pmulld xmm15, xmm14          ; (lo_mul_lo := xmm15) = a_lo * b_lo
    psrld xmm15, 8               ; (lo_mul_lo_shr := xmm15) = lo_mul_lo >> 8
    paddd xmm11, xmm15           ; (result := xmm11) = mixed_mul_shl + lo_mul_lo_shr
    vphaddd xmm11, xmm11, xmm11
    vphaddd xmm11, xmm11, xmm11
    vmovd %1, xmm11
%endmacro

%endif ; !_ARITH_INC
