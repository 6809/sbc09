	;FBASIC, Floating point BASIC.

		;Configuration info, change this for different apps.
ROM		equ 0		;Flag to indicate that BASIC is in ROM
ROMSTART	equ $8000	;First ROM address.
RAMSTART	equ $400	;First RAM address.
RAMTOP		equ $8000	;Last RAM address +1.				

PROGORG		equ ROM*ROMSTART+(1-ROM)*RAMSTART

		;First the O.S. vectors in the zero page.		
		org $0000
* First the I/O routine vectors.
getchar		rmb 3		;Jump to getchar routine.
putchar		rmb 3		;Jump to putchar routine.
getline		rmb 3		;Jump to getline routine.
putline		rmb 3		;Jump to putline routine.
putcr		rmb 3		;Jump to putcr routine.
getpoll         rmb 3           ;Jump to getpoll routine.
xopenin		rmb 3		;Jump to xopenin routine.
xopenout	rmb 3		;Jump to xopenout routine.
xabortin	rmb 3           ;Jump to xabortin routine.
xclosein	rmb 3		;Jump to xclosein routine.
xcloseout	rmb 3		;Jump to xcloseout routine.
delay		rmb 3		;Jump to delay routine.

timer 		equ *+6		;3-byte timer.
linebuf		equ $200	;Input line buffer
xerrvec		equ $280+6*3	;Error vector.

* Now BASIC's own zero-page allocations.
		org $40
startprog	rmb 2		;Start of BASIC program.
endprog		rmb 2		;End of BASIC program.
endvar		rmb 2		;End of variable area.
fpsp		rmb 2		;Floating point stack pointer (grows up).
endmem		rmb 2

intbuf		rmb 4		;Buffer to store integer.
intbuf2		rmb 4
bcdbuf		rmb 5		;Buffer for BCD conversion.

endstr		rmb 2		;End address of string.
dpl		rmb 1		;Decimal point location.

* The BASIC interpreter starts here.
		org PROGORG
cold		jmp docold
warm		bra noboot

* Cold start routine.
docold		ldx #RAMTOP
		stx endmem
		tfr x,s	
		ldu #FREEMEM
		stu startprog
		clr ,u+
		clr ,u+
		stu endprog
		ldx PROGEND
		leax 1,x
		beq noboot	;Test for autoboot program.
		ldx #PROGEND
		stx startprog
		jmp dorun
noboot		jsr doclear				
		ldd #$4000
		std fpsp
		ldu fpsp
nbloop		ldx #$5000
		ldb #20
		jsr getline
		clr b,x
		cmpb #1
		lbne donum
		ldb ,x
		cmpb #'+'
		bne nb1
		jsr fpadd
		lbra doprint
nb1		cmpb #'-'	
		bne nb2
		jsr fpsub
		lbra doprint
nb2		cmpb #'*'
		bne nb3	
		jsr fpmul
		lbra doprint
nb3		cmpb #'/'
		bne nb4
		jsr fpdiv
		lbra doprint		
nb4		cmpb #'q'
		bne nb5
		jsr fpsqrt
		lbra doprint
nb5		cmpb #'i'
		bne nb6
		jsr fpfloor
		lbra doprint
nb6		cmpb #'s'
		bne nb7
		jsr fpsin
		lbra doprint
nb7		cmpb #'='
		bne nb8
		jsr fpcmp
		beq nbeq
		bcc nbgt
		ldb #'<'
		bra nbcmp
nbeq		ldb #'='
		bra nbcmp
nbgt		ldb #'>'
nbcmp		leau -10,u
		jsr putchar
		jsr putcr
		bra nbloop
nb8		cmpb #'c'
		bne nb9
		jsr fpcos
		bra doprint
nb9		cmpb #'t'
		bne nb10
		jsr fptan
		bra doprint
nb10		cmpb #'a'
		bne nb11
		jsr fpatan
		bra doprint
nb11		cmpb #'e'
		bne nb12
		jsr fpexp
		bra doprint
nb12		cmpb #'l'
		bne nb13
		jsr fln
		bra doprint
nb13		cmpb #'d'
		bne nb14
		jsr fpdup
		bra doprint
nb14		cmpb #'x'
		bne nb15
		jsr fpexg
		bra doprint
nb15		cmpb #'r'
		bne nb16
		leau 5,u
		bra doprint
nb16
donum		ldy #$5000
		jsr scannum
		lbra nbloop
doprint		ldy #$5000
		jsr fpdup
		jsr fpscient
		ldx #$5000
		ldb ,x+
		jsr putline
		jsr putcr
		lbra nbloop
		
doclear 	rts
dorun		swi
makefree	rts		

* Floating point primitives.

