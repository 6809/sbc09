	;print value as decimal 

	org $100

	ldx	#$ff00
loop:
	bsr printdec
	ldb #32
	swi2
	leax 1,x
    bne loop
	sync


printdec:
    pshs cc,d,x		; save regs
    lda #$80		; init. terminator
nxtdg:
	sta ,-s			; push digit term
    ldb #16			; 16 bit counter for rotate
    clra			; clear accu and carry
roll:
	rola			; divide by 10 using binary
	adda #$f6		; long division, shifting X one
    bcs sub			; bit at a time info A and
    suba #$f6		; subtracting 10 which sets
sub:
    exg d,x			; C if sub goes, else add 10
    rolb			; back and reset C. Rotating X
    rola			; by means of A & B both shifts
	exg d,x			; X bits into A and shifts
	decb			; result bits into X. Do 17
	bpl roll		; times to get last result bit.
	leax ,x			; test X and repeat if
    bne nxtdg		; X is not zero
	tfr a,b
prog:
	orb #$30		; make into ASCII digit, call
    swi2			; print char
	ldb ,s+			; pull next digit of stack and
	bpl	prog		; repeat if not terminator
	puls cc,d,x,pc	; restore regs and return

  
	end

