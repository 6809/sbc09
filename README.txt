6809 Simulator/Emulator
=======================

sbc09 stands for Lennart Benschop 6809 Single Board Computer.
It contains a assembler and simulator for the Motorola M6809 processor.

copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
license: GNU General Public License version 2, see LICENSE for more details.


Forum thread: http://archive.worldofdragon.org/phpBB3/viewtopic.php?f=8&t=4880
Project: https://github.com/6809/sbc09


For the usage of the assembler a09 and 6809 single board system v09 
read doc/sbc09.creole!


This distribution includes two different kinds of simulators:
 1. The old sim6809 based "simple" simulator built as v09s, v09st
 2. The 6809 single board system as a stand alone environment built as v09



Structure
---------

src/
  Source for the developement tools and virtual machines ...

  a09.c
      The 6809 assembler. It's fairly portable (ANSI) C. It works on both
      Unix and DOS (TC2.0).

      Features of the assembler:
      - generates binary file starting at  the first address
        where code is actually generated. So an initial block of RMB's
        (maybe at a different ORG) is not included in the file.
      - Accepts standard syntax.
      - full expression evaluator.
      - Statements SET, MACRO, PUBLIC, EXTERN IF/ELSE/ENDIF INCLUDE not yet
        implemented. Some provisions are already made internally for macros
        and/or relocatable objects.

  v09s.c
      The (old) 6809 simulator. Loads a binary image (from a09) at adress $100
      and starts executing. SWI2 and SWI3 are for character output/input.
      SYNC stops simulation. When compiling set -DBIG_ENDIAN if your
      computer is big-endian. Set TERM_CONTROL for a crude single character
      (instead of ANSI line-by-line) input. Works on Unix.

  v09stc.c
      Same as v09s.c but for Turbo C. Has its own term control.

  v09.c
  engine.c
  io.c
      The 6809 single board simulator/emulator v09.
       
  mon2.asm
      Monitor progam, alternative version of monitor.asm
      (used in ROM image alt09.rom)

  monitor.asm
      Monitor progam (used in ROM image v09.rom for v09)

  makerom.c
      Helper tool to generate ROM images for v09.


basic/
  Basic interpreters ...

  basic.asm
      Tiny Basic
  fbasic.asm
      Tiny Basic with Lennarts floating point routines.


doc/
  Documentation ...


examples/
  Several test and benchmark programs, simple routines and some bigger stuff
  like a Forth system (ef09).

  ef09.asm Implementation of E-Forth, a very rudimentary and portable Forth.
      Type WORDS to see what words you have. You can evaluate RPN integer
      expressions, like "12 34 + 5 * . " You can make new words like
      " : SQUARED DUP * ; " etc.


examples_forth/
  Forth environment with examples.
  For the 6809 single board system.




Notes on Linux Fedora Core 6
----------------------------
2012-06-04

Compiling v09s, v09st:

 * BIG_ENDIAN (already used by LINUX itself, changed to CPU_BIG_ENDIAN)
   Now automatically set according to BIG_ENDIAN and BYTE_ORDER
   if existing.

 * If TERM_CONTROL mode is active the keyboard is not really in raw mode -
   keyboard signals are still allowed.

 * A tracefilter based on register values can be placed in the TRACE area to
   get tracing output triggered by special states 
   


a09 Assembler
-------------

Bugfixes:
 * addres modes  a,INDEXREG b,INDEXREG d,INDEXREG now known
    as *legal*!

Extended version:
    http://lennartb.home.xs4all.nl/A09.c
    (see above)

 * options -x and -s produces output in Intel Binary/Srecord format,
   contains the above mentioned bugfixes (but fixed by the original
   author).




v09s* Simulator
---------------

### CC register

E F H I N Z V C  Flag
8 7 6 5 4 3 2 1  Bit
| | | | | | | |
| | | | | | | +- $01
| | | | | | +--- $02
| | | | | +----- $04
| | | | +------- $08
| | | +--------- $10
| | +----------- $20
| +------------- $40
+--------------- $80


# differences from real 6809:

ldd #$0fc9
addb #$40
adca #$00

H is set on VCC but not on real 6809, sim6809 does what?

          
### special behavior

    swi2        output character (STDOUT) in register B
    swi3        read character from keyboard into register B
    sync        exit simulator


### start program
v09s BINARY

### start program with tracing output on STDOUT
v09st BINARY

### run program and leave memory dump (64k)

# memory dump in file dump.v09
v09s -d BINARY 



### Bugfixes

 * static int index;
   otherwise the global C library function index() is referenced!
   Write access on it leads to a core dump.

 * BIG_ENDIAN is not useable in FLAG because (POSIX?) Unix
   (especially Linux) defines its byte order.
   If BIG_ENDIAN == BYTE_ORDER -> architecture is big endian!
   Changed to CPU_BIG_ENDIAN, which is refering BIG_ENDIAN and
   BYTE_ORDER automatically (if existent).






eForth
------

Source:

    ef09.asm

    Backspace character changed from 127 to 8.


Memory-Layout:

    0100   At this address the binary is placed to, the Forth entry point
    03C0   USER area start
    4000   Memory TOP


I/O:
    Keyboard input:
     * ^H or BSP deletes character
     * RETURN -> interrupts (long) output

Start:

    ../v09s ef09


Bugs:
    SEE     ;
    STAR (*)    : * UM* DROP ;  ... wrong,
            : * M* DROP ; ... correct (sign!)

Typical commands:

 Commands alway in upper case!!!

WORD    list of defined words of the current vocabulary