* U is the floating point stack pointer and points to the first free
* location. Each number occupies 5 bytes, 
* Format: byte0: binary exponent  $00-$FF $80 means number in range 1..2.
*         byte1-byte4 binary fraction between 1.0 and 2.0, msb would
*	  always be set, but replaced by sign.
*	  Special case: all bytes zero, number=0.

* Exchange top two numbers on stack.
fpexg		ldx -2,u
		ldd -7,u
		stx -7,u
		std -2,u
		ldx -4,u
		ldd -9,u
		stx -9,u
		std -4,u
		lda -5,u
		ldb -10,u
		sta -10,u
		stb -5,u
		rts

fpdup		leax -5,u
* Load fp number from address X and push onto stack.
fplod		ldd ,x++
		std ,u++
		ldd ,x++
		std ,u++
		lda ,x+
		sta ,u+
fckmem		tfr s,d
		stu fpsp
		subd fpsp
		subd #40	
		lbcs makefree	;Test for sufficient free space.
		rts 
		
* Pop fp number from stack and store into address X.
fpsto		lda -5,u
		sta ,x+
		ldd -4,u
		std ,x++
		ldd -2,u
		std ,x++
		leau -5,u
		rts

* Compare magnitude (second-top).
fpcmpmag	lda -10,u
		cmpa -5,u	;Compare exponents.
		bne cmpend
		ldd -4,u
		anda #$7F	;Eliminate sign bit.
		std ,--s
		ldd -9,u
		anda #$7F	;Eliminate sign bit.
		subd ,s++	;Compare msb of mantissa.
		bne cmpend
		ldd -7,u
		subd -2,u
		bne cmpend
cmpend		rts

* Test a top number for 0.
fptest0		tst -5,u
		bne cmpend
		ldd -4,u
		bne cmpend
		ldd -2,u
		rts

* Floating point subtraction.
fpsub		jsr fpneg

* Floating point addition.
fpadd		bsr fpcmpmag	;First compare magnitudes.
		bcc fpadd1
		jsr fpexg	;Put the biggest one second.
fpadd1		bsr fptest0		
		beq fpaddend	;Done if smallest number is 0.
		lda -10,u
		suba -5,u	;Determine exponent difference.
		cmpa #32
		bhi fpaddend	;Done if difference too big.
		ldb -9,u
		andb #$80
		stb ,-s		;Store sign of biggest number.
		eorb -4,u
		stb ,-s		;Store difference of signs.
		ldb -9,u
		orb #$80
		stb -9,u
		ldb -4,u
		orb #$80
		stb -4,u	;Put the hidden msbs back in.
		clr ,u		;Make extra mantissa byte.
		tsta
		beq fpadd2b	;Skip the alignment phase.
fpalign		lsr -4,u
		ror -3,u
		ror -2,u
		ror -1,u	;Shift the smaller number right to align
		ror ,u
		deca
		bne fpalign
fpadd2b		tst ,s+
		bmi dosub	;Did signs differ? Then subtract.
		ldd -7,u	;Add the mantissas.
		addd -2,u
		std -7,u
		ldd -9,u
		adcb -3,u
		adca -4,u
		std -9,u
		bcc fpadd2
fpadd2a		inc -10,u	;Sum overflowed, inc exp, shift mant.
		lbeq fpovf	;If exponent overflowed, too bad.
		ror -9,u
		ror -8,u
		ror -7,u
		ror -6,u
		ror ,u
fpadd2		tst ,u
		bpl fpadd3	;test msb of extra mantissa byte.		
		ldd -7,u	;Add 1 to mantissa if this is set
		addd #1         
		std -7,u	
		bcc fpadd3
		ldd -9,u
		clr ,u
		addd #1
		std -9,u
		bcs fpadd2a	
fpadd3		ldb -9,u
		andb #$7F
		eorb ,s+
		stb -9,u	;Put original sign back in.		
fpaddend 	leau -5,u
		rts		
dosub		ldb ,u
		negb
		stb ,u
		ldd -7,u	;Signs differed, so sbutract.
		sbcb -1,u
		sbca -2,u
		std -7,u
		ldd -9,u
		sbcb -3,u
		sbca -4,u
		std -9,u
		bmi fpadd2	;Number still normalized, then done.
		ldd -9,u
		bne fpnorm
		ldd -7,u
		bne fpnorm
		tst ,u
		beq fpundf	;If mantissa exactly zero, underflow.
fpnorm		tst -10,u	;dec exp, shift mant left
		beq fpundf	;Underflow, put a zero in. 
		dec -10,u
		asl ,u
		rol -6,u
		rol -7,u
		rol -8,u
		rol -9,u
		bpl fpnorm	;Until number is normalized.
		bra fpadd2
		
fpundf		clr -10,u	;Underflow, substitute zero.
		clr -9,u
		clr -8,u
		clr -7,u
		clr -6,u
		leas 1,s	;Discard the sign on stack.
		bra fpaddend

