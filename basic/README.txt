BASIC AND FLOATING POINT ROUTINES FOR THE 6809
==============================================

sbc09 stands for Lennart Benschop 6809 Single Board Computer.
It contains a assembler and simulator for the Motorola M6809 processor.

copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
license: GNU General Public License version 2, see LICENSE for more details.




FLOATING POINT ROUTINES FOR THE 6809
------------------------------------

I recently found these files on an old CD-R. They are intended to be
used with the sbc09 system. These routines should be fairly portable
to any 6809-based system.



FILES
- - -

makeflot.c   Conversion tool to convert floatnum.src to floatnum.inc

floatnum.inc Floating point constants to be included in main program.
floatnum.src Same constants, but not converted to binary.

fbasic.asm   Tiny Basic with floating point

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


assemble the Basic with floats ...

./a09 fbasic.asm


assemble Basic without floats ...

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
q  square root
s  sin
c  cos
t  tan
a  atan
l  ln
e  exp
d  duplicate number on stack
x  exchange top numbers on stack.




IMPLEMENTATION NOTES
- - - - - - - - - - 

This is a 40-bit float, like many microcomputers of the 80s had,
including the Commodore 64, the ZX-Spectrum, the BBC and others.  It
has an 8-bit exponent and a 32-bit mantissa (with hidden leading bit).
The accuracy of the logarithm function is substandard, the
trigonometric functions appear to be better and the basic operations
should be as accurate as can be expected.