BYE     exit Forth (back to shell)
DUMP        hex memory dump 
SEE         HL-word decompiler, corrected:
        * stops at EXIT
        * handles more special primitives (literals, strings,
          variable, constants))
        * handles Direct Threading
        * output line by line with address
.S      shows the content of the parameter stack

count FOR ... NEXT
        replacement for
        hi lo DO ...  I ... LOOP
        hi lo - 1+ FOR ... R@ lo + ... NEXT




Extensions:

    ZEQUAL      0=      Primitive
    PLUS1       1+      Primitive, added
2012-06-07
    ROLL        ROLL        HL, added
    CONST       CONSTANT    HL, added
    doCONST             Primitive, added

2012-06-08
    TWOSTAR     2*      Primtive, added
    TWOSLASH    2/      Primtive, added
    MINUS1      1-      Primtive, added
    SWAPHL      ><      Primtive, added
    STAR256     256*        Primtive, added
    SLASH256    256/        Primtive, added
    CMOVE       CMOVE       Primtive
    FILL        FILL        Primtive
2012-06-09
    ULESS       U<      Primitive
    LESS        <       Primitive
    DO      DO      HL, added
    QDO     ?DO     HL, added
    DODO        (DO)        Primitive, added
    DOQDO       (?DO)       Primitive, added
    LOOP        LOOP        HL, added
    PLOOP       +LOOP       HL, added
    DOLOOP      (LOOP)      Primitive, added
    DOPLOOP     (+LOOP)     Primitive, added
    
2012-06-11
    NEGAT       NEGATE      Primitive, alternative added
    UMSTA       UM*     Primitive, but without MUL
    LSHIFT      LSHIFT      Primitive, added
    RSHIFT      RSHIFT      Primitive, added
2012-06-12
    LEAVE       LEAVE       Primitive, added (fig Forth)
    MDO     -DO     HL, added
    DOMDO       (-DO)       Primitive, added
    I       I       Primitive, added (same as R@)
    CMOVEW      CMOVE       Primitive, other implementation
    STAR        *       korr.: uses M* (instead UM*)
    BLANK       BL      Constant

2012-06-19
    USLASH      U/      Primitive, same as UM/MOD
                    UM/MOD uses USLASH

2012-06-20
    DPLUS       D+      Primitive
    DSUB        D-      HL
    ZERO        0       Constant
    ONE     1       Constant
    TWO     2       Constant
    MONE        -1      Constant
    DOCLIT      doCLIT      Primitive
2012-06-21
    SEE     SEE     extended: handles LIT, CLIT
2012-06-22
    SEE     SEE     extended: handles
                    BRANCH,?BRANCH,?DO,-DO,LOOP,+LOOP,."..."

2012-09-07
    SEE     SEE     ABORT", (DO) added, remarks corrected.

TODO:
 * XXX marks points to open issues.
 * SEE command:
   handling of
    - [COMPILE]
    - DOCONST, DOVAR, DOUSE


TEST:

HEX ok
0 8000 8001 U/ . . FFFE 2 ok
FFFE 8001 U* . . U* ?  ok
FFFE 8001 UM* . . 7FFF FFFE ok
FFFE 8001 UM* 2 0 D+ . . 8000 0 ok

0 8000 7FFF U/ . . FFFF FFFF ok
0 FFFF FFFF U/ . . FFFF FFFF ok
0 FFFE FFFF U/ . . FFFE FFFE ok
FFFF FFFF UM* . . FFFE 1 ok
FFFF FFFE FFFF U/ . . FFFF FFFE ok





Links/References
================


Project:
  https://github.com/6809/sbc09
  Maintained by the original author and others.

Source:
  http://groups.google.com/group/alt.sources/browse_thread/thread/8bfd60536ec34387/94a7cce3fdc5df67
  Autor: Lennart Benschop  lennart@blade.stack.urc.tue.nl, 
                lennartb@xs4all.nl (Webpage, Subject must start with "Your Homepage"!)

  Newsgroups: alt.sources
  From: lennart@blade.stack.urc.tue.nl (Lennart Benschop)
  Date: 3 Nov 1993 15:21:16 GMT
  Local: Mi 3 Nov. 1993 17:21
  Subject: 6809 assembler and simulator (examples) 2/2


Homepage/Download links of Lennart Benschop:
  http://lennartb.home.xs4all.nl/m6809.html
  http://lennartb.home.xs4all.nl/sbc09.tar.gz
  http://lennartb.home.xs4all.nl/A09.c


Emulator for 6809 written in Python, can run sbc09 ROM:
  https://github.com/jedie/DragonPy/


Newer posting in alt.sources (1994):

  Newsgroups: alt.sources
  From: lenn...@blade.stack.urc.tue.nl (Lennart Benschop)
  Date: 17 May 1994 08:13:25 GMT
  Local: Di 17 Mai 1994 10:13
  Subject: 6809 assembler/simulator (3 of 3)


Referenced by:

  http://foldoc.org/6809
    Reference points to posting with buggy version from 1993.

  http://lennartb.home.xs4all.nl/m6809.html
    BAD LINK: http://www.sandelman.ocunix.on.ca/People/Alan_DeKok/interests/6809.html
    -> http://www.sandelman.ottawa.on.ca/People/Alan_DeKok/interests/
    6809 specific site will be redirected, but does not exist.

    Internet-Archiv:
    https://web.archive.org/web/20070112041235/http://www.striker.ottawa.on.ca/6809/
    2014-05-01: Lennart B. lennartb@xs4all.nl has been informed.

  http://archive.worldofdragon.org/phpBB3/viewtopic.php?f=5&t=4308&start=60#p9750