* Compare Floating Point Numbers, flags as with unsigned comparison.
fpcmp		lda -9,u
		anda #$80
		sta ,-s
		lda -4,u
		anda #$80
		suba ,s+	;Subtract the signs, subtraction is reversed.
		bne fpcmpend
		tst -9,u
		bmi fpcmpneg	;Are numbers negative?	
		jmp fpcmpmag
fpcmpneg	jsr fpcmpmag
		beq fpcmpend	
		tfr cc,a
		eora #$1
		tfr a,cc	;Reverse the carry flag.
fpcmpend	rts

* Multiply floating point numbers.
fpmul		lda -9,u
		eora -4,u
		anda #$80
		sta ,-s		;Sign difference to stack.
		jsr fptest0	;Test one operand for 0
		beq fpundf	
		ldd -7,u
		bne fpmula		
		ldd -9,u
		bne fpmula	;And the other one.
		ldb -10,u
		beq fpundf
fpmula		ldb -9,u
		orb #$80
		stb -9,u
		ldb -4,u
		orb #$80
		stb -4,u	;Put hidden msb back in.
		lda -10,u
		suba #$80	;Make unbiased signed num of exponents.
		sta ,-s
		lda -5,u
		suba #$80
		adda ,s+	;add exponents.
		bvc fpmul1	;Check over/underflow
		lbmi fpovf
		bra fpundf
fpmul1		adda #$80	;Make exponent biased again.
		sta -10,u	;Store result exponent.
* Now perform multiplication of mantissas to 40-bit product.
* 0,u--4,u product. 5,u--9,u added term
* Having a mul instruction is nice, but using it for an efficient 
* multiprecision multiplicaton is hard. This routine has 13 mul instructions.
		lda -1,u
		ldb -8,u
		mul		;b4*a2
		sta 4,u
		lda -1,u
		ldb -9,u
		mul		;b4*a1
		addb 4,u
		adca #0
		std 3,u
		lda -2,u
		ldb -7,u
		mul		;b3*a3
		sta 9,u
		lda -2,u
		ldb -8,u
		mul		;b3*a2
		addb 9,u
		adca #0
		std 8,u
		lda -2,u
		ldb -9,u
		mul		;b3*a1
		addb 8,u
		adca #0
		std 7,u
		ldd 8,u
		addd 3,u
		std 3,u
		ldb 7,u
		adcb #0
		stb 2,u		;Add b4*a and b3*a partial products.
		lda -3,u
		ldb -6,u
		mul		;b2*a4
		sta 9,u
		lda -3,u
		ldb -7,u
		mul		;b2*a3
		addb 9,u
		adca #0
		std 8,u
		lda -3,u
		ldb -8,u
		mul		;b2*a2
		addb 8,u
		adca #0
		std 7,u
		lda -3,u
		ldb -9,u	;b2*a1
		mul	
		addb 7,u
		adca #0
		std 6,u
		ldd 8,u
		addd 3,u
		std 3,u
		ldd 6,u
		adcb 2,u
		adca #0
		std 1,u		;Add b2*a partial product in.
		lda -4,u
		ldb -6,u
		mul		;b1*a4
		std 8,u
		lda -4,u
		ldb -7,u
		mul		;b1*a3
		addb 8,u
		adca #0
		std 7,u
		lda -4,u
		ldb -8,u
		mul		;b1*a2
		addb 7,u
		adca #0
		std 6,u
		lda -4,u
		ldb -9,u
		mul		;b1*a1
		addb 6,u
		adca #0
		std 5,u
		ldd 8,u
		addd 3,u
		std -6,u
		ldd 6,u
		adcb 2,u
		adca 1,u
		std -8,u	
		ldb 5,u
		adcb #0
		stb -9,u	;Add product term b1*a in, result to dest.
		bmi fpmul2	
		asl -5,u
		rol -6,u
		rol -7,u
		rol -8,u
		rol -9,u	;Normalize by shifting mantissa left.
		bra fpmul3
fpmul2		inc -10,u	;increment exponent.
		lbeq fpovf	;Test for overflow.
fpmul3		tst -5,u	
		lbpl fpadd3
		ldd -7,u	;Add 1 if msb of 5th nibble is set.
		addd #1
		std -7,u
		lbcc fpadd3
		ldd -9,u
		addd #1
		std -9,u
		bcs fpmul4	;It could overflow.
		lbra fpadd3
fpmul4		clr -5,u
		bra fpmul2

* Divide floating point numbers.
fpdiv		lda -9,u
		eora -4,u
		anda #$80
		sta ,-s		;Sign difference to stack.
		jsr fptest0	;Test divisor for 0
		lbeq fpovf	
		ldd -7,u
		bne fpdiva		
		ldd -9,u
		bne fpdiva	;And the other one.
		ldb -10,u
		lbeq fpundf
