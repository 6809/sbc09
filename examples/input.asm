	;6809 Benchmark program.

	org $100

	lds #$100	

	ldb #'a'
	jsr outc	
	
	
	ldx #40
inloop	jsr inc
	jsr outc
	leax -1,x
	bne inloop
	
        ldb #'b'
	jsr outc
	jmp realexit 

error	ldb #'e'
	jsr outc
	jmp realexit

outc	swi2
	rts

inc	swi3
	rts

realexit sync

enddata
  
	end
