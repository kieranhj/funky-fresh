;
; Copyright (c) 2002 - 2018 Magnus Lind.
;
; This software is provided 'as-is', without any express or implied warranty.
; In no event will the authors be held liable for any damages arising from
; the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
;   1. The origin of this software must not be misrepresented; you must not
;   claim that you wrote the original software. If you use this software in a
;   product, an acknowledgment in the product documentation would be
;   appreciated but is not required.
;
;   2. Altered source versions must be plainly marked as such, and must not
;   be misrepresented as being the original software.
;
;   3. This notice may not be removed or altered from any distribution.
;
;   4. The names of this software and/or it's copyright holders may not be
;   used to endorse or promote products derived from this software without
;   specific prior written permission.
;
; -------------------------------------------------------------------

; NB. This is Exomizer 3.0.2 exodecrunch.s implementation but with the
; following changes:
;   stack used for the decrunch tabke
;   there’s no “extra table for length 3”
;   encoded entries hardcoded to 52
;   relocation of destination was added.
;
; Compress using the command line:
;   exomizer.exe level -c -M256 file.bin@0x0000 -o file.exo

; -------------------------------------------------------------------
; Controls if the shared get_bits routines should be inlined or not.
INLINE_GET_BITS=1
; -------------------------------------------------------------------
; if literal sequences is not used (the data was crunched with the -c
; flag) then the following line can be uncommented for shorter and.
; slightly faster code.
LITERAL_SEQUENCES_NOT_USED=1
; -------------------------------------------------------------------
; if the sequence length is limited to 256 (the data was crunched with
; the -M256 flag) then the following line can be uncommented for
; shorter and slightly faster code.
MAX_SEQUENCE_LENGTH_256=1

decrunch_table = $101 ; yes! we have enough stack space to use page 1 here
;.decrunch_table SKIP 156
	
tabl_bi = decrunch_table
tabl_lo = decrunch_table + 52
tabl_hi = decrunch_table + 104
; LDA &FFFF                             ; 4c
.get_crunched_byte_copy                 ; 6c
{
        inc INPOS                       ; 5c
        bne s0a                         ; 2/3c
        inc INPOS+1                     ; 5c

.s0a    rts                             ; 6c
}
.get_crunched_byte_copy_end             ; 24c/28c

IF get_crunched_byte_copy_end-get_crunched_byte_copy <> get_crunched_byte_code_end-get_crunched_byte_code
        ERROR "get_crunched_byte function size mismatch."
ENDIF

MACRO GET_CRUNCHED_BYTE_INLINE
{
        sty stash_y                     ; 3c
        ldy #0                          ; 2c
        lda (INPOS), Y                  ; 5c
        ldy stash_y                     ; 3c
        inc INPOS                       ; 5c
        bne s0a                         ; 2/3c
        inc INPOS+1                     ; 5c
        .s0a
}                                       ; 21c/25c
ENDMACRO

;; refill bits is always inlined
MACRO mac_refill_bits
        pha
        jsr get_crunched_byte
        rol a
        sta zp_bitbuf
        pla
ENDMACRO

IF INLINE_GET_BITS
MACRO mac_get_bits
{
        adc #$80                ; needs c=0, affects v
        asl a
        bpl gb_skip
.gb_next
        asl zp_bitbuf
        bne gb_ok
        mac_refill_bits
.gb_ok
        rol a
        bmi gb_next
.gb_skip
        bvc skip
.gb_get_hi
        sec
        sta zp_bits_hi
        jsr get_crunched_byte
.skip
}
ENDMACRO
ELSE
MACRO mac_get_bits
        jsr get_bits
ENDMACRO
.get_bits
        adc #$80                ; needs c=0, affects v
        asl a
        bpl gb_skip
.gb_next
        asl zp_bitbuf
        bne gb_ok
        mac_refill_bits
.gb_ok
        rol a
        bmi gb_next
.gb_skip
        bvs gb_get_hi
        rts
.gb_get_hi
        sec
        sta zp_bits_hi
        jmp get_crunched_byte
ENDIF
; -------------------------------------------------------------------
; no code below this comment has to be modified in order to generate
; a working decruncher of this source file.
; However, you may want to relocate the tables last in the file to a
; more suitable address.
; -------------------------------------------------------------------

.exo_init
{
	lda #$AD ; LDA abs
	sta get_crunched_byte
	ldx #get_crunched_byte_copy_end-get_crunched_byte_copy-1
.copyloop
	lda get_crunched_byte_copy,X
	sta get_crunched_byte_code,X
	dex
	bpl copyloop
        rts
}