fpdiva		ldb -9,u
		orb #$80
		stb -9,u
		ldb -4,u
		orb #$80
		stb -4,u	;Put hidden msb back in.
		lda -5,u
		suba #$80	;Make unbiased signed difference of exponents.
		sta ,-s
		lda -10,u
		suba #$80
		suba ,s+	;subtract exponents.
		bvc fpdiv1	;Check over/underflow
		lbmi fpovf
		lbra fpundf
fpdiv1		adda #$80	;Make exponent biased again.
		sta -10,u	;Store result exponent.
* Now start the division of mantissas. Temprorary 34-bit quotient in 0,u--4,u
* -5,u is extra byte of dividend.
		lda #34
		sta ,-s
		clr ,u
		clr 1,u
		clr 2,u
		clr 3,u
		clr 4,u
		clr -5,u
fpdivloop	asl 4,u		;Shift quotient left.
		rol 3,u
		rol 2,u
		rol 1,u
		rol ,u		
		ldd -7,u	;Perform trial subtraction.
		subd -2,u	
		std -7,u
		ldd -9,u
		sbcb -3,u
		sbca -4,u
		std -9,u
		ldb -5,u
		sbcb #0
		bcc fpdiv2
		ldd -7,u	;Undo the trial subtraction.		
		addd -2,u	
		std -7,u
		ldd -9,u
		adcb -3,u
		adca -4,u
		std -9,u
		bra fpdiv4
fpdiv2		stb -5,u	;Store new msb of quotient.
		lda 4,u		;Add 1 to quotient.
		adda #$40
		sta 4,u
fpdiv4		asl -6,u	;Shift dividend left.
		rol -7,u
		rol -8,u
		rol -9,u
		rol -5,u
		dec ,s
		bne fpdivloop
		leas 1,s
		ldd 3,u
		std -6,u
		ldd 1,u
		std -8,u
		ldb ,u
		stb -9,u	;Move quotient to final location.
		bmi fpdiv3	
fpdiv5		asl -5,u
		rol -6,u
		rol -7,u
		rol -8,u
		rol -9,u	;Normalize by shifting mantissa left.
		ldb -10,u	;decrement exponent.
		lbeq fpundf	;Test for underflow.
		decb
		stb -10,u
fpdiv3		tst -5,u	
		lbpl fpadd3
		ldd -7,u	;Add 1 if msb of 5th nibble is set.
		addd #1
		std -7,u
		lbcc fpadd3
		ldd -9,u
		addd #1
		std -9,u
		lbcs fpmul4	;This addition could overflow.
		lbra fpadd3				

* Floating point negation.
fpneg		jsr fptest0
		beq fpnegend	;Do nothing if number equals zero.
		lda -4,u
		eora #$80
		sta -4,u	;Invert the sign bit.	
fpnegend	rts

* Convert unsigned double number at X to float.
ufloat		leau 5,u	;Make room for extra number on stack.
		ldd ,x
		std -4,u
		ldd 2,x
		clr -5,u
uf16		std -2,u	;Transfer integer to FP number.	
		jsr fptest0
		beq ufzero
		ldb #$9f	;Number is not zero.		
		stb -5,u
		tst -4,u
		bmi ufdone
ufloop		dec -5,u	;Decrement exponent.
		asl -1,u
		rol -2,u
		rol -3,u
		rol -4,u	;Shift mantissa.
		bpl ufloop	;until normalized.
ufdone		ldb -4,u
		andb #$7f
		stb -4,u	;Remove the hidden msb.
ufend		jmp fckmem 	;Check that fp stack does not overflow
ufzero		clr -5,u	;Make exponent zero as well.
		bra ufend

* Convert unsigned 16-bit integer in D to floating point.
unint2fp	clr ,-s
		bra i2fp2
* Convert signed 16-bit integer in D to floating point.
int2fp		sta ,-s		;Store sign byte.
		bpl i2fp2
		comb
		coma
		addd #1		;Negate D if negative.
i2fp2		leau 5,u
		clr -4,u
		clr -5,u
		clr -3,u	;Clear msb	
		jsr uf16	
		tst ,s+
		bmi fpneg
		rts		;Negate number if it was negative.

* Convert float to unsigned 32-bit integer at X.
* A is nonzero if number was not integer or zero.
uint		ldd -4,u
		ora #$80	;Put the hidden msb back in.
		std ,x
		ldd -2,u
		std 2,x		;Transfer mantissa.
		clra
		ldb -5,u
		cmpb #$80	;If less than 1, it's 0		
		blo uizero
		cmpb #$9f
		lbhi intrange	;2^32 or higher, that's too bad. 		
		beq uidone
