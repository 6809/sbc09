	;6809 32/16 divison, from Talbot System FIG Forth
	; 2012-06-20 J.E. Klasek j+forth@klasek.at
	org $100
	lds #$100	
	ldu #$8000	

	ldd #$0000	; lowword
	pshu d
	ldd #$5800	; high word
	pshu d
	ldd #$3000	; divisor
	pshu d

USLASH	ldd 2,u		; divident H/L Word tauschen
	ldx 4,u
	stx 2,u
	std 4,u
	asl 3,u		; initial L Word shiften
	rol 2,u
	ldx #$10
USL1:	rol 5,u		; H Word shift
	rol 4,u
	ldd 4,u
	subd ,u		; passt Divisor?
	clc
	bmi USL2
	std 4,u		; passt -> Quot = 1
	sec
USL2:	rol 3,u		; L Wort/Quotient
	rol 2,u
	leax -1,x
	bne USL1
	leau 2,u

	ldx ,u		; quot
	ldd 2,u		; remainder

realexit sync

enddata
  
	end
