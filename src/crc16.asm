	;6809 CRC16 with tests
	org $100
	lds #$8000

; XMODEM CRC
CRCH	EQU $10
CRCL	EQU $21
CRCINIT EQU $0000		

	ldu #s2
	ldb ,u+
	clra
	tfr d,x
	ldd #CRCINIT
	
bl:	eora ,u+
	ldy #8
rl:	aslb
	rola
	bcc cl
	eora #CRCH
	eorb #CRCL
cl:	leay -1,y
	bne rl
	leax -1,x
	bne bl

	; CRC in D

realexit sync

s1:	fcb 19,"An Arbitrary String"
	; CRC=$DDFC
s2:	fcb 26,"ZYXWVUTSRQPONMLKJIHGFEDBCA"
	; CRC=$B199

enddata
  
	end
