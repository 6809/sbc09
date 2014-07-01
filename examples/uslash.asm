	; 6809 32/16 divison
	; 2012-06-20, 2014-07-01 J.E. Klasek j+forth@klasek.at 

	org $100
	lds #$100	
	ldu #$8000	

; Testvalues:
;
; DIVH	DIVL 	DVSR	QUOT	REM
; 0100	0000	FFFF	0100	0100
; 0000  0001    8000	0000	8000
; 0000  5800	3000	0001	1800
; 5800  0000	3000	????	FFFF

DIVH	EQU $0100
DIVL	EQU $0000
DVSR	EQU $FFFF

	bra EFORTH

	; ------------------------------------
	; Version from Talbot System FIG Forth
	; ------------------------------------

TALBOT:

        ; sample parameters on forth parameter stack (U) ...
        ldd #DIVL       ; dividend low word
        pshu d
        ldd #DIVH       ; dividend high word
        pshu d
        ldd #DVSR       ; divisor
        pshu d

USLASH: ldd 2,u         ; dividend swap H/L word
        ldx 4,u
        stx 2,u
        std 4,u
        asl 3,u         ; initial shift of L word
        rol 2,u
        ldx #$10
USL1:   rol 5,u         ; shift H word
        rol 4,u
        ldd 4,u
        subd ,u         ; does divisor fit?
        andcc #$fe	; clc - clear carry flag
        bmi USL2
        std 4,u         ; fits -> quotient = 1
        orcc #$01	; sec - set carry flag
USL2:   rol 3,u         ; L word/quotient
        rol 2,u
        leax -1,x
        bne USL1
        leau 2,u

        ldx ,u          ; quotient
        ldd 2,u         ; remainder

realexit:
	sync




	; ------------------------------------
	; Version from J.E. Klasek, replacing
	; high-level variant in eFORTH.
	; ------------------------------------

EFORTH:
        ; sample parameters on forth parameter stack (S) ...
        ldd #DIVL       ; dividend low word
	pshs d
        ldd #DIVH       ; dividend high word
	pshs d
        ldd #DVSR       ; divisor
	pshs d

;   U/          ( udl udh un -- ur uq )
;               Unsigned divide of a double by a single. Return mod and quotient.
;	
; Handles 2 special cases:
;	1. overflow: quotient overflow if dividend is to great (remainder = divisor),
;		remainder is set to $FFFF.
;		This is checked also right before the main loop.
;	2. underflow: divisor does not fit into dividend -> remainder
;		get the value of the dividend.

USLASH2:
		ldx #16
		ldd 2,s         ; udh
		cmpd ,s		; dividend to great?
		bhs UMMODOV	; quotient overflow!
		asl 5,s         ; udl low
		rol 4,s         ; udl high

UMMOD1:		rolb            ; got one bit from udl
		rola
		bcs UMMOD2	; bit 16 means always greater as divisor
                cmpd ,s         ; divide by un
		bhs UMMOD2      ; higher or same as divisor?
        	andcc #$fe	; clc - clear carry flag
		bra UMMOD3
UMMOD2:		subd ,s
        	orcc #$01	; sec - set carry flag
UMMOD3:		rol 5,s         ; udl, quotient shifted in
		rol 4,s
		leax -1,x
		bne UMMOD1

		ldx 4,s         ; quotient
		cmpd ,s         ; remainder >= divisor -> overflow
		blo UMMOD4
UMMODOV:	ldd #$FFFF	; remainder = FFFF (-1) marks overflow
				; (case 1)
UMMOD4:         
		cmpx #0		; quotient = 0 (underflow) ?
		bne UMMOD5
		ldd 2,s		; yes -> remainder = dividend low
				; (case 2)
UMMOD5:
		leas 2,s        ; un (divisor thrown away)
                stx ,s          ; quotient to TOS
                std 2,s         ; remainder 2nd

		bra realexit

		; not reached
                pulu pc         ; eFORTH NEXT


enddata
  
	end
