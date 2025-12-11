%include "../panic.s"
%include "../function.s"
%include "../debug.s"
%include "../error.s"

section .text

; #[systemv]
; #[nounwind]
; fn panic_drop_frame((frame_ptr := rbp): *mut anytype)
panic_drop_frame:
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
        jnz .end_if_flags_empty
    
            ; let (drop_in_place := r8) = drop_and_flags & UnwindInfoHeader::DROP_BITMASK
            and r8, UnwindInfoHeader_DROP_BITMASK

            ; if drop_in_place == null { break 'drop_scope }
            test r8, r8
            jz .end_if_flags_empty

            ; let (value_offset := rdi) = (frame_ptr + unwind_offset + sizeof(UnwindInfoHeader))
            ;     .cast::<UnwindInfoSinglePtr>().value_offset
            mov rdi, qword [rbp + r12 + UnwindInfoSinglePtr.value_offset]

            ; let (value_ptr := rdi) = value_offset + frame_ptr
            add rdi, rbp

            ; drop_in_place(value_ptr)
            call r8

        ; }
        .end_if_flags_empty:

        ; 'drop_scope: if drop_and_flags & UnwindInfoHeader::FLAGS_BITMASK == UnwindInfoFlags::JUST_FN {
        mov r9b, r8b
        and r9b, UnwindInfoHeader_FLAGS_BITMASK
        cmp r9b, UnwindInfoFlags_JUST_FN
        jnz .end_if_flags_just_fn
    
            ; let (drop_in_place := r8) = drop_and_flags & UnwindInfoHeader::DROP_BITMASK
            and r8, UnwindInfoHeader_DROP_BITMASK

            ; if drop_in_place == null { break 'drop_scope }
            test r8, r8
            jz .end_if_flags_just_fn

            ; drop_in_place(value_ptr)
            call r8

        ; }
        .end_if_flags_just_fn:

        ; unwind_offset = (frame_ptr + unwind_offset).cast::<UnwindInfoHeader>().next_offset
        mov r12, qword [rbp + r12 + UnwindInfoHeader.next_offset]

    ; } while unwind_offset != 0
    test r12, r12
    jnz .while

    .exit:
    pop r13
    pop r12
    ret

; #[systemv]
; #[nounwind]
; fn panic_start_unwind((mut frame_ptr := rbp): *mut anytype)
panic_start_unwind:
    push rbp

    ; while (frame_ptr + FN_UNWIND_INFO_OFFSET).cast::<UnwindHeader>().offset
    ;     != UNWIND_OFFSET_END
    ; {
    .while:
    cmp qword [rbp + FN_UNWIND_INFO_OFFSET + UnwindHeader.offset], UNWIND_OFFSET_END
    je .end_while

        ; panic_drop_frame(frame_ptr)
        call panic_drop_frame

        ; frame_ptr = *(frame_ptr + FN_SAVED_RBP_OFFSET).cast::<*mut anytype>();
        mov rbp, qword [rbp + FN_SAVED_RBP_OFFSET]

    ; }
    jmp .while
    .end_while:

    pop rbp
    ret

; #[systemv]
; #[nounwind]
; #[jumpable]
; #[noreturn]
; fn panic_start_unwind((mut frame_ptr := rbp): *mut anytype) -> !
panic:
    ; panic_start_unwind()
    call panic_start_unwind

    ; abort()
    call abort

    ret