uiloop		lsr ,x
		ror 1,x
		ror 2,x
		ror 3,x		;Adjust integer by shifting to right
		adca #0		;Add any shifted out bit into A.
		incb				
		cmpb #$9f
		blo uiloop 
uidone		leau -5,u
		rts
uizero		inca		; Indicate non-integer.
		clr ,x		; Number is zero
		clr 1,x
		clr 2,x
		clr 3,x
		leau -5,u
	        rts   

* Convert fp number to signed or unsigned 16-bit number in D.
* Acceptable values are -65535..65535.
fp2uint		ldb -5,u
		stb ,-s		;Store sign.
		ldx #intbuf	
		bsr uint
		ldx ,x
		lbne intrange	;Integer must be in 16-bit range.
		ldd intbuf+2
		tst ,s+
		bpl fp2iend
		comb
		coma
		addd #1		;Negate number if negative.
fp2iend		rts
* Convert fp number to signed 16-bit number in D. 
fp2int		ldb -5,u
		stb ,-s		;Store sign of FP number.
		bsr fp2uint
		pshs d
		eora ,s+
		lbmi intrange	;Compare sign to what it should be. 
		puls d,pc

* Scan a number at address Y and convert to integer or floating point
scannum		jsr skipspace
		clr ,-s		;Store sign on stack.
		cmpb #'-'	;Test for minus sign.
		bne sn1
		inc ,s		;Set sign on stack
		ldb ,y+
sn1		jsr scanint	;First scan the number as an integer.
		ldx #intbuf
		jsr ufloat	;Convert to float.
		ldb -1,y
sn1loop		cmpb #'.'
		bne sn1c
		tst dpl		;If dpl already set, accept no other point.
		bne sn1d
		inc dpl
		ldb ,y+
		bra sn1loop
sn1c		subb #'0'
		blo sn1d
		cmpb #9
		bhi sn1d
		clra
		jsr int2fp	;Convert digit to fp
		jsr fpexg
		ldx #fpten
		jsr fplod
		jsr fpmul	;Multiply original number by 10.
		jsr fpadd	;Add digit to it.
		tst dpl
		beq sn1k
		inc dpl		;Adjust dpl (one more digit after .)
sn1k		ldb ,y+
		bra sn1loop		
sn1d		tst ,s+
		beq sn1a
		jsr fpneg	;Negate the number if negative.
sn1a		clr ,-s
		clr ,-s		;Prepare exponent part on stack.
		ldb -1,y
		cmpb #'e'
		beq sn1e
		cmpb #'E'
		bne sn1f	;Test for exponent part.
sn1e		ldb ,y+
		clr ,-s		;Prepare exponent sign on stack.
		cmpb #'+'
		beq sn1g
		cmpb #'-'
		bne sn1h
		inc ,s		;Set sign to negative.
sn1g		ldb ,y+
sn1h		lda dpl
		pshs a
		clr dpl
		inc dpl
		jsr scanint	;Scan the exponent part.
		puls a
		sta dpl		;Restore dpl.
		lda intbuf
		ora intbuf+1
		ora intbuf+2
		lbne fpovf	;Exponent may not be greater than 255.
		ldb intbuf+3
		lbmi fpovf	;Not even greater than 127.
		tst ,s+
		beq sn1i
		negb
sn1i		sex
		std ,s
sn1f		ldb dpl
		beq sn1j
		decb
sn1j		negb
		sex
		addd ,s++	;Add exponent part as well
		pshs d
		ldx #fpten
		jsr fplod
		puls d
		jsr fpipower
		jsr fpmul
sn1b		rts		

* Scan integer number below 1e9 at address Y, first digit in B.
scanint		clr dpl
scanint1	clr intbuf
		clr intbuf+1
		clr intbuf+2
		clr intbuf+3	;Initialize number
snloop		cmpb #'.'	
		bne sn2a	;Test for decimal point.
		tst dpl
		bne sndone	;Done if second point found.
		inc dpl		;Set dpl to indicate decimal point.
		bra sn3
sn2a		subb #'0'
		blo sndone
		cmpb #9
		bhi sndone	;Check that character is a digit.
		tst dpl
		beq sn2b
		inc dpl		;Incremend deecimal point loc if set.
sn2b		pshs b
		ldd intbuf+2
		aslb
		rola
		std intbuf+2
		std intbuf2+2
		ldd intbuf
		rolb
		rola
		std intbuf
		std intbuf2
		asl intbuf+3
		rol intbuf+2
		rol intbuf+1
		rol intbuf
		asl intbuf+3
		rol intbuf+2
		rol intbuf+1
		rol intbuf
		ldd intbuf+2
		addd intbuf2+2
		std intbuf +2
		ldd intbuf
		adcb intbuf2+1
		adca intbuf2
		std intbuf	;Multiply the integer by 10
		ldd intbuf+2
		addb ,s+	;Add the digit in.
		adca #0
		std intbuf+2
		bcc sn2
		ldd intbuf
		addd #1
		std intbuf
