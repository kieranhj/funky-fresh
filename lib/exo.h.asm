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

; -------------------------------------------------------------------
; zero page addresses used
; -------------------------------------------------------------------
.exo_zp_start
.zp_len_lo      skip 1
.zp_len_hi      skip 1
.zp_bits_hi     skip 1
.zp_bitbuf      skip 1
.zp_dest_lo     skip 1      ; dest addr lo - must come after zp_bitbuf
.zp_dest_hi     skip 1      ; dest addr hi
.zp_src_lo      skip 1
.zp_src_hi      skip 1

.get_crunched_byte
skip 1                      ; LDA abs
.INPOS          skip 2      ; &FFFF
.get_crunched_byte_code
skip 7                      ; inc INCPOS: bne no_carry: inc INPOS+1: .no_carry RTS
.get_crunched_byte_code_end
