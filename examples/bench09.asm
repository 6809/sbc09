	;6809 Benchmark program.

	org $100

	lds #$100	

	ldb #'a'
	jsr outc	
	
	
	ldy #0
loop	ldx #data
	lda #(enddata-data)
	clrb	
loop2:	addb ,x+
	deca
	bne loop2
	cmpb #210
	lbne error		
        leay -1,y
	bne loop

        ldb #'b'
	jsr outc
	jmp realexit 

error	ldb #'e'
	jsr outc
	jmp realexit

outc	swi2
	rts

realexit sync

data 	fcb 1,2,3,4,5,6,7,8,9,10
	fcb 11,12,13,14,15,16,17,18,19,20
enddata
  
	end
