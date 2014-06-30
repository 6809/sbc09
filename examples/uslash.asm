    	; 6809 32/16 divison, from Talbot System FIG Forth
    	; 2012-06-20 J.E. Klasek j+forth@klasek.at
    	; 2014-06-30 Bugfix clc/sec - Jens Diemer
    	org $100
    	lds #$100	
    	ldu #$8000	

	    ; sample parameters on stack ...
	    ldd #$0000	    ; dividend low word
	    pshu d
	    ldd #$5800	    ; dividend high word
	    pshu d
	    ldd #$3000	    ; divisor
	    pshu d

USLASH	ldd 2,u		; dividend swap H/L word
	    ldx 4,u
	    stx 2,u
	    std 4,u
	    asl 3,u		    ; initial shift of L word
	    rol 2,u
	    ldx #$10
USL1:	rol 5,u		; shift H word
	    rol 4,u
	    ldd 4,u
	    subd ,u		    ; does divisor fit?
	    ANDCC #$FE      ; clc - clear carry flag
	    bmi USL2
	    std 4,u		    ; fits -> quotient = 1
	    ORCC #$01       ; sec - Set Carry flag
USL2:	rol 3,u		; L word/quotient
	    rol 2,u
	    leax -1,x
	    bne USL1
	    leau 2,u

	    ldx ,u		    ; quotient
	    ldd 2,u		    ; remainder

realexit sync

enddata
  
	end
