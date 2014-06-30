; 6809 CRC16 with tests
;
; Johann E. Klasek, j AT klasek at
;
; Testprogram and finaly submitted to http://beebwiki.mdfs.net/index.php/CRC-16#6809

	org $100
	lds #$8000

; Calculate an XMODEM 16-bit CRC from data in memory. This code is as
; tight and as fast as it can be, moving as much code out of inner
; loops as possible.
;
; On entry, reg. D   = incoming CRC
;           reg. U   = start address of data
;           reg. X   = number of bytes
; On exit,  reg. D   = updated CRC
;           reg. U   = points to first byte behind data
;           reg. X   = 0
;	    reg. Y   = 0
;
; Value order in memory is H,L (big endian)
;
; Multiple passes over data in memory can be made to update the CRC.
; For XMODEM, initial CRC must be 0000.
;
; XMODEM setup:
; polynomic
CRCH	EQU $10
CRCL	EQU $21
; initial CRC
CRCINIT EQU $0000		

; input parameters ...
	ldu #s2		; data (samples: s1 or s2)
	ldb ,u+
	clra
	tfr d,x		; data size
	ldd #CRCINIT	; incoming CRC

crc16:
	
bl:	
	eora ,u+	; fetch byte and XOR into CRC high byte
	ldy #8		; rotate loop counter
rl:	aslb		; shift CRC left, first low
	rola		; and than high byte
	bcc cl		; Justify or ...
	eora #CRCH	; CRC=CRC XOR polynomic, high
	eorb #CRCL	; and low byte
cl:	leay -1,y	; shift loop (8 bits)
	bne rl
	leax -1,x	; byte loop
	bne bl

	; CRC in D

realexit:
	sync

s1:	fcb 19,"An Arbitrary String"
	; CRC=$DDFC
s2:	fcb 26,"ZYXWVUTSRQPONMLKJIHGFEDBCA"
	; CRC=$B199

enddata
  
	end
