\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	FAST MULTIPLICATION BY TABLE LOOKUP FROM RTW.
\ ******************************************************************

\ Multiplies A*X, and stores product in product/product+1.

IF 0        ; here for reference.
.standard_multiply_AX
{
	CPX #0:BEQ zero
	DEX:STX product+1
	LSR A:STA product
	LDA #0
	BCC s1:ADC product+1:.s1 ROR A:ROR product
	BCC s2:ADC product+1:.s2 ROR A:ROR product
	BCC s3:ADC product+1:.s3 ROR A:ROR product
	BCC s4:ADC product+1:.s4 ROR A:ROR product
	BCC s5:ADC product+1:.s5 ROR A:ROR product
	BCC s6:ADC product+1:.s6 ROR A:ROR product
	BCC s7:ADC product+1:.s7 ROR A:ROR product
	BCC s8:ADC product+1:.s8 ROR A:ROR product
	STA product+1
	RTS
	.zero
	STX product:STX product+1
	RTS
}
ENDIF

\ This completes in an average of 113 cycles (excluding the multiply by zero special case) - not bad, but it's possible to do better, provided you're happy to set aside some space for some tables...

\ There is a method which yields the product of two values from the difference between two squares. 
\
\ Mathematically: 
\ (a+b)^2 = a^2 + b^2 + 2ab     --> (I)
\ (a-b)^2 = a^2 + b^2 - 2ab     --> (II)
\
\ (I) minus (II) gives: 
\ (a+b)^2 - (a-b)^2 = 4ab
\
\ or, in other words: 
\
\       (a+b)^2     (a-b)^2
\ ab =  -------  -  -------
\          4           4
\
\ So this means we can store a table of f(n) = n^2 / 4 for n = 0..510, and then can achieve multiplication via a single 16-bit subtract! In reality, we use 4 lookup tables; 2 for the LSB/MSBs of the 16-bit value when n is less than 256, and a further 2 for when n is 256 or greater. 
\ We can divide by 4 without worrying about truncation, because we know that (a+b)^2 - (a-b)^2 will always be a multiple of 4, therefore we lose no information or accuracy by discarding the lower 2 bits in the table itself. 

.fast_multiply_AX
{
    STA num1
    STX num2

    SEC
    SBC num2
    BCS positive
    EOR #255
    ADC #1
    .positive
    TAY
    CLC
    LDA num1
    ADC num2
    TAX
    BCS morethan256

    LDA sqrhi256,X
    STA product+1
    LDA sqrlo,X
    SEC
    BCS lessthan256

    .morethan256
    LDA sqrhi512,X
    STA product+1
    TXA
    AND #1
    BEQ skip
    LDA #&80
    .skip
    EOR sqrlo,X

    .lessthan256
    SBC sqrlo,Y
    STA product
    LDA product+1
    SBC sqrhi256,Y
    STA product+1
    RTS
}

.fast_multiply_signedAX
{
    jsr fast_multiply_AX
	; Apply sign to A only.
    ; Not sure how this works but comes from beeb3d fastmultiply.asm.
	lda num1
	bpl positiveA                                   
	sec                                    
	lda product+1                          
	sbc num2                                
	sta product+1                          
    .positiveA
    rts
}

\\ TODO: Replace the below with a sum of 4x fast_multiply.
\\       AB * CD = (256*A+B)*(256*C+D)
\\               = 65536*A*C + 256*A*D + 256*B*C + B*D
\\               = (A*C)<<16 + (A*D)<<8 + (B*C)<<8 + (B*D)

;When you start, one 16-bit number will be in product+0-product+1, low byte first as usual for 6502
;and the other 16-bit number will be in product+2-product+3, same way. When you're done,
;the 32-bit answer will take all four bytes, with the high cell first.
;IOW, $12345678 will be in the order 34 12 78 56.
;Addresses temp+0 and temp+1 will be used as a scratchpad.
.multiply_16_by_16
{
   	LDA  product+2    ; Get the multiplicand and
    STA  temp+0       ; put it in the scratchpad.
    LDA  product+3
    STA  temp+1
    STZ  product+2    ; Zero-out the original multiplicand area.
    STZ  product+3

    LDY  #16		  ; We'll loop 16 times.
.loop1
	ASL  product+2    ; Shift the entire 32 bits over one bit position.
    ROL  product+3
    ROL  product+0
    ROL  product+1
    BCC  loop2 ; Skip the adding-in to the result if
               ; the high bit shifted out was 0.
    CLC        ; Else, add multiplier to intermediate result.
    LDA  temp+0
    ADC  product+2
    STA  product+2
    LDA  temp+1
    ADC  product+3
    STA  product+3

    LDA  #0    ; If C=1, incr lo byte of hi cell.
    ADC  product+0
    STA  product+0

.loop2
	DEY        	  ; If we haven't done 16 iterations yet,
    BNE  loop1    ; then go around again.
    RTS
}

PAGE_ALIGN
.sqrlo
FOR  N,0,255,1
s256=(N*N) DIV 4
EQUB s256 AND 255
NEXT

PAGE_ALIGN
.sqrhi256
FOR N,0,255,1
s256=(N*N) DIV 4
EQUB s256 DIV 256
NEXT

PAGE_ALIGN
.sqrhi512
FOR N,0,255,1
s512=((N+256)*(N+256)) DIV 4
EQUB s512 DIV 256
NEXT
