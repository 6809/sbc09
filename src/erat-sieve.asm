; ERATOSTHENES SIEVE PRIMES  
; BYTE MAGAZINE 9/1981 BENCHMARK 
; Adapted by Johann Klasek, j AT klasek at
; Previously implemented for a Dragon 32, 
; later also for a the sim6809 simulator.
;
	org	$c000

FLAG	EQU	$5000		; array of bytes, length SIZE
SIZE	EQU	$2000

START	

        lds	#FLAG		; stack below flags array

;	lda	#$42
;	jsr	>$b54a		; char out Dragon Basic
	ldb	#'B
	swi2

	lda	#$0a
	pshs	a

ITER	ldx	#FLAG		; array
	ldu	#$ffff		; filled with
	ldd	#(SIZE/2)	; words
CLEAR	stu	,x++		; word fill
	decb			; byte decrement works only
	bne	CLEAR		; low byte of count is 0
	deca	
	bne	CLEAR

	leau	1,u		; prime counter to 0
	ldy	#FLAG		; array

PRIMES	tst	,y+		; is prime? 
	beq	NPRIME
	leax	-1,y		; prime found
	tfr	x,d
	suba	#(FLAG>>8)
	lslb	
	rola	
	addd	#3		; prime = step 
	bra	STEP

NMARK	clr	,x		; mark all non-primes 
STEP	leax	d,x		; step to next
	cmpx	#(FLAG+SIZE)
	bcs	NMARK

	leau	1,u		; count primes
NPRIME	cmpy	#(FLAG+SIZE)
	bcs	PRIMES

	ldb	#'.	
	swi2			; print
;	lda	#$2e
;	jsr	>$b54a		; char out Dragon Basic

	dec	,s
	bne	ITER

	puls	a		; drop counter
	pshs	u		; store count on stack
;	rts
	sync

