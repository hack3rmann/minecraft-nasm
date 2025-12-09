%include "../panic.s"
%include "../function.s"
%include "../debug.s"

section .text

; #[systemv]
; #[nounwind]
; fn panic_call_deferred((frame_ptr := rbp): *mut anytype)
panic_call_deferred:
    push r12
    push r13

    ; let (unwind_offset := r12) = (frame_ptr + FN_UNWIND_INFO_OFFSET).cast::<UnwindInfoHeader>().offset
    mov r12, qword [rbp + FN_UNWIND_INFO_OFFSET + UnwindHeader.offset]

    ; if unwind_offset == 0 { return }
    test r12, r12
    jz .exit

    ; do {
    .while:

        ; let (drop_and_flags := r8b)
        ;     = (frame_ptr + unwind_offset).cast::<UnwindInfoHeader>().drop_and_flags
        mov r8, qword [rbp + r12 + UnwindInfoHeader.drop_and_flags]

        ; 'drop_scope: if drop_and_flags & UnwindInfoHeader::FLAGS_BITMASK == UnwindInfoFlags::EMPTY {
        test r8b, UnwindInfoHeader_FLAGS_BITMASK
        jnz .end_if_flags
    
            ; let (drop_in_place := r8) = drop_and_flags & UnwindInfoHeader::DROP_BITMASK
            and r8, UnwindInfoHeader_DROP_BITMASK

            ; if drop_in_place == null { break 'drop_scope }
            test r8, r8
            jz .end_if_flags

            ; let (value_offset := rdi) = (frame_ptr + unwind_offset + sizeof(UnwindInfoHeader))
            ;     .cast::<UnwindInfoSinglePtr>().value_offset
            mov rdi, qword [rbp + r12 + UnwindInfoSinglePtr.value_offset]

            ; let (value_ptr := rdi) = value_offset + frame_ptr
            add rdi, rbp

            ; drop_in_place(value_ptr)
            call r8

        ; }
        .end_if_flags:

        ; unwind_offset = (frame_ptr + unwind_offset).cast::<UnwindInfoHeader>().next_offset
        mov r12, qword [rbp + r12 + UnwindInfoHeader.next_offset]

    ; } while unwind_offset != 0
    test r12, r12
    jnz .while

    .exit:
    pop r13
    pop r12
    ret
