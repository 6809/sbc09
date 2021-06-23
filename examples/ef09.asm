     ;TITLE 6809 eForth

; $Id: ef09.asm,v 1.1 1997/11/24 02:56:01 root Exp $
;
;===============================================================
;
;	eForth 1.0 by Bill Muench and C. H. Ting, 1990
;	Much of the code is derived from the following sources:
;		8086 figForth by Thomas Newman, 1981 and Joe smith, 1983
;		aFORTH by John Rible
;		bFORTH by Bill Muench
;
;	The goal of this implementation is to provide a simple eForth Model
;	which can be ported easily to many 8, 16, 24 and 32 bit CPU's.
;	The following attributes make it suitable for CPU's of the '90:
;
;		small machine dependent kernel and portable high level code
;		source code in the MASM format
;		direct threaded code
;		separated code and name dictionaries
;		simple vectored terminal and file interface to host computer
;		aligned with the proposed ANS Forth Standard
;		easy upgrade path to optimize for specific CPU
;
;	You are invited to implement this Model on your favorite CPU and
;	contribute it to the eForth Library for public use. You may use
;	a portable implementation to advertise more sophisticated and
;	optimized version for commercial purposes. However, you are
;	expected to implement the Model faithfully. The eForth Working
;	Group reserves the right to reject implementation which deviates
;	significantly from this Model.
;
;	As the ANS Forth Standard is still evolving, this Model will
;	change accordingly. Implementations must state clearly the
;	version number of the Model being tracked.
;
;	Representing the eForth Working Group in the Silicon Valley FIG Chapter.
;	Send contributions to:
;
;		Dr. C. H. Ting
;		156 14th Avenue
;		San Mateo, CA 94402
;		(415) 571-7639
;
;===============================================================
; $Log: ef09.asm,v $
; Revision 1.1  1997/11/24 02:56:01  root
; Initial revision
;
;===============================================================
;; Version control

VER		EQU	1			;major release version
EXT		EQU	0			;minor extension

;; Constants

TRUEE		EQU	-1			;true flag

COMPO		EQU	$40			;lexicon compile only bit
IMEDD		EQU	$80			;lexicon immediate bit
MASKK		EQU	$1F7F			;lexicon bit mask

CFAOFF		EQU	3			;offset from word entry to code field area
						; (length of JSR)
CELLL		EQU	2			;size of a cell
BASEE		EQU	10			;default radix
VOCSS		EQU	8			;depth of vocabulary stack

BKSPP		EQU	8			;back space
BKSPP2		EQU	127			;back space
LF		EQU	10			;line feed
CRR		EQU	13			;carriage return
ERR		EQU	27			;error escape
TIC		EQU	39			;tick

CALLL		EQU	$12BD			;NOP CALL opcodes

;; Memory allocation

EM		EQU	$4000			;top of memory
US		EQU	64*CELLL		;user area size in cells
RTS		EQU	128*CELLL		;return stack/TIB size

UPP		EQU	EM-US			;start of user area (UP0)
RPP		EQU	UPP-8*CELLL		;start of return stack (RP0)
TIBB		EQU	RPP-RTS			;terminal input buffer (TIB)
SPP		EQU	TIBB-8*CELLL		;start of data stack (SP0)

COLDD		EQU	$100			;cold start vector
CODEE		EQU	COLDD+US		;code dictionary
NAMEE		EQU	EM-$0400		;name dictionary

;; Initialize assembly variables


;; Main entry points and COLD start data


		ORG	COLDD			;beginning of cold boot area
		SETDP   0

ORIG		lds #SPP			;Init stack pointer.
		ldy #RPP			;Init return stack pointer
		ldu #COLD1			;Init Instr pointer.
		pulu pc				;next.

; COLD start moves the following to USER variables.
; MUST BE IN SAME ORDER AS USER VARIABLES.


UZERO		FCB     0,0,0,0,0,0,0,0		;reserved space in user area
		FDB	SPP			;SP0
		FDB	RPP			;RP0
		FDB	QRX			;'?KEY
		FDB	TXSTO			;'EMIT
		FDB	ACCEP			;'EXPECT
		FDB	KTAP			;'TAP
		FDB	TXSTO			;'ECHO
		FDB	DOTOK			;'PROMPT
		FDB	BASEE			;BASE
		FDB	0			;tmp
		FDB	0			;SPAN
		FDB	0			;>IN
		FDB	0			;#TIB
		FDB	TIBB			;TIB
		FDB	0			;CSP
		FDB	INTER			;'EVAL
		FDB	NUMBQ			;'NUMBER
		FDB	0			;HLD
		FDB	0			;HANDLER
		FDB	0			;CONTEXT pointer
		FDB     0,0,0,0,0,0,0,0		;vocabulary stack (VOCSS*2 bytes)
		FDB	0			;CURRENT pointer
		FDB	0			;vocabulary link pointer
		FDB	CTOP			;CP
		FDB	NTOP			;NP
		FDB	LASTN			;LAST
ULAST

		ORG	CODEE			;beginning of the code dictionary

;; Device dependent I/O

;   BYE		( -- )
;		Exit eForth.

		FDB BYE,0		
L100		FCB 3,"BYE"
BYE		sync
		
;   ?RX		( -- c T | F )
;		Return input character and true, or a false if no input.

		FDB QRX,L100
L110		FCB 3,"?RX"
QRX		ldx #0
		swi3
		bcc qrx1
		stx ,--s
		pulu pc
qrx1		clra
		std ,--s
		leax -1,x
		stx ,--s
		pulu pc

;   TX!		( c -- )
;		Send character c to the output device.
		FDB TXSTO,L110
L120		FCB 3,"TX!"
TXSTO		ldd ,s++
		cmpb #$ff
		bne tx1
		ldb #32
tx1		swi2
		pulu pc


;   !IO		( -- )
;		Initialize the serial I/O devices.

		FDB STOIO,L120
L130		FCB 3,"!IO"
STOIO		pulu pc

;; The kernel

;   doLIT	( -- w )
;		Push an inline literal.
		
		FDB DOLIT,L130
L140		FCB COMPO+5,"doLIT"
DOLIT
;;;;		ldd ,u++
		pulu d
; 7 cycles
		pshs d
;;;; 8 cycles
;;;;		std ,--s
		pulu pc

;   doCLIT	( -- w )
;		Push an inline 8-bit literal.
		
		FDB DOCLIT,L140
L141		FCB COMPO+6,"doCLIT"
DOCLIT
		pulu b
		sex		; sign extended
		pshs d
		pulu pc

;   doLIST	( a -- )
;		Process colon list.

		FDB DOLST,L141
L150		FCB COMPO+6,"doLIST"
DOLST		stu ,--y		; IP on return stack
		puls u			; JSR left new IP on parameter stack
;;;;		ldu ,s++
		pulu pc			; FORTH NEXT IP

;   next	( -- )
;		Run time code for the single index loop.
;		: next ( -- ) \ hilevel model
;		  r> r> dup if 1 - >r @ >r exit then drop cell+ >r ;

		FDB DONXT,L150
L160		FCB COMPO+4,"next"
DONXT		ldd ,y			; counter on return stack
		subd #1			; decrement
		bcs next1		; < -> exit loop
		std ,y			; decremented value back on stack
		ldu ,u			; branch to begin of loop
		pulu pc
next1		leay 2,y		; remove counter from stack
		leau 2,u		; skip branch destination
		pulu pc


;   ?branch	( f -- )
;		Branch if flag is zero.

		FDB QBRAN,L160
L170		FCB COMPO+7,"?branch"
QBRAN		;$CODE	COMPO+7,'?branch',QBRAN
		ldd ,s++
		beq bran1
		leau 2,u	; skip new IP, no branch
		pulu pc
bran1		ldu ,u		; go to new IP
		pulu pc

;   branch	( -- )
;		Branch to an inline address.
		
		FDB BRAN,L170
L180		FCB COMPO+6,"branch"
BRAN		ldu ,u		; destination immediate after BRANCH
		pulu pc

;   EXECUTE	( ca -- )
;		Execute the word at ca.

		FDB EXECU,L180
L190		FCB 7,"EXECUTE"
EXECU		rts		; code pointer on parameter stack

;   EXIT	( -- )
;   SEMIS
;		Terminate a colon definition.

		FDB EXIT,L190
L200		FCB 4,"EXIT"
EXIT		ldu ,y++	; get calling IP from return stack
		pulu pc

;   !		( w a -- )
;		Pop the data stack to memory.
		
		FDB STORE,L200
