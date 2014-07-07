        ; 6809 32/16 divison for a forth environment
        ; 2012-06-20, 2014-07-01 J.E. Klasek j+forth@klasek.at 
        ;
        ; There are two implementations:
        ;       TALBOT  just for analysis, not really used here.
        ;       EFORTH  advanced and optimized version for ef09
        ;
        ; EFORTH version's special cases:
        ;   overflow:           quotient = $FFFF, remainder = divisor
        ;   underflow:          quotient = $0000, remainder = dividend low
        ;   division by zero:   quotient = $FFFF, remainder = $0000

        org $100
        lds #$100       
        ldu #$8000      

; Testvalues:
;
; DIVH  DIVL    DVSR    QUOT    REM     comment
;
; 0100  0000    FFFF    0100    0100    maximum divisor
; 0000  0001    8000    0000    0001    underflow (REM = DIVL)
; 0000  5800    3000    0001    1800    normal divsion
; 5800  0000    3000    FFFF    3000    overflow
; 0000  0001    0000    FFFF    0000    overflow (division by zero)
;

DIVH    EQU $0000
DIVL    EQU $5800
DVSR    EQU $3000

        bra EFORTH      ; comment out to try TALBOT's version

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
        andcc #$fe      ; clc - clear carry flag
        bmi USL2
        std 4,u         ; fits -> quotient = 1
        orcc #$01       ; sec - set carry flag
USL2:   rol 3,u         ; L word/quotient
        rol 2,u
        leax -1,x
        bne USL1
        leau 2,u        ; drop divisor from parameter stack

                        ; into registers for simulator ...

        ldx ,u          ; quotient on TOS
        ldd 2,u         ; remainder on 2nd

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
; Special cases:
;       1. overflow: quotient overflow if dividend is to great (remainder = divisor),
;               remainder is set to $FFFF -> special handling.
;               This is checked also right before the main loop.
;       2. underflow: divisor does not fit into dividend -> remainder
;               get the value of the dividend -> automatically covered.

USLASH2:
        ldx #16
        ldd 2,s         ; udh
        cmpd ,s         ; dividend to great?
        bhs UMMODOV     ; quotient overflow!
        asl 5,s         ; udl low
        rol 4,s         ; udl high

UMMOD1: rolb            ; got one bit from udl
        rola
        bcs UMMOD2      ; bit 16 means always greater as divisor
        cmpd ,s         ; divide by un
        bhs UMMOD2      ; higher or same as divisor?
        andcc #$fe      ; clc - clear carry flag
        bra UMMOD3
UMMOD2: subd ,s
        orcc #$01       ; sec - set carry flag
UMMOD3: rol 5,s         ; udl, quotient shifted in
        rol 4,s
        leax -1,x
        bne UMMOD1

        ldx 4,s         ; quotient
        cmpd ,s         ; remainder >= divisor -> overflow
        blo UMMOD4
UMMODOV:
        ldd ,s          ; remainder set to divisor
        ldx #$FFFF      ; quotient = FFFF (-1) marks overflow
                                ; (case 1)
UMMOD4:         
        leas 2,s        ; un (divisor thrown away)
        stx ,s          ; quotient to TOS
        std 2,s         ; remainder 2nd

        bra realexit

        ; not reached
        pulu pc         ; eFORTH NEXT

enddata
  
        end