sn2		ldd intbuf
		cmpd #$5f5      
		blo sn3
		bhi snovf
		ldd intbuf+2	;note $5f5e100 is 100 million
		cmpd #$e100	;Compare result to 100 million 
		bhs snovf
sn3		ldb ,y+		;get next digit.
		bra snloop		
snovf		ldb ,y+		;get next digit.
sndone		ldb -1,y
		rts

*Convert integer at X to BCD.
int2bcd		clr bcdbuf
		clr bcdbuf+1
		clr bcdbuf+2
		clr bcdbuf+3
		clr bcdbuf+4
		ldb #4
tstzero		tst ,x+
		bne bcd1
		decb
		bne tstzero	;Skip bytes that are zero.
		bra sndone	;Done if number already zero.	
bcd1		stb ,-s		;Store number of bytes.
		leax -1,x
bcdloop		ldb #8
bcdloop1	rol ,x		;Get next bit of binary nunber
		lda bcdbuf+4
		adca bcdbuf+4
		daa
		sta bcdbuf+4
		lda bcdbuf+3
		adca bcdbuf+3
		daa
		sta bcdbuf+3
		lda bcdbuf+2
		adca bcdbuf+2
		daa
		sta bcdbuf+2
		lda bcdbuf+1
		adca bcdbuf+1
		daa
		sta bcdbuf+1
		lda bcdbuf
		adca bcdbuf
		daa
		sta bcdbuf	;Add BCD number to itself plus the extra bit.
		decb
		bne bcdloop1		
		leax 1,x
		dec ,s
		bne bcdloop
		leas 1,s	;Remove counter from stack.
		rts

* Raise fp number to an integer power contained in D. 
fpipower	sta ,-s		;Store sign of exponent.
		bpl fppow1	;Is exponent negative.
		coma
		comb
		addd #1		;Take absolute value of exponent.
fppow1		std ,--s	;Store the exponent.
		ldx #fpone
		jsr fplod	;Start with number one.
fppowloop	lsr ,s
		ror 1,s		;Divide exponent by 2.
		bcc fppow2	;Test if it was odd.
		leax -10,u
		jsr fplod
		jsr fpmul	;Multiply result by factor.
fppow2		ldd ,s
		beq fppowdone	;Is exponent zero?
		leax -10,u
		jsr fplod
		jsr fpdup
		jsr fpmul	;Sqaure the factor.
		leax -15,u
		jsr fpsto	;Store it in its place on stack.
		bra fppowloop				
fppowdone	leas 2,s	;Remove exponent.
		tst ,s+
		bpl fppow3	;Was exponent negative?
		ldx #fpone
		jsr fplod
		jsr fpexg
		jsr fpdiv	:compute 1/result.
fppow3		jsr fpexg
		leau -5,u	;Remove factor from stack.
		rts								


* Convert fp number to string at address Y in scientific notation.
fpscient	ldb #15
		stb ,y+		;Store the string length.
		lda #' '
		ldb -4,u
		bpl fpsc1
		lda #'-'
fpsc1		sta ,y+		;Store - or space depending on sign.
		andb #$7f
		stb -4,u	;Make number positive.
		clr ,-s		;Store decimal exponent (default 0)
		jsr fptest0		
		beq fpsc2	;Test for zero
		lda -5,u
		suba #$80
		suba #$1D	;Adjust exponent.
		bvc fpsc11a
		lda #-128
fpsc11a		sta ,-s		;store it to recover sign later.
		bpl posexp
		nega		;Take absolute value.
posexp		ldb #5
		mul
		lsra
		rorb
		lsra
		rorb
		lsra
		rorb
		lsra
		rorb		;multiply by 5/16 approx 10log 2
		cmpb #37
		bls expmax
		ldb #37	;Maximum decimal exponent=37
expmax		tst ,s+
		bpl posexp1
		negb
posexp1		stb ,s		;Store approximate decimal exponent.
		negb
		sex		;Approximate (negated) decimal exponent in D.
		pshs d
		ldx #fpten
		jsr fplod
		puls d
		jsr fpipower	;Take 10^-exp
		jsr fpmul
fpsc1a		ldx #fplolim
		jsr fplod
		jsr fpcmpmag	;Compare number to 100 million
		leau -5,u
		bhs fpsc1c
		dec ,s		;Decrement approximate exponent.
		ldx #fpten
		jsr fplod
		jsr fpmul	;Multiply by ten.
		bra fpsc1a
fpsc1c		ldx #fphilim
		jsr fplod
		jsr fpcmpmag	;Compare number to 1 billion
		leau -5,u
		blo fpsc1d
		inc ,s		;Increment approximate exponent.
		ldx #fpten
		jsr fplod
		jsr fpdiv	;Divide by ten.
		bra fpsc1c