L210		FCB 1,"!"
STORE
;;;;	 	ldx ,s++
;;;;		ldd ,s++
;;;; faster ...
		puls x
		puls d
		; we cannot use puls x,d because the order fetched would be wrong :(
		std ,x
		pulu pc

;   @		( a -- w )
;		Push memory location to the data stack.

		FDB AT,L210
L220		FCB 1,"@"
AT		ldd [,s]
		std ,s
		pulu pc

;   C!		( c b -- )
;		Pop the data stack to byte memory.

		FDB CSTOR,L220
L230		FCB 2,"C!"
CSTOR
;;;;	 	ldx ,s++
;;;;		ldd ,s++
;;;; faster ...
		puls x
		puls d
		; we cannot use puls x,d because the order fetched would be wrong :(
		stb ,x
		pulu pc


;   C@		( b -- c )
;		Push byte memory location to the data stack.

		FDB CAT,L230
L240		FCB 2,"C@"
CAT		ldb [,s]
		clra
		std ,s
		pulu pc

;   RP@		( -- a )
;		Push the current RP to the data stack.

		FDB RPAT,L240
L250		FCB 3,"RP@"
RPAT		pshs y
		pulu pc

;   RP!		( a -- )
;		Set the return stack pointer.

		FDB RPSTO,L250
L260		FCB 3,"RP!"
RPSTO		puls y
		pulu pc

;   R>		( -- w )
;		Pop the return stack to the data stack.

		FDB RFROM,L260
L270		FCB 2,"R>"
RFROM		ldd ,y++
;;;;		std ,--s
		pshs d
		pulu pc

;   I		( -- w )
;		Copy top of return stack (current index from DO/LOOP) to the data stack.

		FDB RAT,L270
L279		FCB 1,"I"

;   R@		( -- w )
;		Copy top of return stack to the data stack.

		FDB RAT,L279
L280		FCB 2,"R@"
RAT
I
		ldd ,y
;;;;		std ,--s
		pshs d
		pulu pc

;   >R		( w -- )
;		Push the data stack to the return stack.

		FDB TOR,L280
L290		FCB 2,">R"
TOR
;;;;		ldd ,s++
		puls d
		std ,--y
		pulu pc

;   SP@		( -- a )
;		Push the current data stack pointer.

		FDB SPAT,L290
L300		FCB 3,"SP@"
SPAT
		tfr s,d
		std ,--s
;;;; alternatively
;;;;		sts ,--s        ; does this work?
		pulu pc

;   SP!		( a -- )
;		Set the data stack pointer.

		FDB SPSTO,L300
L310		FCB 3,"SP!"
SPSTO		lds ,s
		pulu pc

;   DROP	( w -- )
;		Discard top stack item.

		FDB DROP,L310
L320		FCB 4,"DROP"
DROP		leas 2,s
		pulu pc

;   DUP		( w -- w w )
;		Duplicate the top stack item.

		FDB DUPP,L320
L330		FCB 3,"DUP"
DUPP		ldd ,s
;;;;		std ,--s
		pshs d
		pulu pc

;   SWAP	( w1 w2 -- w2 w1 )
;		Exchange top two stack items.

		FDB SWAP,L330
L340		FCB 4,"SWAP"
SWAP
;;;;OLD 1: slow
;;;;		ldx ,s++
;;;;		ldd ,s++
;;;;OLD 2: faster
;;;;		puls x
;;;;		puls d
;;;;		pshs d,x
;more efficient, without unnecessary stack pointer manipulations
		ldd ,s
		ldx 2,s
		std 2,s	
		stx ,s
		pulu pc
		
;   OVER	( w1 w2 -- w1 w2 w1 )
;		Copy second stack item to top.

		FDB OVER,L340
L350		FCB 4,"OVER"
OVER		ldd 2,s
;;;;		std ,--s
		pshs d
		pulu pc

;   0<		( n -- t )
;		Return true if n is negative.

		FDB ZLESS,L350
L360		FCB 2,"0<"
ZLESS		ldb ,s		; input high byte, as D low
		sex		; sign extend to b to a/b
		tfr a,b		; high byte: 0 or FF copy to D low
		std ,s		; D: 0000 or FFFF (= -1)
		pulu pc

;   0=		( n -- t )
;		Return true if n is zero

		FDB ZEQUAL,L360
L365		FCB 2,"0="
ZEQUAL
		ldx #TRUEE	; true
		ldd ,s		; TOS
		beq ZEQUAL1	; -> true
		ldx #0		; false		
ZEQUAL1		stx ,s		; D: 0000 or FFFF (= -1)
		pulu pc

;   AND		( w w -- w )
;		Bitwise AND.

		FDB ANDD,L365
L370		FCB 3,"AND"
ANDD		ldd ,s++
		anda ,s
		andb 1,s
		std ,s
		pulu pc

;   OR		( w w -- w )
;		Bitwise inclusive OR.

		FDB ORR,L370
L380		FCB 2,"OR"
ORR		ldd ,s++
		ora ,s
		orb 1,s
		std ,s
		pulu pc

;   XOR		( w w -- w )
;		Bitwise exclusive OR.

		FDB XORR,L380
L390		FCB 3,"XOR"
XORR		ldd ,s++
		eora ,s
		eorb 1,s
		std ,s
		pulu pc

;   D+		( ud ud -- udsum )
;		Add two unsigned double numbers and return a double sum.

		FDB DPLUS,L390
L391		FCB 2,"D+"
DPLUS		ldd 2,s		; add low words
		addd 6,s
		std 6,s
		ldd ,s		; add hig words
		adcb 5,s
		adca 4,s
		std 4,s
		leas 4,s	; drop one double
		pulu pc

;   D-		( ud ud -- uddiff )
;		Subtract two unsigned double numbers and return a double sum.

		FDB DSUB,L391
L392		FCB 2,"D-"
DSUB		jsr DOLST
		FDB DNEGA,DPLUS,EXIT


;   UM+		( u u -- udsum )
;		Add two unsigned single numbers and return a double sum.

		FDB UPLUS,L392
L400		FCB 3,"UM+"
UPLUS		ldd ,s
		addd 2,s
		std 2,s
		ldd #0
		adcb #0
		std ,s
		pulu pc

;; Constants

;   doCONST	( -- w )
;		Run time routine for CONSTANT

		FDB DOCONST,L400
L401		FCB COMPO+7,"doCONST"
DOCONST
FDOCONST
		ldd [,s]	; contents of W (on TOS because of JSR)
		std ,s		; to TOS (replacing W)
		pulu pc

;   0		( -- 0 )
;		Constant 0

		FDB ZERO,L401
L402		FCB 1,"0"
ZERO		jsr FDOCONST
		FDB 0

;   1		( -- 1 )
;		Constant 1

		FDB ONE,L402
L403		FCB 1,"1"
ONE		jsr FDOCONST
		FDB 1

;   2		( -- 2 )
;		Constant 2

		FDB TWO,L403
L404		FCB 1,"2"
TWO		jsr FDOCONST
		FDB 2


;   -1		( -- -1 )
;		Constant -1

		FDB MONE,L404
L405		FCB 2,"-1"
MONE		jsr FDOCONST
		FDB -1

;; System and user variables

;   doVAR	( -- a )
;		Run time routine for VARIABLE and CREATE.

		FDB DOVAR,L405
L410		FCB COMPO+5,"doVAR"
DOVAR		
		jsr DOLST
		FDB RFROM,EXIT

;; fast native DOVAR implementation
FDOVAR		pulu pc
		  

;   UP		( -- a )
;		Pointer to the user area.

		FDB UP,L410
L420		FCB 2,"UP"
UP		
;;		jsr DOLST
;;		FDB	DOVAR
;; fast (native) DOVAR
		jsr FDOVAR
		FDB	UPP

;   doUSER	( -- a )
;		Run time routine for user variables.

		FDB DOUSE,L420
L430		FCB COMPO+5,"doUSER"
DOUSE 		
		jsr DOLST
		FDB RFROM,AT,UP,AT,PLUS,EXIT

;; fast (native) DOUSE implementation (*NOT COMPLETE*)
FDOUSE
		ldd [,s]	; pointer to value (from JSR)
		addd UP+CFAOFF	; dirty access to start of USER area:
				; var. UP value direct access (not
				; as a high level word)
		std ,s		; resulting address returned on p-stack
		pulu pc
		
;   SP0		( -- a )
;		Pointer to bottom of the data stack.

		FDB SZERO,L430
L440		FCB 3,"SP0"
SZERO		
		jsr FDOUSE
		FDB 8
;;;;		jsr DOLST
;;;;		FDB DOUSE,8

;   RP0		( -- a )
;		Pointer to bottom of the return stack.

		FDB RZERO,L440
L450		FCB 3,"RP0"
RZERO		
		jsr FDOUSE
		FDB 10
;;;;		jsr DOLST
;;;;		FDB DOUSE,10

;   '?KEY	( -- a )
;		Execution vector of ?KEY.

		FDB TQKEY,L450
L460		FCB 5,"'?KEY"
TQKEY		
		jsr FDOUSE
		FDB 12
;;;;		jsr DOLST
;;;;		FDB DOUSE,12

;   'EMIT	( -- a )
;		Execution vector of EMIT.

		FDB TEMIT,L460
L470		FCB 5,"'EMIT"
TEMIT		
		jsr FDOUSE
		FDB 14
;;		jsr DOLST
;;		FDB DOUSE,14

;   'EXPECT	( -- a )
;		Execution vector of EXPECT.

		FDB TEXPE,L470
L480		FCB 7,"'EXPECT"
TEXPE		
		jsr FDOUSE
		FDB 16
;;;;		jsr DOLST
;;;;		FDB DOUSE,16

;   'TAP	( -- a )
;		Execution vector of TAP.

		FDB TTAP,L480
L490		FCB 4,"'TAP"
TTAP		
		jsr FDOUSE
		FDB 18
;;;;		jsr DOLST
;;;;		FDB DOUSE,18

;   'ECHO	( -- a )
;		Execution vector of ECHO.

		FDB TECHO,L490
L500		FCB 5,"'ECHO"
TECHO		
		jsr FDOUSE
		FDB 20
;;;;		jsr DOLST
;;;;		FDB DOUSE,20

;   'PROMPT	( -- a )
;		Execution vector of PROMPT.

		FDB TPROM,L500
L510		FCB 7,"'PROMPT"
TPROM		
		jsr FDOUSE
		FDB 22
;;;;		jsr DOLST
;;;;		FDB DOUSE,22


;   BASE	( -- a )
;		Storage of the radix base for numeric I/O.

		FDB BASE,L510
L520		FCB 4,"BASE"
BASE		
		jsr FDOUSE
		FDB 24
;;;;		jsr DOLST
;;;;		FDB DOUSE,24		

;   tmp		( -- a )
;		A temporary storage location used in parse and find.

		FDB TEMP,L520
L530		FCB COMPO+3,"tmp"
TEMP		
		jsr FDOUSE
		FDB 26
;;;;		jsr DOLST
;;;;		FDB DOUSE,26
 
;   SPAN	( -- a )
;		Hold character count received by EXPECT.

		FDB SPAN,L530
L540		FCB 4,"SPAN"
SPAN		
		jsr FDOUSE
		FDB 28
;;;;		jsr DOLST
;;;;		FDB DOUSE,28
		
;   >IN		( -- a )
;		Hold the character pointer while parsing input stream.

		FDB INN,L540
L550		FCB 3,">IN"
INN		
		jsr FDOUSE
		FDB 30
;;;;		jsr DOLST
;;;;		FDB DOUSE,30

;   #TIB	( -- a )
;		Hold the current count in and address of the terminal input buffer.

		FDB NTIB,L550
L560		FCB 4,"#TIB"
NTIB		
		jsr FDOUSE
		FDB 32
;;;;		jsr DOLST
;;;;		FDB DOUSE,32 ;It contains TWO cells!!!!

;   CSP		( -- a )
;		Hold the stack pointer for error checking.

		FDB CSP,L560
L570		FCB 3,"CSP"
CSP		
		jsr FDOUSE
		FDB 36
;;;;		jsr DOLST
;;;;		FDB DOUSE 36

;   'EVAL	( -- a )
;		Execution vector of EVAL.

		FDB TEVAL,L570
L580		FCB 5,"'EVAL"
TEVAL		
		jsr FDOUSE
		FDB 38
;;;;		jsr DOLST
;;;;		FDB DOUSE,38

;   'NUMBER	( -- a )
;		Execution vector of NUMBER?.

		FDB TNUMB,L580
L590		FCB 7,"'NUMBER"
TNUMB		
		jsr FDOUSE
		FDB 40
;;;;		jsr DOLST
;;;;		FDB DOUSE,40

;   HLD		( -- a )
;		Hold a pointer in building a numeric output string.

		FDB HLD,L590
L600		FCB 3,"HLD"
HLD		
		jsr FDOUSE
		FDB 42
;;;;		jsr DOLST
;;;;		FDB DOUSE,42

;   HANDLER	( -- a )
;		Hold the return stack pointer for error handling.

		FDB HANDL,L600
L610		FCB 7,"HANDLER"
HANDL		
		jsr FDOUSE
		FDB 44
;;;;		jsr DOLST
;;;;		FDB DOUSE,44

;   CONTEXT	( -- a )
;		A area to specify vocabulary search order.

		FDB CNTXT,L610
L620		FCB 7,"CONTEXT"
CNTXT		
		jsr FDOUSE
		FDB 46
;;;;		jsr DOLST
;;;;		FDB DOUSE,46        ;plus space for voc stack.

;   CURRENT	( -- a )
;		Point to the vocabulary to be extended.

		FDB CRRNT,L620
L630		FCB 7,"CURRENT"
CRRNT		
		jsr FDOUSE
		FDB 48+VOCSS*2  ;Extra cell
;;;;		jsr DOLST
;;;;		FDB DOUSE,48+VOCSS*2  ;Extra cell

;   CP		( -- a )
;		Point to the top of the code dictionary.

		FDB CP,L630
L640		FCB 2,"CP"
CP		
		jsr FDOUSE
		FDB 52+VOCSS*2
;;;;		jsr DOLST
;;;;		FDB DOUSE,52+VOCSS*2

;   NP		( -- a )
;		Point to the bottom of the name dictionary.
		
		FDB NP,L640
L650		FCB 2,"NP"
NP		
		jsr FDOUSE
		FDB 54+VOCSS*2
;;;;		jsr DOLST
;;;;		FDB DOUSE,54+VOCSS*2

;   LAST	( -- a )
;		Point to the last name in the name dictionary.

		FDB LAST,L650
L660		FCB 4,"LAST"
LAST		
		jsr FDOUSE
		FDB 56+VOCSS*2
;;;;		jsr DOLST
;;;;		FDB DOUSE,56+VOCSS*2

;; Common functions

;   doVOC	( -- )
;		Run time action of VOCABULARY's.

		FDB DOVOC,L660
L670		FCB COMPO+5,"doVOC"
DOVOC		
		jsr DOLST
		FDB RFROM,CNTXT,STORE,EXIT

;   FORTH	( -- )
;		Make FORTH the context vocabulary.

		FDB FORTH,L670
L680		FCB 5,"FORTH"
FORTH 		
		jsr DOLST
		FDB	DOVOC
		FDB	0			;vocabulary head pointer
		FDB	0			;vocabulary link pointer

;   ?DUP	( w -- w w | 0 )
;		Dup tos if its is not zero.

		FDB QDUP,L680
L690		FCB 4,"?DUP"
QDUP		
		jsr DOLST
		FDB	DUPP
		FDB	QBRAN,QDUP1
		FDB	DUPP
QDUP1		FDB	EXIT

;   ROT		( w1 w2 w3 -- w2 w3 w1 )
;		Rot 3rd item to top.

		FDB ROT,L690
L700		FCB 3,"ROT"
ROT		
		jsr DOLST
		FDB	TOR,SWAP,RFROM,SWAP,EXIT

;   2DROP	( w w -- )
;		Discard two items on stack.

		FDB DDROP,L700
L710		FCB 5,"2DROP"
DDROP		
		jsr DOLST
		FDB	DROP,DROP,EXIT

;   2DUP	( w1 w2 -- w1 w2 w1 w2 )
;		Duplicate top two items.
		
		FDB DDUP,L710
L720		FCB 4,"2DUP"
DDUP		
		jsr DOLST
		FDB	OVER,OVER,EXIT

;   LSHIFT	( w n -- w )
;		Shift word left n times.
		FDB LSHIFT,L720
L721		FCB 6,"LSHIFT"
LSHIFT		ldx ,s++	;shift count
		beq LSHIFT2
		ldd ,s		;value to shift
LSHIFT1		aslb		;low
		rola		;high
		leax -1,x	;count down
		bne LSHIFT1
		std ,s
LSHIFT2
		pulu pc

;   RSHIFT	( w n -- w )
;		Shift word right n times.
		FDB RSHIFT,L721
L721A		FCB 6,"RSHIFT"
RSHIFT		ldx ,s++	;shift count
		beq RSHIFT2
		ldd ,s		;value to shift
RSHIFT1 	lsra		;high
		rorb		;low
		leax -1,x	;count down
		bne RSHIFT1
		std ,s
RSHIFT2
		pulu pc

;   ><		( w -- w )
;		swap high and low byte
		FDB SWAPHL,L721A
L722		FCB 2,"><"
SWAPHL		ldb ,s		;high -> D low
		lda 1,s		;low -> D high
		std ,s
		pulu pc

;   256/		( w -- w )
;		multiply with 256 (shift left 8 times)
		FDB SLASH256,L722
L723		FCB 4,"256/"
SLASH256	ldb ,s		;high -> D low
		clra		;D high = 0
		std ,s
		pulu pc

;   256*		( w -- w )
;		multiply with 256 (shift left 8 times)
		FDB STAR256,L723
L724		FCB 4,"256*"
STAR256		lda 1,s		;low -> D high
		clrb		;D low = 0
		std ,s
		pulu pc

;   1+		( w -- w )
;		Shortcut, quick add 1
		FDB PLUS1,L724
L725		FCB 2,"1+"
PLUS1		ldd ,s
		addd #1
		std ,s
		pulu pc

;   -+		( w -- w )
;		Shortcut, quick subtract 1
		FDB MINUS1,L725
L726		FCB 2,"1-"
MINUS1		ldd ,s
		subd #1
		std ,s
		pulu pc

;   2*		( w -- w )
;		multiply by 2 using shift operation
		FDB TWOSTAR,L726
L727		FCB 2,"2*"
TWOSTAR		asl 1,s		;low
		rol 0,s		;high
		pulu pc

;   2/		( w -- w )
;		divide by 2 using shift operation
		FDB TWOSLASH,L727
L728		FCB 2,"2/"
TWOSLASH	asr 0,s		;high
		ror 1,s		;low
		pulu pc

;   +		( w w -- sum )
;		Add top two items.

		FDB PLUS,L728
L730		FCB 1,"+"
PLUS		
		ldd ,s++
		addd ,s
		std ,s
		pulu pc
;;; HL with UPLUS!? Too inefficient ...
;;;		jsr DOLST
;;;		FDB	UPLUS,DROP,EXIT

;   NOT		( w -- w )
;		One's complement of tos.

		FDB INVER,L730
L740		FCB 3,"NOT"
INVER
;;;; fastest ... (13T)
		com ,s	;		6T
		com 1,s ;		7T
		pulu pc
;;;; alternative ...  (14T)
		ldd ,s	;TOS		5T
		coma	;		2T
		comb	;		2T	
		std ,s	;		5T
		pulu pc
;;; slow HL ...
;;;		jsr DOLST
;;;		FDB	DOLIT,-1,XORR,EXIT

;   NEGATE	( n -- -n )
;		Two's complement of tos.

		FDB NEGAT,L740
L750		FCB 6,"NEGATE"
NEGAT		
;;;; fastest? .... (3+6+5 = 14T)
		ldd #0		;			3T
		subd ,s		;			6T
		std ,s		;			5T
		pulu pc
;;;; alternate ... (7+3+6 = 16T)
		neg 1,s		; high			7T
		bne NEGAT1	; 			3T
		neg ,s		; low with 1+ carry	6T
		pulu pc
NEGAT1		com ,s		; low, no 1+ carry	6T
		pulu pc
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	INVER,PLUS1,EXIT

;   DNEGATE	( d -- -d )
;		Two's complement of top double.

		FDB DNEGA,L750
L760		FCB 7,"DNEGATE"
DNEGA
		ldd #0
		subd 2,s	; low word
		std 2,s
		ldd #0
		sbcb 1,s	; high word low byte
		sbca ,s		; high word high byte
		std ,s
		pulu pc
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	INVER,TOR,INVER
;;;;		FDB	DOLIT,1,UPLUS
;;;;		FDB	RFROM,PLUS,EXIT

;   -		( n1 n2 -- n1-n2 )
;		Subtraction.

		FDB SUBB,L760
L770		FCB 1,"-"
SUBB		ldd 2,s
		subd ,s++
		std ,s
		pulu pc
;;; slow HL ...
;;;		jsr DOLST
;;;		FDB	NEGAT,PLUS,EXIT

;   ABS		( n -- n )
;		Return the absolute value of n.

		FDB ABSS,L770
L780		FCB 3,"ABS"
ABSS		jsr DOLST
		FDB	DUPP,ZLESS
		FDB	QBRAN,ABS1
		FDB	NEGAT
ABS1		FDB	EXIT

;   =		( w w -- t )
;		Return true if top two are equal.

		FDB EQUAL,L780
L790		FCB 1,"="
EQUAL
		ldx #TRUEE
		puls d		; first value
		cmpd ,s		; compare to 2nd value
		beq EQUAL1	; equal -> true
		ldx #0		; false (leax 1,x save 1 byte, but is slower)
EQUAL1 		stx ,s
		pulu pc
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	XORR
;;;;		FDB	QBRAN,EQU1
;;;;		FDB	DOLIT,0,EXIT
;;;;EQU1:		FDB	DOLIT,TRUEE,EXIT

;   U<		( u1 u2 -- t )
;		Unsigned compare of top two items.

		FDB ULESS,L790
L800		FCB 2,"U<"
ULESS
		ldx #TRUEE	; true
		puls d		; u2
		cmpd ,s		; u2 - u1
		bhi ULES1	; unsigned: u2 higher u1
		ldx #0		; false
ULES1		stx ,s		; replace TOS with result
		pulu pc
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	DDUP,XORR,ZLESS
;;;;		FDB	QBRAN,ULES1
;;;;		FDB	SWAP,DROP,ZLESS,EXIT
;;;;ULES1:		FDB	SUBB,ZLESS,EXIT

;   <		( n1 n2 -- t )
;		Signed compare of top two items.

		FDB LESS,L800
L810		FCB 1,"<"
LESS
		ldx #TRUEE	; true
		puls d		; n2
		cmpd ,s		; n2 - n1
		bgt LESS1	; signed: n2 greater than n1
		ldx #0		; false
LESS1		stx ,s		; replace TOS with result
		pulu pc
		
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	DDUP,XORR,ZLESS
;;;;		FDB	QBRAN,LESS1
;;;;		FDB	DROP,ZLESS,EXIT
;;;;LESS1:		FDB	SUBB,ZLESS,EXIT

;   MAX		( n n -- n )
;		Return the greater of two top stack items.

		FDB MAX,L810
L820		FCB 3,"MAX"
MAX		jsr DOLST
		FDB	DDUP,LESS
		FDB	QBRAN,MAX1
		FDB	SWAP
MAX1		FDB	DROP,EXIT

;   MIN		( n n -- n )
;		Return the smaller of top two stack items.

		FDB MIN,L820
L830		FCB 3,"MIN"
MIN		jsr DOLST
		FDB	DDUP,SWAP,LESS
		FDB	QBRAN,MIN1
		FDB	SWAP
MIN1		FDB	DROP,EXIT

;   WITHIN	( u ul uh -- t )
;		Return true if u is within the range of ul and uh. ( ul <= u < uh )

		FDB WITHI,L830
L840		FCB 6,"WITHIN"
WITHI		jsr DOLST
		FDB	OVER,SUBB,TOR
		FDB	SUBB,RFROM,ULESS,EXIT

;; Divide

;   U/		( udl udh un -- ur uq )
;		Unsigned divide of a double by a single. Return mod and quotient.
;
; Special cases:
;       1. overflow: quotient overflow if dividend is to great (remainder = divisor),
;               remainder is set to $FFFF -> special handling.
;               This is checked also right before the main loop.
;       2. underflow: divisor does not fit into dividend -> remainder
;               get the value of the dividend -> automatically covered.
;
;   overflow:           quotient = $FFFF, remainder = divisor
;   underflow:          quotient = $0000, remainder = dividend low
;   division by zero:   quotient = $FFFF, remainder = $0000
;
; Testvalues:
;
; DIVH  DIVL    DVSR    QUOT    REM     comment
;
; 0100  0000    FFFF    0100    0100    maximum divisor
; 0000  0001    8000    0000    0001    underflow (REM = DIVL)
; 0000  5800    3000    0001    1800    normal divsion
; 5800  0000    3000    FFFF    3000    overflow
; 0000  0001    0000    FFFF    0000    overflow (division by zero)

		FDB USLASH,L840
L845		FCB 2,"U/"

USLASH
		ldx #16
		ldd 2,s         ; udh
		cmpd ,s         ; dividend to great?
		bhs UMMODOV     ; quotient overflow!
		asl 5,s         ; udl low
		rol 4,s         ; udl high

UMMOD1		rolb            ; got one bit from udl
		rola
		bcs UMMOD2      ; bit 16 means always greater as divisor
		cmpd ,s         ; divide by un
		bhs UMMOD2      ; higher or same as divisor?
		andcc #$fe      ; clc - clear carry flag
		bra UMMOD3
UMMOD2		subd ,s
		orcc #$01       ; sec - set carry flag
UMMOD3		rol 5,s         ; udl, quotient shifted in
		rol 4,s
		leax -1,x
		bne UMMOD1

		ldx 4,s         ; quotient
		cmpd ,s         ; remainder >= divisor -> overflow
		blo UMMOD4
UMMODOV
		ldd ,s          ; remainder set to divisor
		ldx #$FFFF      ; quotient = FFFF (-1) marks overflow
                                ; (case 1)
UMMOD4         
		leas 2,s        ; un (divisor thrown away)
		stx ,s          ; quotient to TOS
		std 2,s         ; remainder 2nd

	        pulu pc         ; NEXT


;   UM/MOD	( udl udh un -- ur uq )
;		Unsigned divide of a double by a single. Return mod and quotient.

		FDB UMMOD,L845
L850		FCB 6,"UM/MOD"
UMMOD
		jmp USLASH
;;;; slow HL ...
		jsr DOLST
		FDB	DDUP,ULESS
		FDB	QBRAN,UMM4
		FDB	NEGAT,DOLIT,15,TOR
UMM1		FDB	TOR,DUPP,UPLUS
		FDB	TOR,TOR,DUPP,UPLUS
		FDB	RFROM,PLUS,DUPP
		FDB	RFROM,RAT,SWAP,TOR
		FDB	UPLUS,RFROM,ORR
		FDB	QBRAN,UMM2
		FDB	TOR,DROP,PLUS1,RFROM
		FDB	BRAN,UMM3
UMM2		FDB	DROP
UMM3		FDB	RFROM
		FDB	DONXT,UMM1
		FDB	DROP,SWAP,EXIT
UMM4		FDB	DROP,DDROP
		FDB	DOLIT,-1,DUPP,EXIT

;   M/MOD	( d n -- r q )
;		Signed floored divide of double by single. Return mod and quotient.

		FDB MSMOD,L850
L860		FCB 5,"M/MOD"
MSMOD
		jsr DOLST
		FDB	DUPP,ZLESS,DUPP,TOR
		FDB	QBRAN,MMOD1
		FDB	NEGAT,TOR,DNEGA,RFROM
MMOD1		FDB	TOR,DUPP,ZLESS
		FDB	QBRAN,MMOD2
		FDB	RAT,PLUS
MMOD2		FDB	RFROM,UMMOD,RFROM
		FDB	QBRAN,MMOD3
		FDB	SWAP,NEGAT,SWAP
MMOD3		FDB	EXIT

;   /MOD	( n n -- r q )
;		Signed divide. Return mod and quotient.

		FDB SLMOD,L860
L870		FCB 4,"/MOD"
SLMOD		jsr DOLST
		FDB	OVER,ZLESS,SWAP,MSMOD,EXIT

;   MOD		( n n -- r )
;		Signed divide. Return mod only.

		FDB MODD,L870
L880		FCB 3,"MOD"
MODD		jsr DOLST
		FDB	SLMOD,DROP,EXIT

;   /		( n n -- q )
;		Signed divide. Return quotient only.

		FDB SLASH,L880
L890		FCB 1,"/"
SLASH
		jsr DOLST
		FDB	SLMOD,SWAP,DROP,EXIT

;; Multiply

;   UM*		( u u -- ud )
;		Unsigned multiply. Return double product.

		FDB UMSTA,L890
L900		FCB 3,"UM*"
UMSTA
		ldx #17		; 16 adds and 17 shifts ...
		clra		; result high word
		clrb
		bra UUMSTA3
UUMSTA1		bcc UUMSTA2
		addd ,s
UUMSTA2 	rora		; high, result high word
		rorb		; low, result high word
UUMSTA3 	ror 2,s		; shift multiplier high, result low word
		ror 3,s		; shift multiplier low, result low word
		leax -1,x
		bne UUMSTA1
		std ,s
		pulu pc
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	DOLIT,0,SWAP,DOLIT,15,TOR
;;;;UMST1:		FDB	DUPP,UPLUS,TOR,TOR
;;;;		FDB	DUPP,UPLUS,RFROM,PLUS,RFROM
;;;;		FDB	QBRAN,UMST2
;;;;		FDB	TOR,OVER,UPLUS,RFROM,PLUS
;;;;UMST2:		FDB	DONXT,UMST1
;;;;		FDB	ROT,DROP,EXIT

;   _UM*		( u u -- ud )
;		Unsigned multiply. Return double product.

		FDB UUMSTA,L900
L900A		FCB 4,"_UM*"
UUMSTA
		jsr DOLST
		FDB	DOLIT,0,SWAP,DOLIT,15,TOR
UMST1		FDB	DUPP,UPLUS,TOR,TOR
		FDB	DUPP,UPLUS,RFROM,PLUS,RFROM
		FDB	QBRAN,UMST2
		FDB	TOR,OVER,UPLUS,RFROM,PLUS
UMST2		FDB	DONXT,UMST1
		FDB	ROT,DROP,EXIT

;   *		( n n -- n )
;		Signed multiply. Return single product.
;		XXX Not really signed, -200 -200 * -> -25536

		FDB STAR,L900A
L910		FCB 1,"*"
STAR
 		jsr DOLST
		FDB	MSTAR,DROP,EXIT

;   M*		( n n -- d )
;		Signed multiply. Return double product.

		FDB MSTAR,L910
L920		FCB 2,"M*"
MSTAR
 		jsr DOLST
		FDB	DDUP,XORR,ZLESS,TOR
		FDB	ABSS,SWAP,ABSS,UMSTA
		FDB	RFROM
		FDB	QBRAN,MSTA1
		FDB	DNEGA
MSTA1		FDB	EXIT

;   */MOD	( n1 n2 n3 -- r q )
;		Multiply n1 and n2, then divide by n3. Return mod and quotient.

		FDB SSMOD,L920
L930		FCB 5,"*/MOD"
SSMOD		jsr DOLST
		FDB	TOR,MSTAR,RFROM,MSMOD,EXIT

;   */		( n1 n2 n3 -- q )
;		Multiply n1 by n2, then divide by n3. Return quotient only.

		FDB STASL,L930
L940		FCB 2,"*/"
STASL		jsr DOLST
		FDB	SSMOD,SWAP,DROP,EXIT

;; Miscellaneous

;   CELL+	( a -- a )
;		Add cell size in byte to address.

		FDB CELLP,L940
L950		FCB 5,"CELL+"
CELLP		jsr DOLST
		FDB	DOCLIT
		FCB	CELLL
		FDB	PLUS,EXIT

;   CELL-	( a -- a )
;		Subtract cell size in byte from address.

		FDB CELLM,L950
L960		FCB 5,"CELL-"
CELLM		jsr DOLST
		FDB	DOCLIT
		FCB	0-CELLL
		FDB	PLUS,EXIT

;   CELLS	( n -- n )
;		Multiply tos by cell size in bytes.

		FDB CELLS,L960
L970		FCB 5,"CELLS"
CELLS		jsr DOLST
		FDB	DOCLIT
		FCB	CELLL
		FDB	STAR,EXIT

;   ALIGNED	( b -- a )
;		Align address to the cell boundary.

		FDB ALGND,L970
L975		FCB 7,"ALIGNED"
ALGND		jsr DOLST
		FDB EXIT

;   BL		( -- 32 )
;		Return 32, the blank character.

		FDB BLANK,L975
L980		FCB 2,"BL"
BLANK
		jsr DOCONST
		FDB ' '
;;;		jsr DOLST
;;;		FDB	DOLIT,' ',EXIT

;   >CHAR	( c -- c )
;		Filter non-printing characters.

		FDB TCHAR,L980
L990		FCB 5,">CHAR"
TCHAR		jsr DOLST
		FDB	DOLIT,$7F,ANDD,DUPP	;mask msb
		FDB	DOCLIT
		FCB	127
		FDB	BLANK,WITHI	;check for printable
		FDB	QBRAN,TCHA1
		FDB	DROP,DOLIT,'_'		;replace non-printables
TCHA1		FDB	EXIT

;   DEPTH	( -- n )
;		Return the depth of the data stack.

		FDB DEPTH,L990
L1000		FCB 5,"DEPTH"
DEPTH		jsr DOLST
		FDB	SPAT,SZERO,AT,SWAP,SUBB
		FDB	DOCLIT
		FCB	CELLL
		FDB	SLASH,EXIT

;   PICK	( ... +n -- ... w )
;		Copy the nth stack item to tos.

		FDB PICK,L1000
L1010		FCB 4,"PICK"
PICK		
		ldd ,s
		addd #1		; correct index
		aslb		; CELLL* (ASSERT: CELLL=2!!!)
		rola
		ldx d,s		; pick value
		stx ,s		; replace TOP
		pulu pc
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	PLUS1,CELLS
;;;;		FDB	SPAT,PLUS,AT,EXIT


;   ROLL	( ... +n -- ... w )
;		Copy the nth stack item to tos.

		FDB ROLL,L1010
L1015		FCB 4,"ROLL"
ROLL
;;;; XXX als Primitive!
;;;; slow HL ...
		jsr DOLST
		FDB	DUPP,TWO
		FDB	LESS,QBRAN,ROL1
		FDB	DROP,BRAN,ROL2
ROL1		FDB	SWAP,TOR,ONE
		FDB	SUBB
		FDB	ROLL,RFROM,SWAP
ROL2		FDB	EXIT

;; Memory access

;   +!		( n a -- )
;		Add n to the contents at address a.

		FDB PSTOR,L1015
L1020		FCB 2,"+!"
PSTOR
		puls x		; address
		puls d		; value
		addd ,x		; add to value from address
		std ,x		; store back
		pulu pc

;;;; XXX als Primitive!
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	SWAP,OVER,AT,PLUS
;;;;		FDB	SWAP,STORE,EXIT

;   2!		( d a -- )
;		Store the double integer to address a.

		FDB DSTOR,L1020
L1030		FCB 2,"2!"
DSTOR
;;;; XXX als Primitive!
;;;; slow HL ...
		jsr DOLST
		FDB	SWAP,OVER,STORE
		FDB	CELLP,STORE,EXIT

;   2@		( a -- d )
;		Fetch double integer from address a.

		FDB DAT,L1030
L1040		FCB 2,"2@"
DAT
;;;; XXX als Primitive!
;;;; slow HL ...
		jsr DOLST
		FDB	DUPP,CELLP,AT
		FDB	SWAP,AT,EXIT

;   COUNT	( b -- b +n )
;		Return count byte of a string and add 1 to byte address.

		FDB COUNT,L1040
L1050		FCB 5,"COUNT"
COUNT		jsr DOLST
		FDB	DUPP,PLUS1
		FDB	SWAP,CAT,EXIT

;   HERE	( -- a )
;		Return the top of the code dictionary.

		FDB HERE,L1050
L1060		FCB 4,"HERE"
HERE		jsr DOLST
		FDB	CP,AT,EXIT

;   PAD		( -- a )
;		Return the address of the text buffer above the code dictionary.

		FDB PAD,L1060
L1070		FCB 3,"PAD"
PAD		jsr DOLST
		FDB	HERE,DOLIT,80,PLUS,EXIT

;   TIB		( -- a )
;		Return the address of the terminal input buffer.

		FDB TIB,L1070
L1080		FCB 3,"TIB"
TIB		jsr DOLST
		FDB	NTIB,CELLP,AT,EXIT

;   @EXECUTE	( a -- )
;		Execute vector stored in address a.

		FDB ATEXE,L1080
L1090		FCB 8,"@EXECUTE"
ATEXE		jsr DOLST
		FDB	AT,QDUP			;?address or zero
		FDB	QBRAN,EXE1
		FDB	EXECU			;execute if non-zero
EXE1		FDB	EXIT			;do nothing if zero

;   CMOVE	( b1 b2 u -- )
;		Copy u bytes from b1 to b2.

		FDB CMOVE,L1090
L1100		FCB 5,"CMOVE"
CMOVE
		jmp CMOVEW
		ldd ,s		;count
		beq CMOVE3	;zero -> leave
		tstb		;count low
		beq CMOVE1
		inc ,s		;ajust high for to-0 decrementation
CMOVE1
		ldx 2,s		;to addr
		stu 2,s		;save reg on stack
		ldu 4,s		;from addr
CMOVE2		lda ,u+		;from ->
		sta ,x+		;to	
		decb		;low count
		bne CMOVE2
		dec ,s		;high count
		bne CMOVE2
		ldu 2,s
CMOVE3		leas 6,s	;drop 3 parameters from stack
		pulu pc
;;;;
;;;; alternative, wordwise copy ...
CMOVEW		ldd ,s		; count
		ldx 2,s		; destination
		sty ,s		; save RP
		stu 2,s		; save IP
		ldy 4,s		; source
		lsra		; divide by 2, count words
		rorb		;
		pshs cc
		beq CMOVEW1	; byte decrement correction
		inca		; byte decrement high byte correction
CMOVEW1		subd #0		; word count zero (=65536)?
		beq CMOVEW3
CMOVEW2		ldu ,y++	; source
		stu ,x++	; destination
		decb		; count low
		bne CMOVEW2
		deca		; count high (count to 0 corrected)
		bne CMOVEW2
CMOVEW3 	puls CC		; check if odd count?
		bcc CMOVEW4
		lda ,y
		sta ,x
CMOVEW4 	puls y,u	; y first
		leas 2,s	; drop 3rd parameter
		pulu pc		; next
;;;;
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	TOR
;;;;		FDB	BRAN,CMOV2
;;;;CMOV1:		FDB	TOR,DUPP,CAT
;;;;		FDB	RAT,CSTOR
;;;;		FDB	PLUS1
;;;;		FDB	RFROM,PLUS1
;;;;CMOV2:		FDB	DONXT,CMOV1
;;;;		FDB	DDROP,EXIT
;;;;

;   FILL	( b u c -- )
;		Fill u bytes of character c to area beginning at b.

		FDB FILL,L1100
L1110		FCB 4,"FILL"
FILL
		ldd 2,s		;count
		beq NFILL3	;zero -> leave
		tstb		;count low
		beq NFILL1
		inc 2,s		;ajust high for to-0 decrementation
NFILL1
		ldx 4,s		;to addr
		lda 1,s		;fill byte, low byte from TOS
NFILL2		
		sta ,x+		;to	
		decb		;low count
		bne NFILL2
		dec 2,s		;high count
		bne NFILL2
NFILL3		leas 6,s	;drop 3 parameters from stack
		pulu pc
;;;; slow HL ...
;;;;		jsr DOLST
;;;;		FDB	SWAP,TOR,SWAP
;;;;		FDB	BRAN,FILL2
;;;;FILL1:		FDB	DDUP,CSTOR,PLUS1
;;;;FILL2:		FDB	DONXT,FILL1
;;;;		FDB	DDROP,EXIT

;   -TRAILING	( b u -- b u )
;		Adjust the count to eliminate trailing white space.

		FDB DTRAI,L1110
L1120		FCB 9,"-TRAILING"
DTRAI		jsr DOLST
		FDB	TOR
		FDB	BRAN,DTRA2
DTRA1		FDB	BLANK,OVER,RAT,PLUS,CAT,LESS
		FDB	QBRAN,DTRA2
		FDB	RFROM,PLUS1,EXIT
DTRA2		FDB	DONXT,DTRA1
		FDB	ZERO,EXIT

;   PACK$	( b u a -- a )
;		Build a counted string with u characters from b. Null fill.

		FDB PACKS,L1120
L1130		FCB 5,"PACK$"
PACKS		jsr DOLST
		FDB	DUPP,TOR		;strings only on cell boundary
		FDB	DDUP,CSTOR
		FDB	PLUS1			;count mod cell
		FDB	DDUP,PLUS
		FDB	ZERO,SWAP,CSTOR	;null fill cell
		FDB	SWAP,CMOVE,RFROM,EXIT	;move string

;; Numeric output, single precision

;   DIGIT	( u -- c )
;		Convert digit u to a character.

		FDB DIGIT,L1130
L1140		FCB 5,"DIGIT"
DIGIT		jsr DOLST
		FDB	DOCLIT
		FCB	9
		FDB	OVER,LESS
		FDB	DOCLIT
		FCB	7
		FDB	ANDD,PLUS
		FDB	DOLIT,'0',PLUS,EXIT

;   EXTRACT	( n base -- n c )
;		Extract the least significant digit from n.

		FDB EXTRC,L1140
L1150		FCB 7,"EXTRACT"
EXTRC		jsr DOLST
		FDB	ZERO,SWAP,UMMOD
		FDB	SWAP,DIGIT,EXIT

;   <#		( -- )
;		Initiate the numeric output process.

		FDB BDIGS,L1150
L1160		FCB 2,"<#"
BDIGS		jsr DOLST
		FDB	PAD,HLD,STORE,EXIT

;   HOLD	( c -- )
;		Insert a character into the numeric output string.


		FDB HOLD,L1160
L1170		FCB 4,"HOLD"
HOLD		jsr DOLST
		FDB	HLD,AT,MINUS1
		FDB	DUPP,HLD,STORE,CSTOR,EXIT

;   #		( u -- u )
;		Extract one digit from u and append the digit to output string.

		FDB DIG,L1170
L1180		FCB 1,"#"
DIG		jsr DOLST
		FDB	BASE,AT,EXTRC,HOLD,EXIT

;   #S		( u -- 0 )
;		Convert u until all digits are added to the output string.

		FDB DIGS,L1180
L1190		FCB 2,"#S"
DIGS		jsr DOLST
DIGS1		FDB	DIG,DUPP
		FDB	QBRAN,DIGS2
		FDB	BRAN,DIGS1
DIGS2		FDB	EXIT

;   SIGN	( n -- )
;		Add a minus sign to the numeric output string.

		FDB SIGN,L1190
L1200		FCB 4,"SIGN"
SIGN		jsr DOLST
		FDB	ZLESS
		FDB	QBRAN,SIGN1
		FDB	DOLIT,'-',HOLD
SIGN1		FDB	EXIT

;   #>		( w -- b u )
;		Prepare the output string to be TYPE'd.

		FDB EDIGS,L1200
L1210		FCB 2,"#>"
EDIGS		jsr DOLST
		FDB	DROP,HLD,AT
		FDB	PAD,OVER,SUBB,EXIT

;   str		( w -- b u )
;		Convert a signed integer to a numeric string.

		FDB STR,L1210
L1220		FCB 3,"str"
STR		jsr DOLST
		FDB	DUPP,TOR,ABSS
		FDB	BDIGS,DIGS,RFROM
		FDB	SIGN,EDIGS,EXIT

;   HEX		( -- )
;		Use radix 16 as base for numeric conversions.

		FDB HEX,L1220
L1230		FCB 3,"HEX"
HEX		jsr DOLST
		FDB	DOCLIT
		FCB	16
		FDB	BASE,STORE,EXIT

;   DECIMAL	( -- )
;		Use radix 10 as base for numeric conversions.

		FDB DECIM,L1230
L1240		FCB 7,"DECIMAL"
DECIM		jsr DOLST
		FDB	DOCLIT
		FCB	10
		FDB	BASE,STORE,EXIT

;; Numeric input, single precision

;   DIGIT?	( c base -- u t )
;		Convert a character to its numeric value. A flag indicates success.

		FDB DIGTQ,L1240
L1250		FCB 6,"DIGIT?"
DIGTQ		jsr DOLST
		FDB	TOR,DOLIT,'0',SUBB
		FDB	DOCLIT
		FCB	9
		FDB	OVER,LESS
		FDB	QBRAN,DGTQ1
		FDB	DOCLIT
		FCB	7
		FDB	SUBB
		FDB	DUPP,DOLIT,10,LESS,ORR
DGTQ1		FDB	DUPP,RFROM,ULESS,EXIT

;   NUMBER?	( a -- n T | a F )
;		Convert a number string to integer. Push a flag on tos.

		FDB NUMBQ,L1250
L1260		FCB 7,"NUMBER?"
NUMBQ		jsr DOLST
		FDB	BASE,AT,TOR,ZERO,OVER,COUNT
		FDB	OVER,CAT,DOLIT,'$',EQUAL
		FDB	QBRAN,NUMQ1
		FDB	HEX,SWAP,PLUS1
		FDB	SWAP,MINUS1
NUMQ1		FDB	OVER,CAT,DOLIT,'-',EQUAL,TOR
		FDB	SWAP,RAT,SUBB,SWAP,RAT,PLUS,QDUP
		FDB	QBRAN,NUMQ6
		FDB	MINUS1,TOR
NUMQ2		FDB	DUPP,TOR,CAT,BASE,AT,DIGTQ
		FDB	QBRAN,NUMQ4
		FDB	SWAP,BASE,AT,STAR,PLUS,RFROM
		FDB	PLUS1
		FDB	DONXT,NUMQ2
		FDB	RAT,SWAP,DROP
		FDB	QBRAN,NUMQ3
		FDB	NEGAT
NUMQ3		FDB	SWAP
		FDB	BRAN,NUMQ5
NUMQ4		FDB	RFROM,RFROM,DDROP,DDROP,ZERO
NUMQ5		FDB	DUPP
NUMQ6		FDB	RFROM,DDROP
		FDB	RFROM,BASE,STORE,EXIT

;; Basic I/O

;   ?KEY	( -- c T | F )
;		Return input character and true, or a false if no input.


		FDB QKEY,L1260
L1270		FCB 4,"?KEY"
QKEY		jsr DOLST
		FDB	TQKEY,ATEXE,EXIT

;   KEY		( -- c )
;		Wait for and return an input character.

		FDB KEY,L1270
L1280		FCB 3,"KEY"
KEY		jsr DOLST
KEY1		FDB	QKEY
		FDB	QBRAN,KEY1
		FDB	EXIT

;   EMIT	( c -- )
;		Send a character to the output device.

		FDB EMIT,L1280
L1290		FCB 4,"EMIT"
EMIT		jsr DOLST		
		FDB	TEMIT,ATEXE,EXIT

;   NUF?	( -- t )
;		Return false if no input, else pause and if CR return true.

		FDB NUFQ,L1290
L1300		FCB 4,"NUF?"
NUFQ		jsr DOLST
		FDB	QKEY,DUPP
		FDB	QBRAN,NUFQ1
		FDB	DDROP,KEY,DOCLIT
		FCB	CRR
		FDB	EQUAL
NUFQ1		FDB	EXIT

;   PACE	( -- )
;		Send a pace character for the file downloading process.

		FDB PACE,L1300
L1310		FCB 4,"PACE"
PACE 		jsr DOLST
		FDB	DOCLIT
		FCB	11
		FDB	EMIT,EXIT

;   SPACE	( -- )
;		Send the blank character to the output device.

		FDB SPACE,L1310
L1320		FCB 5,"SPACE"
SPACE 		jsr DOLST
		FDB	BLANK,EMIT,EXIT

;   SPACES	( +n -- )
;		Send n spaces to the output device.

		FDB SPACS,L1320
L1330		FCB 6,"SPACES"
SPACS		jsr DOLST
		FDB	ZERO,MAX,TOR
		FDB	BRAN,CHAR2
CHAR1		FDB	SPACE
CHAR2		FDB	DONXT,CHAR1
		FDB	EXIT

;   TYPE	( b u -- )
;		Output u characters from b.

		FDB TYPES,L1330
L1340		FCB 4,"TYPE"
TYPES		jsr DOLST
		FDB	TOR
		FDB	BRAN,TYPE2
TYPE1		FDB	DUPP,CAT,EMIT
		FDB	PLUS1
TYPE2		FDB	DONXT,TYPE1
		FDB	DROP,EXIT

;   CR		( -- )
;		Output a carriage return and a line feed.

		FDB CR,L1340
L1350		FCB 2,"CR"
CR		jsr DOLST
		FDB	DOCLIT
		FCB	CRR
		FDB	EMIT
		FDB	DOCLIT
		FCB	LF
		FDB	EMIT,EXIT

;   do$		( -- a )
;		Return the address of a compiled string.

		FDB DOSTR,L1350
L1360		FCB COMPO+3,"do$"
DOSTR 		jsr DOLST
		FDB	RFROM,RAT,RFROM,COUNT,PLUS
		FDB	ALGND,TOR,SWAP,TOR,EXIT

;   $"|		( -- a )
;		Run time routine compiled by $". Return address of a compiled string.

		FDB STRQP,L1360
L1370		FCB COMPO+3,'$','"','|'
STRQP		jsr DOLST
		FDB	DOSTR,EXIT		;force a call to do$

;   ."|		( -- )
;		Run time routine of ." . Output a compiled string.

		FDB DOTQP,L1370
L1380		FCB COMPO+3,'.','"','|'
DOTQP		jsr DOLST
		FDB	DOSTR,COUNT,TYPES,EXIT

;   .R		( n +n -- )
;		Display an integer in a field of n columns, right justified.

		FDB DOTR,L1380
L1390		FCB 2,".R"
DOTR		jsr DOLST
		FDB	TOR,STR,RFROM,OVER,SUBB
		FDB	SPACS,TYPES,EXIT

;   U.R		( u +n -- )
;		Display an unsigned integer in n column, right justified.

		FDB UDOTR,L1390
L1400		FCB 3,"U.R"
UDOTR		jsr DOLST
		FDB	TOR,BDIGS,DIGS,EDIGS
		FDB	RFROM,OVER,SUBB
		FDB	SPACS,TYPES,EXIT

;   U.		( u -- )
;		Display an unsigned integer in free format.

		FDB UDOT,L1400
L1410		FCB 2,"U."
UDOT		jsr DOLST
		FDB	BDIGS,DIGS,EDIGS
		FDB	SPACE,TYPES,EXIT

;   .		( w -- )
;		Display an integer in free format, preceeded by a space.

		FDB DOT,L1410
L1420		FCB 1,"."
DOT		jsr DOLST
		FDB	BASE,AT,DOCLIT
		FCB	10
		FDB	XORR			;?decimal
		FDB	QBRAN,DOT1
		FDB	UDOT,EXIT		;no, display unsigned
DOT1		FDB	STR,SPACE,TYPES,EXIT	;yes, display signed

;   ?		( a -- )
;		Display the contents in a memory cell.

		FDB QUEST,L1420
L1430		FCB 1,"?"
QUEST 		jsr DOLST
		FDB	AT,DOT,EXIT

;; Parsing

;   parse	( b u c -- b u delta ; <string> )
;		Scan string delimited by c. Return found string and its offset.

		FDB PARS,L1430
L1440		FCB 5,"parse"
PARS		jsr DOLST
		FDB	TEMP,STORE,OVER,TOR,DUPP
		FDB	QBRAN,PARS8
		FDB	MINUS1,TEMP,AT,BLANK,EQUAL
		FDB	QBRAN,PARS3
		FDB	TOR
PARS1		FDB	BLANK,OVER,CAT		;skip leading blanks ONLY
		FDB	SUBB,ZLESS,INVER
		FDB	QBRAN,PARS2
		FDB	PLUS1
		FDB	DONXT,PARS1
		FDB	RFROM,DROP,ZERO,DUPP,EXIT
PARS2		FDB	RFROM
PARS3		FDB	OVER,SWAP
		FDB	TOR
PARS4		FDB	TEMP,AT,OVER,CAT,SUBB	;scan for delimiter
		FDB	TEMP,AT,BLANK,EQUAL
		FDB	QBRAN,PARS5
		FDB	ZLESS
PARS5		FDB	QBRAN,PARS6
		FDB	PLUS1
		FDB	DONXT,PARS4
		FDB	DUPP,TOR
		FDB	BRAN,PARS7
PARS6		FDB	RFROM,DROP,DUPP
		FDB	PLUS1,TOR
PARS7		FDB	OVER,SUBB
		FDB	RFROM,RFROM,SUBB,EXIT
PARS8		FDB	OVER,RFROM,SUBB,EXIT

;   PARSE	( c -- b u ; <string> )
;		Scan input stream and return counted string delimited by c.

		FDB PARSE,L1440
L1450		FCB 5,"PARSE"
PARSE		jsr DOLST
		FDB	TOR,TIB,INN,AT,PLUS	;current input buffer pointer
		FDB	NTIB,AT,INN,AT,SUBB	;remaining count
		FDB	RFROM,PARS,INN,PSTOR,EXIT

;   .(		( -- )
;		Output following string up to next ) .

		FDB DOTPR,L1450
L1460		FCB IMEDD+2,".("
DOTPR		jsr DOLST
		FDB	DOLIT,')',PARSE,TYPES,EXIT

;   (		( -- )
;		Ignore following string up to next ) . A comment.

		FDB PAREN,L1460
L1470		FCB IMEDD+1,"("
PAREN 		jsr DOLST
		FDB	DOLIT,')',PARSE,DDROP,EXIT

;   \		( -- )
;		Ignore following text till the end of line.

		FDB BKSLA,L1470
L1480		FCB IMEDD+1,92 ; '\' but give as numeric to avoid different escap char processing in different assemblers
BKSLA		jsr DOLST
		FDB	NTIB,AT,INN,STORE,EXIT

;   CHAR	( -- c )
;		Parse next word and return its first character.

		FDB CHAR,L1480
L1490		FCB 4,"CHAR"
CHAR		jsr DOLST
		FDB	BLANK,PARSE,DROP,CAT,EXIT

;   TOKEN	( -- a ; <string> )
;		Parse a word from input stream and copy it to name dictionary.

		FDB TOKEN,L1490
L1500		FCB 5,"TOKEN"
TOKEN		jsr DOLST
		FDB	BLANK,PARSE,DOCLIT
		FCB	31
		FDB	MIN
		FDB	NP,AT,OVER,SUBB,CELLM
		FDB	PACKS,EXIT

;   WORD	( c -- a ; <string> )
;		Parse a word from input stream and copy it to code dictionary.

		FDB WORD,L1500
L1510		FCB 4,"WORD"
WORD		jsr DOLST
		FDB	PARSE,HERE,PACKS,EXIT

;; Dictionary search

;   NAME>	( na -- ca )
;		Return a code address given a name address.

		FDB NAMET,L1510
L1520		FCB 5,"NAME>"
NAMET		jsr DOLST
		FDB	CELLM,CELLM,AT,EXIT

;   SAME?	( a a u -- a a f \ -0+ )
;		Compare u bytes in two strings. Return 0 if identical.

		FDB SAMEQ,L1520
L1530		FCB 5,"SAME?"
SAMEQ 		jsr DOLST
		FDB	TOR
		FDB	BRAN,SAME2
SAME1		FDB	OVER,RAT,PLUS,CAT
		FDB	OVER,RAT,PLUS,CAT
		FDB	SUBB,QDUP
		FDB	QBRAN,SAME2
		FDB	RFROM,DROP,EXIT
SAME2		FDB	DONXT,SAME1
		FDB	DOLIT,0,EXIT

;   find	( a va -- ca na | a F )
;		Search a vocabulary for a string. Return ca and na if succeeded.

		FDB FIND,L1530
L1540		FCB 4,"find"
FIND		jsr DOLST
		FDB	SWAP,DUPP,CAT,MINUS1
		FDB	TEMP,STORE
		FDB	DUPP,AT,TOR,CELLP,SWAP
FIND1		FDB	AT,DUPP
		FDB	QBRAN,FIND6
		FDB	DUPP,AT,DOLIT,MASKK,ANDD,RAT,XORR
		FDB	QBRAN,FIND2
		FDB	CELLP,MONE
		FDB	BRAN,FIND3
FIND2		FDB	CELLP,TEMP,AT,SAMEQ
FIND3		FDB	BRAN,FIND4
FIND6		FDB	RFROM,DROP
		FDB	SWAP,CELLM,SWAP,EXIT
FIND4		FDB	QBRAN,FIND5
		FDB	CELLM,CELLM
		FDB	BRAN,FIND1
FIND5		FDB	RFROM,DROP,SWAP,DROP
		FDB	CELLM
		FDB	DUPP,NAMET,SWAP,EXIT

;   NAME?	( a -- ca na | a F )
;		Search all context vocabularies for a string.

		FDB NAMEQ,L1540
L1550		FCB 5,"NAME?"
NAMEQ		jsr DOLST
		FDB	CNTXT,DUPP,DAT,XORR
		FDB	QBRAN,NAMQ1
		FDB	CELLM
NAMQ1		FDB	TOR
NAMQ2		FDB	RFROM,CELLP,DUPP,TOR
		FDB	AT,QDUP
		FDB	QBRAN,NAMQ3
		FDB	FIND,QDUP
		FDB	QBRAN,NAMQ2
		FDB	RFROM,DROP,EXIT
NAMQ3		FDB	RFROM,DROP
		FDB	ZERO,EXIT

;; Terminal response

;   ^H		( bot eot cur -- bot eot cur )
;		Backup the cursor by one character.

		FDB BKSP,L1550
L1560		FCB 2,"^H"
BKSP		jsr DOLST
		FDB	TOR,OVER,RFROM,SWAP,OVER,XORR
		FDB	QBRAN,BACK1
		FDB	DOLIT,BKSPP,TECHO,ATEXE,MINUS1
		FDB	BLANK,TECHO,ATEXE
		FDB	DOLIT,BKSPP,TECHO,ATEXE
BACK1		FDB	EXIT

;   TAP		( bot eot cur c -- bot eot cur )
;		Accept and echo the key stroke and bump the cursor.

		FDB TAP,L1560
L1570		FCB 3,"TAP"
TAP		jsr DOLST
		FDB	DUPP,TECHO,ATEXE
		FDB	OVER,CSTOR,PLUS1,EXIT

;   kTAP	( bot eot cur c -- bot eot cur )
;		Process a key stroke, CR or backspace.

		FDB KTAP,L1570
L1580		FCB 4,"kTAP"
KTAP		jsr DOLST
		FDB	DUPP,DOCLIT
		FCB	CRR
		FDB	XORR
		FDB	QBRAN,KTAP2
		FDB	DUPP,DOLIT,BKSPP,XORR
		FDB	SWAP,DOLIT,BKSPP2,XORR,ANDD
		FDB	QBRAN,KTAP1
		FDB	BLANK,TAP,EXIT
KTAP1		FDB	BKSP,EXIT
KTAP2		FDB	DROP,SWAP,DROP,DUPP,EXIT

;   accept	( b u -- b u )
;		Accept characters to input buffer. Return with actual count.

		FDB ACCEP,L1580
L1590		FCB 6,"ACCEPT"
ACCEP		jsr DOLST
		FDB	OVER,PLUS,OVER
ACCP1		FDB	DDUP,XORR
		FDB	QBRAN,ACCP4
		FDB	KEY,DUPP
;		FDB	BLANK,SUBB,DOLIT,95,ULESS
		FDB	BLANK,DOLIT,127,WITHI
		FDB	QBRAN,ACCP2
		FDB	TAP
		FDB	BRAN,ACCP3
ACCP2		FDB	TTAP,ATEXE
ACCP3		FDB	BRAN,ACCP1
ACCP4		FDB	DROP,OVER,SUBB,EXIT

;   EXPECT	( b u -- )
;		Accept input stream and store count in SPAN.

		FDB EXPEC,L1590
L1600		FCB 6,"EXPECT"
EXPEC		jsr DOLST
		FDB	TEXPE,ATEXE,SPAN,STORE,DROP,EXIT

;   QUERY	( -- )
;		Accept input stream to terminal input buffer.

		FDB QUERY,L1600
L1610		FCB 5,"QUERY"
QUERY		jsr DOLST
		FDB	TIB,DOCLIT
		FCB	80
		FDB	TEXPE,ATEXE,NTIB,STORE
		FDB	DROP,ZERO,INN,STORE,EXIT

;; Error handling

;   CATCH	( ca -- 0 | err# )
;		Execute word at ca and set up an error frame for it.

		FDB CATCH,L1610
L1620		FCB 5,"CATCH"
CATCH		jsr DOLST
		FDB	SPAT,TOR,HANDL,AT,TOR	;save error frame
		FDB	RPAT,HANDL,STORE,EXECU	;execute
		FDB	RFROM,HANDL,STORE	;restore error frame
		FDB	RFROM,DROP,ZERO,EXIT	;no error

;   THROW	( err# -- err# )
;		Reset system to current local error frame an update error flag.

		FDB THROW,L1620
L1630		FCB 5,"THROW"
THROW		jsr DOLST
		FDB	HANDL,AT,RPSTO		;restore return stack
		FDB	RFROM,HANDL,STORE	;restore handler frame
		FDB	RFROM,SWAP,TOR,SPSTO	;restore data stack
		FDB	DROP,RFROM,EXIT

;   NULL$	( -- a )
;		Return address of a null string with zero count.

		FDB NULLS,L1630
L1640		FCB 5,"NULL$"
NULLS
;;;;		jsr DOLST
;;;;		FDB	DOVAR			;emulate CREATE
		jsr FDOVAR
		FDB	0
		FCB	99,111,121,111,116,101

;   ABORT	( -- )
;		Reset data stack and jump to QUIT.

		FDB ABORT,L1640
L1650		FCB 5,"ABORT"
ABORT		jsr DOLST
		FDB	NULLS,THROW

;   abort"	( f -- )
;		Run time routine of ABORT" . Abort with a message.

		FDB ABORQ,L1650
L1660		FCB COMPO+6,"abort",'"'
ABORQ		jsr DOLST
		FDB	QBRAN,ABOR1		;text flag
		FDB	DOSTR,THROW		;pass error string
ABOR1		FDB	DOSTR,DROP,EXIT		;drop error

;; The text interpreter

;   $INTERPRET	( a -- )
;		Interpret a word. If failed, try to convert it to an integer.

		FDB INTER,L1660
L1670		FCB 10,"$INTERPRET"
INTER		jsr DOLST
		FDB	NAMEQ,QDUP		;?defined
		FDB	QBRAN,INTE1
		FDB	AT,DOLIT,COMPO<<8,ANDD	;?compile only lexicon bits
		FDB	ABORQ
		FCB	13," compile only"
		FDB	EXECU,EXIT		;execute defined word
INTE1		FDB	TNUMB,ATEXE		;convert a number
		FDB	QBRAN,INTE2
		FDB	EXIT
INTE2		FDB	THROW			;error

;   [		( -- )
;		Start the text interpreter.

		FDB LBRAC,L1670
L1680		FCB IMEDD+1,"["
LBRAC		jsr DOLST
		FDB	DOLIT,INTER,TEVAL,STORE,EXIT

;   .OK		( -- )
;		Display 'ok' only while interpreting.

		FDB DOTOK,L1680
L1690		FCB 3,".OK"
DOTOK		jsr DOLST
		FDB	DOLIT,INTER,TEVAL,AT,EQUAL
		FDB	QBRAN,DOTO1
		FDB	DOTQP
		FCB	3," ok"
DOTO1		FDB	CR,EXIT

;   ?STACK	( -- )
;		Abort if the data stack underflows.

		FDB QSTAC,L1690
L1700		FCB 6,"?STACK"
QSTAC		jsr DOLST
		FDB	DEPTH,ZLESS		;check only for underflow
		FDB	ABORQ
		FCB	10," underflow"
		FDB	EXIT

;   EVAL	( -- )
;		Interpret the input stream.

		FDB EVAL,L1700
L1710		FCB 4,"EVAL"
EVAL		jsr DOLST
EVAL1		FDB	TOKEN,DUPP,CAT		;?input stream empty
		FDB	QBRAN,EVAL2
		FDB	TEVAL,ATEXE,QSTAC	;evaluate input, check stack
		FDB	BRAN,EVAL1
EVAL2		FDB	DROP,TPROM,ATEXE,EXIT	;prompt

;; Shell

;   PRESET	( -- )
;		Reset data stack pointer and the terminal input buffer.

		FDB PRESE,L1710
L1720		FCB 6,"PRESET"
PRESE		jsr DOLST
		FDB	SZERO,AT,SPSTO
		FDB	DOLIT,TIBB,NTIB,CELLP,STORE,EXIT

;   xio		( a a a -- )
;		Reset the I/O vectors 'EXPECT, 'TAP, 'ECHO and 'PROMPT.

		FDB XIO,L1720
L1730		FCB COMPO+3,"xio"
XIO		jsr DOLST
		FDB	DOLIT,ACCEP,TEXPE,DSTOR
		FDB	TECHO,DSTOR,EXIT

;   FILE	( -- )
;		Select I/O vectors for file download.

		FDB FILE,L1730
L1740		FCB 4,"FILE"
FILE		jsr DOLST
		FDB	DOLIT,PACE,DOLIT,DROP
		FDB	DOLIT,KTAP,XIO,EXIT

;   HAND	( -- )
;		Select I/O vectors for terminal interface.

		FDB HAND,L1740
L1750		FCB 4,"HAND"
HAND		jsr DOLST
		FDB	DOLIT,DOTOK,DOLIT,EMIT
		FDB	DOLIT,KTAP,XIO,EXIT

;   I/O		( -- a )
;		Array to store default I/O vectors.

		FDB ISLO,L1750
L1760		FCB 3,"I/O"
ISLO
;;		jsr DOLST
;;		FDB	DOVAR			;emulate CREATE
		jsr FDOVAR
		FDB	QRX,TXSTO		;default I/O vectors

;   CONSOLE	( -- )
;		Initiate terminal interface.

		FDB CONSO,L1760
L1770		FCB 7,"CONSOLE"
CONSO		jsr DOLST
		FDB	ISLO,DAT,TQKEY,DSTOR	;restore default I/O device
		FDB	HAND,EXIT		;keyboard input

;   QUIT	( -- )
;		Reset return stack pointer and start text interpreter.

		FDB QUIT,L1770
L1780		FCB 4,"QUIT"
QUIT		jsr DOLST
		FDB	RZERO,AT,RPSTO		;reset return stack pointer
QUIT1		FDB	LBRAC			;start interpretation
QUIT2		FDB	QUERY			;get input
		FDB	DOLIT,EVAL,CATCH,QDUP	;evaluate input
		FDB	QBRAN,QUIT2		;continue till error
		FDB	TPROM,AT,TOR		;save input device
		FDB	CONSO,NULLS,OVER,XORR	;?display error message
		FDB	QBRAN,QUIT3
		FDB	SPACE,COUNT,TYPES	;error message
		FDB	DOTQP
		FCB	3," ? "			;error prompt
QUIT3		FDB	RFROM,DOLIT,DOTOK,XORR	;?file input
		FDB	QBRAN,QUIT4
		FDB	DOLIT,ERR,EMIT		;file error, tell host
QUIT4		FDB	PRESE			;some cleanup
		FDB	BRAN,QUIT1

;; The compiler

;   '		( -- ca )
;		Search context vocabularies for the next word in input stream.

		FDB TICK,L1780
L1790		FCB 1,"'"
TICK		jsr DOLST
		FDB	TOKEN,NAMEQ		;?defined
		FDB	QBRAN,TICK1
		FDB	EXIT			;yes, push code address
TICK1		FDB	THROW			;no, error

;   ALLOT	( n -- )
;		Allocate n bytes to the code dictionary.

		FDB ALLOT,L1790
L1800		FCB 5,"ALLOT"
ALLOT		jsr DOLST
		FDB	CP,PSTOR,EXIT		;adjust code pointer

;   ,		( w -- )
;		Compile an integer into the code dictionary.

		FDB COMMA,L1800
L1810		FCB 1,","
COMMA		jsr DOLST
		FDB	HERE,DUPP,CELLP		;cell boundary
		FDB	CP,STORE,STORE,EXIT	;adjust code pointer and compile

;   [COMPILE]	( -- ; <string> )
;		Compile the next immediate word into code dictionary.

		FDB BCOMP,L1810
L1820		FCB IMEDD+9,"[COMPILE]"
BCOMP		jsr DOLST
		FDB	TICK,COMMA,EXIT

;   COMPILE	( -- )
;		Compile the next address in colon list to code dictionary.

		FDB COMPI,L1820
L1830		FCB COMPO+7,"COMPILE"
COMPI		jsr DOLST
		FDB	RFROM,DUPP,AT,COMMA	;compile address
		FDB	CELLP,TOR,EXIT		;adjust return address

;   LITERAL	( w -- )
;		Compile tos to code dictionary as an integer literal.

		FDB LITER,L1830
L1840		FCB IMEDD+7,"LITERAL"
LITER		jsr DOLST
		FDB	COMPI,DOLIT,COMMA,EXIT

;   $,"		( -- )
;		Compile a literal string up to next " .

		FDB STRCQ,L1840
L1850		FCB 3,"$,",'"'
STRCQ		jsr DOLST
		FDB	DOLIT,'"',WORD		;move string to code dictionary
		FDB	COUNT,PLUS,ALGND	;calculate aligned end of string
		FDB	CP,STORE,EXIT		;adjust the code pointer

;   RECURSE	( -- )
;		Make the current word available for compilation.

		FDB RECUR,L1850
L1860		FCB IMEDD+7,"RECURSE"
RECUR		jsr DOLST
		FDB	LAST,AT,NAMET,COMMA,EXIT

;; Structures

;   DO		( -- a m )
;		Start a DO-LOOP/+LOOP structure in a colon definition.
		
		FDB DO,L1860
L1861		FCB IMEDD+2,"DO"
DO		jsr DOLST
		FDB	COMPI,DODO,HERE
		FDB	ONE		; marker for DO
		FDB	EXIT

;   ?DO		( -- a m )
;		Start a ?DO-LOOP/+LOOP structure in a colon definition.
		
		FDB QDO,L1861
L1862		FCB IMEDD+3,"?DO"
QDO		jsr DOLST
		FDB	COMPI,DOQDO,HERE
		FDB	COMPI,0		; branch destination placeholder
		FDB	TWO		; marker for ?DO
		FDB	EXIT

;   (?DO)	( w w -- )
;		Runtime part of DO in a DO-LOOP/+LOOP structure.
		
		FDB DOQDO,L1862
L1862A		FCB 5,"(?DO)"
DOQDO		
		puls d		;start
		cmpd ,s		;start < end -> ok
		blt DOQDO1
		leas 2,s	;drop end
		ldu ,u
		pulu pc		;branch past loop
DOQDO1
		puls x		;end
		stx ,--y	;end to return stack
		std ,--y	;start to return stack
		leau 2,u	;skip jump forward
		pulu pc

;   -DO		( -- a m )
;		Start a -DO-LOOP/+LOOP structure in a colon definition.
		
		FDB MDO,L1862A
L1862B		FCB IMEDD+3,"-DO"
MDO		jsr DOLST
		FDB	COMPI,DOMDO,HERE
		FDB	COMPI,0		; branch destination placeholder
		FDB	TWO		; marker for ?DO/-DO
		FDB	EXIT

;   (-DO)	( w w -- )
;		Runtime part of -DO in a -DO-LOOP/+LOOP structure.
		
		FDB DOMDO,L1862B
L1862C		FCB 5,"(-DO)"
DOMDO		
		puls d		;start
		cmpd ,s		;start > end -> ok
		bgt DOMDO1
		leas 2,s	;drop end
		ldu ,u
		pulu pc		;branch past loop
DOMDO1
		puls x		;end
		stx ,--y	;end to return stack
		std ,--y	;start to return stack
		leau 2,u	;skip jump forward
		pulu pc

;   (DO)	( w w -- )
;		Runtime part of DO in a DO-LOOP/+LOOP structure.
		
		FDB DODO,L1862C
L1863		FCB 4,"(DO)"
DODO		
		puls d,x	;start first, end second
		stx ,--y	;end to return stack
		std ,--y	;start to return stack
		pulu pc

;   (LOOP)	( -- )
;		Runtime part of LOOP

		FDB DOLOOP,L1863
L1864		FCB 6,"(LOOP)"
DOLOOP		
		ldd #1
		bra DOPLOF

;   (+LOOP)	( -- )
;		Runtime part of +LOOP

		FDB DOPLOOP,L1864
L1865		FCB IMEDD+7,"(+LOOP)"
DOPLOOP		
		ldd ,s++	; increment
		bpl DOPLOF	; forward
		addd ,y		; start/index
		cmpd 2,y	; end
		ble DOPLO1	; index <= end -> leave
		std ,y
		ldu ,u		; branch to begin of loop
		pulu pc

DOPLOF		addd ,y		; start/index
		cmpd 2,y	; end
		bge DOPLO1	; index >= end -> leave
		std ,y		; save back
		ldu ,u		; branch to begin of loop
		pulu pc
DOPLO1
		leau 2,u	; skip back destination
		leay 4,y	; remove index and upper from r stack
		pulu pc

;   LOOP	( a m -- )
;		Terminate a DO/?DO-LOOP loop structure.

		FDB LOOP,L1865
L1866		FCB IMEDD+4,"LOOP"
LOOP		jsr DOLST
		FDB	COMPI,DOLOOP
		FDB	TWO,EQUAL,QBRAN,LOOP1
		FDB	HERE,CELLP,OVER,STORE,CELLP	; branch forward destination
LOOP1		FDB	COMMA,EXIT


;   +LOOP	( a m -- )
;		Terminate a DO/?DO-+LOOP loop structure.

		FDB PLOOP,L1866
L1867		FCB IMEDD+5,"+LOOP"
PLOOP		jsr DOLST
		FDB	COMPI,DOPLOOP
		FDB	TWO,EQUAL,QBRAN,PLOOP1
		FDB	HERE,CELLP,OVER,STORE,CELLP	; branch forward destination
PLOOP1		FDB	COMMA,EXIT

;   LEAVE	( -- )
;		Leave DO/LOOP

		FDB LEAVE,L1867
L1868		FCB 5,"LEAVE"
LEAVE
		ldd ,y		;take index on return stack
		std 2,y		;and change end to it
		pulu pc

;   FOR		( -- a )
;		Start a FOR-NEXT loop structure in a colon definition.
		
		FDB FOR,L1867
L1870		FCB IMEDD+3,"FOR"
FOR		jsr DOLST
		FDB	COMPI,TOR,HERE,EXIT

;   BEGIN	( -- a )
;		Start an infinite or indefinite loop structure.

		FDB BEGIN,L1870
L1880		FCB IMEDD+5,"BEGIN"
BEGIN		jsr DOLST
		FDB	HERE,EXIT

;   NEXT	( a -- )
;		Terminate a FOR-NEXT loop structure.

		FDB NEXT,L1880
L1890		FCB IMEDD+4,"NEXT"
NEXT		jsr DOLST
		FDB	COMPI,DONXT,COMMA,EXIT

;   UNTIL	( a -- )
;		Terminate a BEGIN-UNTIL indefinite loop structure.

		FDB UNTIL,L1890
L1900		FCB IMEDD+5,"UNTIL"
UNTIL		jsr DOLST
		FDB	COMPI,QBRAN,COMMA,EXIT

;   AGAIN	( a -- )
;		Terminate a BEGIN-AGAIN infinite loop structure.

		FDB AGAIN,L1900
L1910		FCB IMEDD+5,"AGAIN"
AGAIN		jsr DOLST
		FDB	COMPI,BRAN,COMMA,EXIT

;   IF		( -- A )
;		Begin a conditional branch structure.

		FDB IFF,L1910
L1920		FCB IMEDD+2,"IF"
IFF		jsr DOLST
		FDB	COMPI,QBRAN,HERE
		FDB	ZERO,COMMA,EXIT

;   AHEAD	( -- A )
;		Compile a forward branch instruction.

		FDB AHEAD,L1920
L1930		FCB IMEDD+5,"AHEAD"
AHEAD		jsr DOLST
		FDB	COMPI,BRAN,HERE,ZERO,COMMA,EXIT

;   REPEAT	( A a -- )
;		Terminate a BEGIN-WHILE-REPEAT indefinite loop.

		FDB REPEA,L1930
L1940		FCB IMEDD+6,"REPEAT"
REPEA		jsr DOLST
		FDB	AGAIN,HERE,SWAP,STORE,EXIT

;   THEN	( A -- )
;		Terminate a conditional branch structure.

		FDB THENN,L1940
L1950		FCB IMEDD+4,"THEN"
THENN		jsr DOLST
		FDB	HERE,SWAP,STORE,EXIT

;   AFT		( a -- a A )
;		Jump to THEN in a FOR-AFT-THEN-NEXT loop the first time through.

		FDB AFT,L1950
L1960		FCB IMEDD+3,"AFT"
AFT		jsr DOLST
		FDB	DROP,AHEAD,BEGIN,SWAP,EXIT

;   ELSE	( A -- A )
;		Start the false clause in an IF-ELSE-THEN structure.

		FDB ELSEE,L1960
L1970		FCB IMEDD+4,"ELSE"
ELSEE		jsr DOLST
		FDB	AHEAD,SWAP,THENN,EXIT

;   WHILE	( a -- A a )
;		Conditional branch out of a BEGIN-WHILE-REPEAT loop.

		FDB WHILE,L1970
L1980		FCB IMEDD+5,"WHILE"
WHILE		jsr DOLST
		FDB	IFF,SWAP,EXIT

;   ABORT"	( -- ; <string> )
;		Conditional abort with an error message.

		FDB ABRTQ,L1980
L1990		FCB IMEDD+6,"ABORT",'"'
ABRTQ		jsr DOLST
		FDB	COMPI,ABORQ,STRCQ,EXIT

;   $"		( -- ; <string> )
;		Compile an inline string literal.

		FDB STRQ,L1990
L2000		FCB IMEDD+2,'$','"'
STRQ		jsr DOLST
		FDB	COMPI,STRQP,STRCQ,EXIT

;   ."		( -- ; <string> )
;		Compile an inline string literal to be typed out at run time.

		FDB DOTQ,L2000
L2010		FCB IMEDD+2,'.','"'
DOTQ		jsr DOLST
		FDB	COMPI,DOTQP,STRCQ,EXIT

;; Name compiler

;   ?UNIQUE	( a -- a )
;		Display a warning message if the word already exists.

		FDB UNIQU,L2010
L2020		FCB 7,"?UNIQUE"
UNIQU		jsr DOLST
		FDB	DUPP,NAMEQ		;?name exists
		FDB	QBRAN,UNIQ1
		FDB	DOTQP			;redefinitions are OK
		FCB	7," reDef "		;but the user should be warned
		FDB	OVER,COUNT,TYPES	;just in case its not planned
UNIQ1		FDB	DROP,EXIT

;   $,n		( na -- )
;		Build a new dictionary name using the string at na.

		FDB SNAME,L2020
L2030		FCB 3,"$,n"
SNAME		jsr DOLST
		FDB	DUPP,CAT		;?null input
		FDB	QBRAN,PNAM1
		FDB	UNIQU			;?redefinition
		FDB	DUPP,LAST,STORE		;save na for vocabulary link
		FDB	HERE,ALGND,SWAP		;align code address
		FDB	CELLM			;link address
		FDB	CRRNT,AT,AT,OVER,STORE
		FDB	CELLM,DUPP,NP,STORE	;adjust name pointer
		FDB	STORE,EXIT		;save code pointer
PNAM1		FDB	STRQP
		FCB	5," name"		;null input
		FDB	THROW

;; FORTH compiler

;   $COMPILE	( a -- )
;		Compile next word to code dictionary as a token or literal.

		FDB SCOMP,L2030
L2040		FCB 8,"$COMPILE"
SCOMP		jsr DOLST
		FDB	NAMEQ,QDUP		;?defined
		FDB	QBRAN,SCOM2
		FDB	AT,DOLIT,IMEDD<<8,ANDD	;?immediate
		FDB	QBRAN,SCOM1
		FDB	EXECU,EXIT		;its immediate, execute
SCOM1		FDB	COMMA,EXIT		;its not immediate, compile
SCOM2		FDB	TNUMB,ATEXE		;try to convert to number
		FDB	QBRAN,SCOM3
		FDB	LITER,EXIT		;compile number as integer
SCOM3		FDB	THROW			;error

;   OVERT	( -- )
;		Link a new word into the current vocabulary.

		FDB OVERT,L2040
L2050		FCB 5,"OVERT"
OVERT 		jsr DOLST
		FDB	LAST,AT,CRRNT,AT,STORE,EXIT

;   ;		( -- )
;		Terminate a colon definition.

		FDB SEMIS,L2050
L2060		FCB IMEDD+COMPO+1,";"
SEMIS		jsr DOLST
		FDB	COMPI,EXIT,LBRAC,OVERT,EXIT

;   ]		( -- )
;		Start compiling the words in the input stream.

		FDB RBRAC,L2060
L2070		FCB 1,"]"
RBRAC		jsr DOLST
		FDB	DOLIT,SCOMP,TEVAL,STORE,EXIT

;   call,	( ca -- )
;		Assemble a call instruction to ca.

		FDB CALLC,L2070
L2080		FCB 5,"call,"
CALLC		jsr DOLST
		FDB	DOCLIT
		FCB	CALLL
		FDB	HERE,CSTOR	;Direct Threaded Code
		FDB 	ONE,ALLOT
		FDB	COMMA,EXIT	;DTC 6809 extended addr jsr

;   :		( -- ; <string> )
;		Start a new colon definition using next word as its name.

		FDB COLON,L2080
L2090		FCB 1,":"
COLON		jsr DOLST
		FDB	TOKEN,SNAME,DOLIT,DOLST
		FDB	CALLC,RBRAC,EXIT

;   IMMEDIATE	( -- )
;		Make the last compiled word an immediate word.

		FDB IMMED,L2090
L2100		FCB 9,"IMMEDIATE"
IMMED		jsr DOLST
		FDB	DOLIT,IMEDD<<8,LAST,AT,AT,ORR
		FDB	LAST,AT,STORE,EXIT

;; Defining words

;   USER	( u -- ; <string> )
;		Compile a new user variable.

		FDB USER,L2100
L2110		FCB 4,"USER"
USER		jsr DOLST
		FDB	TOKEN,SNAME,OVERT
;;;;		FDB	DOLIT,DOLST,CALLC
;;;;		FDB	DOLIT,DOUSE,COMMA
; fast implementation ....
		FDB	DOLIT,FDOUSE,CALLC
		FDB	COMMA,EXIT

;   CREATE	( -- ; <string> )
;		Compile a new array entry without allocating code space.

		FDB CREAT,L2110
L2120		FCB 6,"CREATE"
CREAT		jsr DOLST
		FDB	TOKEN,SNAME,OVERT
;;;;		FDB	DOLIT,DOLST,CALLC
;;;;		FDB	DOLIT,DOVAR,COMMA,EXIT
; fast implementation ....
		FDB	DOLIT,FDOVAR,CALLC,EXIT

;   VARIABLE	( -- ; <string> )
;		Compile a new variable initialized to 0.

		FDB VARIA,L2120
L2130		FCB 8,"VARIABLE"
VARIA		jsr DOLST
		FDB	CREAT,ZERO,COMMA,EXIT

;   CONSTANT	( w -- ; <string> )
;		Compile a new constant with value w.

		FDB CONST,L2130
L2135		FCB 8,"CONSTANT"
CONST		jsr DOLST
		FDB	TOKEN,SNAME,OVERT
		FDB	DOLIT,DOCONST,CALLC
		FDB	COMMA,EXIT

;; Tools

;   _TYPE	( b u -- )
;		Display a string. Filter non-printing characters.

		FDB UTYPE,L2135
L2140		FCB 5,"_TYPE"
UTYPE		jsr DOLST
		FDB	TOR			;start count down loop
		FDB	BRAN,UTYP2		;skip first pass
UTYP1		FDB	DUPP,CAT,TCHAR,EMIT	;display only printable
		FDB	PLUS1		;increment address
UTYP2		FDB	DONXT,UTYP1		;loop till done
		FDB	DROP,EXIT

;   dm+		( a u -- a )
;		Dump u bytes from , leaving a+u on the stack.

		FDB DUMPP,L2140
L2150		FCB 3,"dm+"
DUMPP		jsr DOLST
		FDB	OVER,DOLIT,4,UDOTR	;display address
		FDB	SPACE,TOR		;start count down loop
		FDB	BRAN,PDUM2		;skip first pass
PDUM1		FDB	DUPP,CAT,DOLIT,3,UDOTR	;display numeric data
		FDB	PLUS1			;increment address
PDUM2		FDB	DONXT,PDUM1		;loop till done
		FDB	EXIT

;   DUMP	( a u -- )
;		Dump u bytes from a, in a formatted manner.

		FDB DUMP,L2150
L2160		FCB 4,"DUMP"
DUMP		jsr DOLST
		FDB	BASE,AT,TOR,HEX		;save radix, set hex
		FDB	DOCLIT
		FCB	16
		FDB	SLASH			;change count to lines
		FDB	TOR			;start count down loop
DUMP1		FDB	CR,DOCLIT
		FCB	16
		FDB	DDUP,DUMPP		;display numeric
		FDB	ROT,ROT
		FDB	TWO,SPACS,UTYPE		;display printable characters
		FDB	NUFQ,INVER		;user control
		FDB	QBRAN,DUMP2
		FDB	DONXT,DUMP1		;loop till done
		FDB	BRAN,DUMP3
DUMP2		FDB	RFROM,DROP		;cleanup loop stack, early exit
DUMP3		FDB	DROP,RFROM,BASE,STORE	;restore radix
		FDB	EXIT

;   .S		( ... -- ... )
;		Display the contents of the data stack.

		FDB DOTS,L2160
L2170		FCB 2,".S"
DOTS		jsr DOLST
		FDB	CR,DEPTH		;stack depth
		FDB	TOR			;start count down loop
		FDB	BRAN,DOTS2		;skip first pass
DOTS1		FDB	RAT,PICK,DOT		;index stack, display contents
DOTS2		FDB	DONXT,DOTS1		;loop till done
		FDB	DOTQP
		FCB	4," <sp"
		FDB	EXIT

;   !CSP	( -- )
;		Save stack pointer in CSP for error checking.

		FDB STCSP,L2170
L2180		FCB 4,"!CSP"
STCSP		jsr DOLST
		FDB	SPAT,CSP,STORE,EXIT	;save pointer

;   ?CSP	( -- )
;		Abort if stack pointer differs from that saved in CSP.

		FDB QCSP,L2180
L2190		FCB 4,"?CSP"
QCSP		jsr DOLST
		FDB	SPAT,CSP,AT,XORR	;compare pointers
		FDB	ABORQ			;abort if different
		FCB	6,"stacks"
		FDB	EXIT

;   >NAME	( ca -- na | F )
;		Convert code address to a name address.

		FDB TNAME,L2190
L2200		FCB 5,">NAME"
TNAME		jsr DOLST
		FDB	CRRNT			;vocabulary link
TNAM1		FDB	CELLP,AT,QDUP		;check all vocabularies
		FDB	QBRAN,TNAM4
		FDB	DDUP
TNAM2		FDB	AT,DUPP			;?last word in a vocabulary
		FDB	QBRAN,TNAM3
		FDB	DDUP,NAMET,XORR		;compare
		FDB	QBRAN,TNAM3
		FDB	CELLM			;continue with next word
		FDB	BRAN,TNAM2
TNAM3		FDB	SWAP,DROP,QDUP
		FDB	QBRAN,TNAM1
		FDB	SWAP,DROP,SWAP,DROP,EXIT
TNAM4		FDB	DROP,DOLIT,0,EXIT

;   .ID		( na -- )
;		Display the name at address.

		FDB DOTID,L2200
L2210		FCB 3,".ID"
DOTID		jsr DOLST
		FDB	QDUP			;if zero no name
		FDB	QBRAN,DOTI1
		FDB	COUNT,DOCLIT
		FCB	$1F
		FDB	ANDD			;mask lexicon bits
		FDB	UTYPE,EXIT		;display name string
DOTI1		FDB	DOTQP
		FCB	9," {noName}"
		FDB	EXIT

;   SEE		( -- ; <string> )
;		A simple decompiler.

		FDB SEE,L2210
L2220		FCB 3,"SEE"
SEE		jsr DOLST
		FDB	TICK			;starting address
		FDB	PLUS1			;skip JSR
						;primitive check ...
		FDB	BASE,AT,TOR,HEX		;switch to hex base
		FDB	DUPP,AT,DOLIT,DOLST,XORR
						;high level word?
		FDB	QBRAN,SEE1		;yes!
		FDB	CR,DOTQP		;primitive word only
		FCB	9, " PRIMITVE"		
		FDB	BRAN,SEE5		;exit
SEE1		FDB	CR,CELLP,DUPP,UDOT,SPACE
		FDB	DUPP,AT,DUPP		;?does it contain a zero
		FDB	QBRAN,SEE2
		FDB	TNAME			;?is it a name
SEE2		FDB	QDUP			;name address or zero
		FDB	QBRAN,SEE3

		FDB	SPACE,DOTID		;display name
		FDB	DUPP,AT

		FDB	DUPP,DOLIT,DOCLIT,EQUAL	; doCLIT?
		FDB	QBRAN,SEE21
		FDB	OVER,CELLP,CAT,SPACE,UDOT ; CLIT: get only single byte
		FDB	SWAP,PLUS1,SWAP
		FDB	BRAN,SEE28

SEE21		FDB	DUPP,DOLIT,DOLIT,EQUAL	; doCLIT?
		FDB	OVER,DOLIT,QBRAN,EQUAL,ORR ; ?BRAN ?
		FDB	OVER,DOLIT,BRAN,EQUAL,ORR; BRANCH ?
		FDB	OVER,DOLIT,DONXT,EQUAL,ORR; next ? (from FOR/NEXT)
		FDB	OVER,DOLIT,DOLOOP,EQUAL,ORR; (LOOP) ?
		FDB	OVER,DOLIT,DOPLOOP,EQUAL,ORR; (+LOOP) ?
		FDB	OVER,DOLIT,DODO,EQUAL,ORR; (DO) ?
		FDB	OVER,DOLIT,DOQDO,EQUAL,ORR; (?DO) ?
		FDB	OVER,DOLIT,DOMDO,EQUAL,ORR; (-DO) ?
		FDB	QBRAN,SEE27
		FDB	SWAP,CELLP,DUPP,AT,SPACE,UDOT,SWAP ; LIT: get word
		FDB	BRAN,SEE28
SEE27		
		FDB	DUPP,DOLIT,DOTQP,EQUAL	; ." ..."
		FDB	OVER,DOLIT,ABORQ,EQUAL,ORR ; ABORT" ..."
		FDB	OVER,DOLIT,STRQP,EQUAL,ORR ; $" ..."
		FDB	QBRAN,SEE29		; last case aalway to SEE29!!
		FDB	SWAP,CELLP		; print compiled string
		FDB	DUPP,COUNT,TYPES,DOCLIT
		FCB	34
		FDB	EMIT
		FDB	COUNT,PLUS,CELLM,SWAP	; adjust continuation address

SEE28		FDB	DROP			; LEAVL, without EXIT check
		FDB	BRAN,SEE4
SEE29		FDB	DROP			; ELSE
		FDB	BRAN,SEE31		; cleanup, check for EXIT

SEE3		FDB	DUPP,AT,UDOT		;display number
		FDB	BRAN,SEE4
SEE31		FDB	DUPP,AT,DOLIT,EXIT,XORR ; stop on EXIT word
						; but not if SEE decompiles itself!
		FDB	QBRAN,SEE5
SEE4		FDB	NUFQ	 		;user control
		FDB	QBRAN,SEE1
SEE5		FDB	RFROM,BASE,STORE,DROP,EXIT

;   WORDS	( -- )
;		Display the names in the context vocabulary.

		FDB WORDS,L2220
L2230		FCB 5,"WORDS"
WORDS		jsr DOLST
		FDB	CR,CNTXT,AT		;only in context
WORS1		FDB	AT,QDUP			;?at end of list
		FDB	QBRAN,WORS2
		FDB	DUPP,SPACE,DOTID	;display a name
		FDB	CELLM,NUFQ		;user control
		FDB	QBRAN,WORS1
		FDB	DROP
WORS2		FDB	EXIT

;; Hardware reset

;   VER		( -- n )
;		Return the version number of this implementation.

		FDB VERSN,L2230
L2240		FCB 3,"VER"
VERSN		jsr DOLST
		FDB	DOLIT,VER*256+EXT,EXIT

;   hi		( -- )
;		Display the sign-on message of eForth.

		FDB HI,L2240
L2250		FCB 2,"hi"
HI		jsr DOLST
		FDB	STOIO,CR,DOTQP		;initialize I/O
		FCB	11,"eForth v"		;model
		FCB	VER+'0','.',EXT+'0'	;version
		FDB	CR,EXIT

;   'BOOT	( -- a )
;		The application startup vector.

		FDB TBOOT,L2250
L2260		FCB 5,"'BOOT"
TBOOT
;;;;		jsr DOLST
;;;;		FDB	DOVAR
		jsr FDOVAR
		FDB	HI			;application to boot

;   COLD	( -- )
;		The hilevel cold start sequence.

		FDB COLD,L2260
L2270		FCB 4,"COLD"
COLD		jsr DOLST		
COLD1		FDB	DOLIT,UZERO,DOLIT,UPP
		FDB	DOLIT,ULAST-UZERO,CMOVE	;initialize user area
		FDB	PRESE			;initialize data stack and TIB
		FDB	TBOOT,ATEXE		;application boot
		FDB	FORTH,CNTXT,AT,DUPP	;initialize search order
		FDB	CRRNT,DSTOR,OVERT
; TEST
;		FDB	DOLIT,10,DOLIT,1
;		FDB	DODO
;
		FDB	QUIT			;start interpretation
		FDB	BRAN,COLD1		;just in case

;===============================================================

LASTN		EQU	L2270			;last name address in name dictionary

NTOP		EQU	NAMEE			;next available memory in name dictionary
CTOP		EQU	*			;next available memory in code dictionary


		END	ORIG

;===============================================================

