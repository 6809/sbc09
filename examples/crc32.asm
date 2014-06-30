; 6809 CRC32 with tests
;
; Johann E. Klasek, j AT klasek at
;
; Testprogram, previous version submitted to http://beebwiki.mdfs.net/index.php/CRC-32#6809

	org $100
	lds #$8000

; Calculate a ZIP 32-bit CRC from data in memory. This code is as
; tight and nearly as fast as it can be, moving as much code out of inner
; loops as possible. With the included optimisation, moving the whole
; CRC in registers, the performane gain on average data is only slight
; (estimated 2% but at losing clarity of implementation;
; worst case gain is 18%, best case worsens at 29%)
;
; On entry, crc..crc+3  = incoming CRC
;           reg. U      = start address of data
;           reg. X      = number of bytes
; On exit,  crc..crc+3  = updated CRC
;           reg. U      = points to first byte behind data
;           reg. X      = 0
;	    reg. Y      = 0
;
; Value order in memory is H,L (big endian)
;
; Multiple passes over data in memory can be made to update the CRC.
; For ZIP, initial CRC must be $FFFFFFFF, and the final CRC must
; be EORed with $FFFFFFFF before being stored in the ZIP file.
; Total 47 bytes (if above parameters are located in direct page).
;
; ZIP polynomic, reflected (bit reversed) from $04C11DB7
CRCHH	EQU $ED
CRCHL	EQU $B8
CRCLH	EQU $83
CRCLL	EQU $20
CRCINITH EQU $FFFF		
CRCINITL EQU $FFFF		

; CRC 32 bit in DP (4 bytes)
crc	EQU $80

	ldu #s1		; start address in u 
	ldb ,u+		;
	clra		; length in d
	leax d,u	; 
	pshs x		; end address +1 to TOS
	ldd #CRCINITL
	std crc+2
	ldx #CRCINITH
	stx crc
			; d/x contains the CRC
bl:	
	eorb ,u+	; XOR with lowest byte
	ldy #8		; bit counter
rl:
	exg d,x
rl1:
	lsra		; shift CRC right, beginning with high word
	rorb
	exg d,x
	rora		; low word
	rorb
	bcc cl
			; CRC=CRC XOR polynomic
	eora #CRCLH	; apply CRC polynomic low word
	eorb #CRCLL
	exg d,x
	eora #CRCHH	; apply CRC polynomic high word
	eorb #CRCHL
	leay -1,y	; bit count down
	bne rl1
	exg d,x		; CRC: restore correct order
	beq el		; leave bit loop
cl:
	leay -1,y	; bit count down
	bne rl		; bit loop
el:
	cmpu ,s		; end address reached?
	bne bl		; byte loop

	std crc+2	; CRC low word
	stx crc		; CRC high word


realexit:
	sync


s1:	fcb 19,"An Arbitrary String"
	; CRC=$90415518 

s2:	fcb 26,"ZYXWVUTSRQPONMLKJIHGFEDBCA"
	; CRC32=$6632024D

enddata
  
	end