; -------------------------------------------------------------------
; jsr this label to decrunch, it will in turn init the tables and
; call the decruncher
; no constraints on register content, however the
; decimal flag has to be #0 (it almost always is, otherwise do a cld)
.decrunch_to_page_A
; -------------------------------------------------------------------
; init zeropage, x and y regs. (12 bytes)
{
        pha
	stx INPOS
        sty INPOS+1
        ldy #0
        ldx #3
.init_zp
        jsr get_crunched_byte
        sta zp_bitbuf - 1,x
        dex
        bne init_zp

; allow relocation of destination
        clc
        pla
        adc zp_dest_hi
        sta zp_dest_hi

; -------------------------------------------------------------------
; calculate tables (62 bytes) + get_bits macro
; x and y must be #0 when entering
;
        clc
.table_gen
        tax
        tya
        and #$0f
        sta tabl_lo,y
        beq shortcut            ; start a new sequence
; -------------------------------------------------------------------
        txa
        adc tabl_lo - 1,y
        sta tabl_lo,y
        lda zp_len_hi
        adc tabl_hi - 1,y
.shortcut
        sta tabl_hi,y
; -------------------------------------------------------------------
        lda #$01
        sta <zp_len_hi
        lda #$78                ; %01111000
        mac_get_bits
; -------------------------------------------------------------------
        lsr a
        tax
        beq rolled
        php
.rolle
        asl zp_len_hi
        sec
        ror a
        dex
        bne rolle
        CHECK_SAME_PAGE_AS rolle
        plp
.rolled
        ror a
        sta tabl_bi,y
        bmi no_fixup_lohi
        lda zp_len_hi
        stx zp_len_hi
        equb $24
.no_fixup_lohi
        txa
; -------------------------------------------------------------------
        iny
        cpy #52
        bne table_gen
        CHECK_SAME_PAGE_AS table_gen
; -------------------------------------------------------------------
; prepare for main decruncher
        ldy zp_dest_lo
        stx zp_dest_lo
        stx zp_bits_hi
; -------------------------------------------------------------------
; copy one literal byte to destination (11 bytes)
;
.literal_start1
        tya
        bne no_hi_decr
        dec zp_dest_hi
.no_hi_decr
        dey
        jsr get_crunched_byte
        sta (zp_dest_lo),y
; -------------------------------------------------------------------
; fetch sequence length index (15 bytes)
; x must be #0 when entering and contains the length index + 1
; when exiting or 0 for literal byte
.next_round
        dex
        lda zp_bitbuf
.no_literal1
        asl a
        bne nofetch8
        jsr get_crunched_byte
        rol a
.nofetch8
        inx
        bcc no_literal1
        CHECK_SAME_PAGE_AS no_literal1
        sta zp_bitbuf
; -------------------------------------------------------------------
; check for literal byte (2 bytes)
;
        beq literal_start1
        CHECK_SAME_PAGE_AS literal_start1
; -------------------------------------------------------------------
; check for decrunch done and literal sequences (4 bytes)
;
        cpx #$11
IF INLINE_GET_BITS
        bcc skip_jmp
        jmp exit_or_lit_seq
.skip_jmp
ELSE
        bcs exit_or_lit_seq
ENDIF
; -------------------------------------------------------------------
; calulate length of sequence (zp_len) (18(11) bytes) + get_bits macro
;
        lda tabl_bi - 1,x
        mac_get_bits
        adc tabl_lo - 1,x       ; we have now calculated zp_len_lo
        sta zp_len_lo
IF MAX_SEQUENCE_LENGTH_256
        tax
ELSE
        lda zp_bits_hi
        adc tabl_hi - 1,x       ; c = 0 after this.
        sta zp_len_hi
; -------------------------------------------------------------------
; here we decide what offset table to use (27(26) bytes) + get_bits_nc macro
; z-flag reflects zp_len_hi here
;
        ldx zp_len_lo
ENDIF
        lda #$e1
        cpx #$03
        bcs gbnc2_next
        lda tabl_bit,x
.gbnc2_next
        asl zp_bitbuf
        bne gbnc2_ok
        tax
        jsr get_crunched_byte
        rol a
        sta zp_bitbuf
        txa
.gbnc2_ok
        rol a
        bcs gbnc2_next
        CHECK_SAME_PAGE_AS gbnc2_next
        tax
; -------------------------------------------------------------------
; calulate absolute offset (zp_src) (21 bytes) + get_bits macro
;
IF MAX_SEQUENCE_LENGTH_256=0
        lda #0
        sta zp_bits_hi
ENDIF
        lda tabl_bi,x
        mac_get_bits
        adc tabl_lo,x
        sta zp_src_lo
        lda zp_bits_hi
        adc tabl_hi,x
        adc zp_dest_hi
        sta zp_src_hi
; -------------------------------------------------------------------
; prepare for copy loop (2 bytes)
;
.pre_copy
        ldx zp_len_lo
; -------------------------------------------------------------------
; main copy loop (30 bytes)
;
.copy_next
        tya
        bne copy_skip_hi
        dec zp_dest_hi
        dec zp_src_hi
.copy_skip_hi
        dey
IF LITERAL_SEQUENCES_NOT_USED=0
        bcs get_literal_byte
ENDIF
        lda (zp_src_lo),y
.literal_byte_gotten
        sta (zp_dest_lo),y
        dex
        bne copy_next
IF MAX_SEQUENCE_LENGTH_256=0
        lda zp_len_hi
IF INLINE_GET_BITS
        bne copy_next_hi
ENDIF
ENDIF
.begin_stx
        stx zp_bits_hi
IF INLINE_GET_BITS=0
        beq next_round
ELSE
        jmp next_round
ENDIF
IF MAX_SEQUENCE_LENGTH_256=0
.copy_next_hi
        dec zp_len_hi
        jmp copy_next
ENDIF
IF LITERAL_SEQUENCES_NOT_USED=0
.get_literal_byte
        jsr get_crunched_byte
        bcs literal_byte_gotten
        CHECK_SAME_PAGE_AS literal_byte_gotten
ENDIF
; -------------------------------------------------------------------
; exit or literal sequence handling (16(12) bytes)
;
.exit_or_lit_seq
IF LITERAL_SEQUENCES_NOT_USED=0
        beq decr_exit
        jsr get_crunched_byte
IF MAX_SEQUENCE_LENGTH_256=0
        sta zp_len_hi
ENDIF
        jsr get_crunched_byte
        tax
        bcs copy_next
        CHECK_SAME_PAGE_AS copy_next
.decr_exit
ENDIF
        rts
; -------------------------------------------------------------------
; the static stable used for bits+offset for lengths 3, 1 and 2 (3 bytes)
; bits 4, 2, 4 and offsets 16, 48, 32
; -------------------------------------------------------------------
; end of decruncher
; -------------------------------------------------------------------
.tabl_bit
 equb %11100001, %10001100, %11100010
}