fpsc1d		ldb ,s
		addb #8
		stb ,s		;Adjust decimal exponent (8 decimals)
		ldx #fphalf
		jsr fplod
		jsr fpadd	;Add 0.5 for the final round to integer.		
* Number is either zero or between 100 million and 1 billion.
fpsc2		ldx #intbuf
		jsr uint	;Convert decimal mantissa to integer.
		jsr int2bcd	;Convert to bcd.
		ldb bcdbuf
		addb #'0'
		stb ,y+		;Store digit before decimal point
		ldb #'.'
		stb ,y+		;Store decimal point.
		lda #4
		sta ,-s
		ldx #bcdbuf+1
fpscloop	lda ,x+
		tfr a,b
		lsrb
		lsrb
		lsrb
		lsrb
		addb #'0'	
		stb ,y+
		anda #$0f
		adda #'0	
		sta ,y+
		dec ,s		;Convert the other 8 digits to ASCII
		bne fpscloop
		leas 1,s	;Remove loop counter.
		ldb #'E'
		stb ,y+		;Store the E character.
		lda #'+'
		ldb ,s+		;Get decimal exponent.
		bpl fpsc3	;Test sign of exponent.
		lda #'-'
		negb		;Take absolute value of exponent.
fpsc3		sta ,y+		;Store sign of exponent.
		stb intbuf+3
		clr intbuf+2
		clr intbuf+1
		clr intbuf
		ldx #intbuf
		jsr int2bcd	;Convert decimal exponent to bcd.
		lda bcdbuf+4
		tfr a,b
		lsrb
		lsrb
		lsrb
		lsrb
		addb #'0'	
		stb ,y+		;Convert first exp digit to ascii
		anda #$0f
		adda #'0'
		sta ,y+		;And the second one.
		rts


		include "floatnum.inc"

fpovf		swi
intrange	swi
inval		swi

* This routine takes the square root of an FP number.
* Uses Newton's algorithm.
fpsqrt		tst -4,u
		lbmi inval	;Negative arguments are invalid.
		jsr fptest0
		beq sqdone	;Sqaure root of 0 is 0.
		jsr fpdup
		ldb -5,u
		subb #$80	;Unbias the exponent.
		bpl sq1
		addb #1
sq1		asrb		;Divide exponent by 2.
		addb #$80	;Make it biased again.
		stb -5,u	;This is the initial guess for the root.
		ldb #4		;Do the loop 4 times.
		stb ,-s
sqloop		leax -10,u
		jsr fplod
		leax -10,u
		jsr fplod
		jsr fpdiv	;Divide argument by guess.
		jsr fpadd	;Add to guess.
		dec -5,u	;Divide this by two, giving new guess.
		dec ,s
		bne sqloop
		leas 1,s
		jsr fpexg	
		leau -5,u	;Remove argument, leave final guess.
sqdone		rts	
			
