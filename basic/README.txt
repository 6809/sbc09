BASIC AND FLOATING POINT ROUTINES FOR THE 6809
==============================================

sbc09 stands for Lennart Benschop 6809 Single Board Computer.
It contains a assembler and simulator for the Motorola M6809 processor.

copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
license: GNU General Public License version 2, see LICENSE for more details.



FLOATING POINT ROUTINES FOR THE 6809
------------------------------------

They are intended to be used with the sbc09 system. These routines
should be fairly portable to any 6809-based system. 

As it is an unfinished program (intended to become a full-featured
BASIC interpreter one day), I never released it before and I almost
forgot about it. Fortunately it was still on a backup CD-R that I
made in 2001.


FILES
- - -

makeflot.c   Conversion tool to convert floatnum.src to floatnum.inc

floatnum.inc Floating point constants to be included in main program.
floatnum.src Same constants, but not converted to binary.

fbasic.asm   RPN calculator with floating point (just to test the FP routines.
	     This was intended to be part of a larger Basic interpreter,
   	     but this was never finished).

basic.asm    Tiny Basic
basic.txt    Tiny Basic instructions

It was originally planned to turn this into a full-fledged BASIC
interpreter (maybe somewhat like BBC Basic), but this never
happened. It is now a rudimentary RPN calculator, just to test the 
floating point routines. Each number or command needs to be on a separate
line.




MAKE THE PROGRAMS
- - - - - - - - -

Simple:

make


Or in single steps:

compile the helper tool ...

./makeflot <floatnum.src >floatnum.inc


assemble the FP calculator ...

./a09 fbasic.asm


assemble Tiny Basic (integer only) ...

./a09 basic.asm




RUN THE PROGRAMS
- - - - - - - - 


Start the board simulator

../v09

You should see the prompt "Welcome to BUGGY version 1.0"

Type the command 

xl400

Press the escape character Control-]
(e.g. on Linux for a german style keyboard Control+AltGr+9)

Then you see the v09> prompt.

Type the command

ufbasic

Now the file "fbasic" will be uploaded to the board.

Type the command 

g400

Now you can type floating point numbers and commands (RPN style), each
on a different line, like this

2
3
*
 6.00000000E+00

1
0
/

The last calculation breaks back to the monitor.

The following commands are available (see the source):
+ - * /  (the normal arithmetic operators).
=  compare top two numbers on stack (and leave them), show < = or >
i  round to integer (round to -Inf, like BASIC INT() function).
q  square root
s  sin
c  cos
t  tan
a  atan
l  ln
e  exp
d  duplicate number on stack
x  exchange top numbers on stack.
r  remove top of stack.



IMPLEMENTATION NOTES
- - - - - - - - - - 

This is a 40-bit float, like many microcomputers of the 80s had,
including the Commodore 64, the ZX-Spectrum, the BBC and others.  It
has an 8-bit exponent and a 32-bit mantissa (with hidden leading bit).
The basic operations (including square root) should be as accurate as
can be expected.

It does not do IEEE-754 features, such as Infinity, NaN, +/-zero and
subnormal numbers, but appears to work quite reasonably.

Trig functions deviate a few places in the 9th decimal. In particular
sin(pi/2) shows as 9.99999998E-01 instead of 1.00000000E+00. I
consider this acceptable and consistent with what could be expected.

The Log function deviates a few places in the 8th decimal. LN(5) appears to
be about worst-case. I find this a bit disappointing.

2
l
5
l
+
e

should show exactly 10, but it shows 9.99999970E+00 instead.  This is
not caused by the exp function, but by the log of 5 (as I checked with
Python).


