	;6809 CRC32 with tests
	org $100
	lds #$8000

; ZIP CRC, already reflected from $04C11DB7
CRCHH	EQU $ED
CRCHL	EQU $B8
CRCLH	EQU $83
CRCLL	EQU $20
CRCINITH EQU $FFFF		
CRCINITL EQU $FFFF		

; CRC 32 bit in DP
crc	EQU $80

	ldu #s1
	ldb ,u+		; start address in u
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
	ldy #8		; Bit counter
rl:
	exg d,x
rl1:
	lsra		; Shift CRC right, beginning with high word
	rorb
	exg d,x
	rora		; low word
	rorb
	bcc cl
	eora #CRCLH	; Apply CRC polynomic low word
	eorb #CRCLL
	exg d,x
	eora #CRCHH	; Apply CRC polynomic high word
	eorb #CRCHL
	leay -1,y	; Bit count down
	bne rl1
	exg d,x
	beq el
cl:
	leay -1,y	; Bit count down
	bne rl
el:
	cmpu ,s		; end address reached?
	bne bl

	std crc+2	; CRC low word
	stx crc		; CRC high word



realexit sync

s1:	fcb 19,"An Arbitrary String"
	; CRC=$90415518 

s2:	fcb 26,"ZYXWVUTSRQPONMLKJIHGFEDBCA"
	; CRC32=$6632024D

enddata
  
	end