* Compute the floor of an fp number (result is still fp.
fpfloor		ldb -5,u
		cmpb #$9f
		bhs sqdone	;If abs value >=2^31, then already integer.
		ldb -4,u
		stb ,-s		;Stroe sign of number
		andb #$7f
		stb -4,u	;Take absolute value of number.
		ldx #intbuf
		jsr uint	;Convert to int (truncation)
		sta ,-s		;Store number of fraction bits.
		ldx #intbuf
		jsr ufloat	;Convert back to float
		ldd ,s++
		tstb
		bpl sqdone
		sta ,-s
		jsr fpneg	;Negate number if it was negative
		lda ,s+
		beq sqdone
		ldx #fpone
		jsr fplod
		jmp fpsub	;Subtract 1 if negative & not integer.
		
* Floating point modulo operation (floored modulo).
* Integer part of quotient is still left in intbuf
fpmod		leax -10,u
		jsr fplod
		leax -10,u
		jsr fplod
		jsr fpdiv	;Perform division.
		jsr fpfloor
		jsr fpmul	;Multiply Quotient and Divisor
		leax -10,u
		jmp fpsub	;Dividend - quotient*divisor = modulus.		
		

* Now the transcendental functions follow.
* They use approximation polynomials as defined in the
* Handbook of Mathematical Functions by Abramowitz & Stegun.

* Compute polynomial, number of terms in B, coefficients start at Y
fppoly		stb ,-s
		ldx #fpzero
		jsr fplod	;Start with zero.
polyloop	leax ,y
		jsr fplod
		jsr fpadd	;Add next coefficient.
		leay 5,y	
		leax -10,u		
		jsr fplod
		jsr fpmul	;Multiply by x.
		dec ,s
		bne polyloop
		leas 1,s
		jsr fpexg
		leau -5,u	;Remove x from stack.
		rts

add1		ldx #fpone
		jsr fplod
		jsr fpadd
		rts

halfpi		ldx #fpi
		jsr fplod
		dec -5,u
		rts

* sin(x)
fpsin		ldx #fpi
		jsr fplod
		inc -5,u	;Load 2*pi
		jsr fpmod	;Modulo 2pi
		bsr halfpi
		jsr fpcmp	;Compare x to pi/2
		bls sin2
		inc -5,u	;Change pi/2 to pi
		jsr fpsub
		jsr fpneg	;x := pi-x if x>pi/2
		bsr halfpi
		jsr fpneg
		jsr fpcmp	;Compare x to -pi/2
		bhs sin2
		inc -5,u	;Change -pi/2 to -pi
		jsr fpsub
		jsr fpneg
		bra sin3
sin2		leau -5,u	;Drop the compare limit pi/2 or -pi/2
sin3		jsr fpdup
		jsr fpdup
		jsr fpmul	;On stack: x, x*x
		ldy #sincoeff
		ldb #5
		jsr fppoly	;Do the sine polynomial with x*x as argument
		jsr add1	;Add 1 to the result.
		jmp fpmul	;multiply the polynomial result with x.				
* cos(x)
fpcos		jsr halfpi
		jsr fpsub
		jsr fpneg
		bra fpsin	;Compute sin(pi/2-x)

* tan(x)	
fptan		jsr fpdup
		jsr fpsin
		jsr fpexg
		jsr fpcos
		jmp fpdiv	;Compute sin(x)/cos(x)

* atan(x)
fpatan		clr ,-s		;Make flag on stack
		ldb -5,u
		cmpb #$80	;Compare magnitude to 1.
		blo atn1
		inc ,s		;Set flag on stack.
		ldx #fpone	;if x>1 then compute 1/x
		jsr fplod
		jsr fpexg
		jsr fpdiv
atn1		jsr fpdup
		jsr fpdup
		jsr fpmul	;On stack: x, x*x
		ldb #8
		ldy #atancoeff
		jsr fppoly	;Doe the arctan polynomyal, x*x as argument.
		jsr add1	;Add 1 to result
		jsr fpmul	;multiply result by x.
		tst ,s+
		beq atndone		
		jsr halfpi
		jsr fpsub
		jsr fpneg	;Compute pi/2 - result when x was >1
atndone		rts

* exp(x)
fpexp		ldb -4,u
		stb ,-s		;Store sign of x.
		andb #$7f
		stb -4,u	;Take absolute value.
		ldx #fln2
		jsr fplod
		jsr fpmod	;modulo ln2.
		ldb #7
		ldy #expcoeff
		jsr fppoly	;Do the exp(-x) polynomial.
		jsr add1
		tst ,s+
		bpl exppos
		ldb -5,u	;Number was negative.
		subb intbuf+3	;Subtract the integer quotient of the modln2	
		bcs expund	
		lda intbuf
		ora intbuf+1
		ora intbuf+2
		bne expund	;Underflow also if quotient >255
		stb -5,u	;Store exponent.
		rts
exppos		ldx #fpone
		jsr fplod
		jsr fpexg
		jsr fpdiv	;x was postitive, compute 1/exp(-x)
		ldb intbuf
		orb intbuf+1
		orb intbuf+2	;Check int part is less than 255
		lbne fpovf
		ldb -5,u
		addb intbuf+3	;Add integer part to exponent.
		lbcs fpovf	;Check for overflow.	
		stb -5,u
		rts
expund		leau -5,u
		ldx #fpzero
		jmp fplod	;underflow, result is zero.

* ln(x) Natural logarithm
fln		jsr fptest0
		lbeq inval	;Don't accept zero as argument.
		tst -4,u
		lbmi inval	;No negative numbers either.
		ldb -5,u
		stb ,-s		;Save the binary exponent.
		ldb #$80
		stb -5,u	;Replace exponent with 1.
		ldx #fpone	;Argument is now in range 1..2
		jsr fplod
		jsr fpsub	;Subtract 1.
		ldy #lncoeff
		ldb #8
		jsr fppoly	;Do the ln(1+x) polynomial.
		ldb ,s+		;Get original exponent.
		subb #$80	;Unbias it.
		sex
		jsr int2fp	;Convert to fp.
		ldx #fln2
		jsr fplod
		jsr fpmul	;Multiply it by ln2.
		jmp fpadd	;Add that to result.

skipspace	ldb ,y+
		cmpb #' ' 
		beq skipspace
		rts

PROGEND		fdb $FFFF	;Indicate there is no AUTOBOOT app.
				;Flag can be overwritten by it.
FREEMEM		equ ROM*RAMSTART+(1-ROM)*(PROGEND+2)


		end

