6809 Simulator/Emulator
=======================

sbc09 stands for Lennart Benschop 6809 Single Board Computer.
It contains a assembler and simulator for the Motorola M6809 processor.

copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
license: GNU General Public License version 2, see LICENSE for more details.


Forum thread: http://archive.worldofdragon.org/phpBB3/viewtopic.php?f=8&t=4880


The first file of this shell archive contains C source, the second part
conttains example programs that can be run on the simulator.






a09.c the 6809 assembler. It's fairly portable (ansi) C. It works on both
      Unix and DOS (TC2.0).

      Features of the assembler.
      - generates binary file starting at  the first address
        where code is actually generated. So an initial block of RMB's
        (maybe at a different ORG) is not included in the file.
      - Accepts standard syntax.
      - full expression evaluator.
      - Statements SET, MACRO, PUBLIC, EXTERN IF/ELSE/ENDIF INCLUDE not yet
        implemented. Some provisions are already made internally for macros
        and/or relocatable objects.

V09.c  the 6809 simulator. Loads a binary image (from a09) at adress $100
       and starts executing. SWI2 and SWI3 are for character output/input.
       SYNC stops simulation. When compiling set -DBIG_ENDIAN if your
       computer is big-endian. Set TERM_CONTROL for a crude single character
       (instead of ANSI line-by-line) input. Works on Unix.
v09tc.c same for Turbo C. Has its own term control.

test09.asm and bench09.asm simple test and benchmark progs.

ef09.asm Implementation of E-Forth, a very rudimentary and portable Forth.
      Type WORDS to see what words you have. You can evaluate RPN integer
      expressions, like "12 34 + 5 * . " You can make new words like
      " : SQUARED DUP * ; " etc.




Running on Fedora Core 6
------------------------
2012-06-04

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




v09* Simulator
--------------

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
v09 BINARY

### start program with tracing output on STDOUT
v09t BINARY

### run program and leave memory dump (64k)

# memory dump in file dump.v09
v09 -d BINARY 



### Bugfixes

* static int index;
  otherwise the global C library function index() is referenced!
  Write access on it leads to a core dump.

 * com with C-operator ~WERT instead 0^WERT ...
   Already fixed in 1994 edition.
 * BIG_ENDIAN is not useable in FLAG because (POSIX?) Unix
   (especially Linux) defines its byte order.
   If BIG_ENDIAN == BYTE_ORDER -> architecture is big endian!
   Changed to CPU_BIG_ENDIAN, which is refering BIG_ENDIAN and
   BYTE_ORDER automatically (if existent).






eForth
------

ef09.asm:

Backspace character changed from 127 to 8.


Memory-Layout:

 0100   At this address the binary is placed to, the Forth entry point
 03C0   USER area start
 4000   Memory TOP


I/O:
    Keyboard input:
     * ^H or BSP deletes character
     * RETURN -> interrupts (long) output

Bugs:
    SEE     ;
    STAR (*)    : * UM* DROP ;  ... wrong,
            : * M* DROP ; ... correct (sign!)

Typical commands:

 Command alway in upper case!!!

WORD        list of defined words of the current vocabulary

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
 * XXX marked  open points
 * SEE:
  * handling of
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





MC6809 ASSEMBLER AND SIMULATOR.

These are the third version of the 6809 assembler and simulator.
Both compile currently under POSIX compatible Unix systems and
(with some porting) other systems.  The assembler should contain very
few system dependencies and should work under MS-DOS as well. 
The Unix version of the simulator depends on the POSIX header file termios.h.
Most modern Unix systems with ANSI C have this. 

THE ASSEMBER

The assembler is a09. Run it with

 a09 [-l listing] [-o object|-s object] source

Source is a mandatory argument. The -l listing and -o or -s object arguments are
optional. By default there is no listing and the object file is the
sourcefile name without an extension and if the source file name has no
extension it is the source file name with .b extension. 

A09 recognizes standard 6809 mnemonics. Labels should start in the first
column and may or may not be terminated by a colon. Every line starting with
a non-alphanumeric is taken to be a comment line. Everything after the
operand field is taken to be comment. There is a full expression evaluator
with C-style operators (and Motorola style number bases). 

There are the usual pseudo-ops such as ORG EQU SET SETDP RMB FCB FDB FCC etc. 
Strings within double quotes may be mixed with numbers on FCB lines. There 
is conditional assembly with IF/ELSE/ENDIF and there is INCLUDE. The
assembler is case-insensitive.

The object file is either a binary image file (-o) or Motorola S-records (-s).
In the former case it contains a binary image of the assembled data starting
at the first address where something is assembled. In the following case
 
	ORG 0
VAR1	RMB 2
VAR2	RMB 2

	ORG $100
START	LDS #$400
        ...

the RMB statements generate no data so the object file contains the memory
image from address $100.
     
The list file contains no pretty lay-out and no pagination. It is assumed
that utilities (Unix pr or enscript) are available for that.

There are no macros and no linkable modules yet. Some provisions are taken
for it in the code.

After the assembler has finished, it prints the number of pass 2 errors.
This should be zero. So if you see
  0 Pass 2 Errors.
then you are lucky.



THE SIMULATOR

The simulator is v09. Run it with
  v09 [-l loadaddr] [-r runaddr] [-t tracefile [-tl tracelo] [-th tracehi]]
      [-e escchar] imagefile

loadaddr runaddr tracelo and tracehi are addresses. They can be entered in
decimal, octal or hex using the C conventions for number input.

If a tracefile is specified, all instructions at addresses between
tracelo and tracehi are traced. Tracing information such as program
location, register contents and opcodes are written to the trace file.

escchar is the escape character. It must be entered as a number. This is
the character that you must type to get the v09 prompt. This is ^]
by default. (0x1d)

imagefile is the file that contains the binary image of the program. This is
the object file generated by a09.

By default the program is loaded at address 0x100 and it is run at the load
address.

At addresses $E000 and $E001 there is an emulated serial port (ACIA). All
bytes sent to it (or read from it) are send to (read from) the terminal and
sometimes to/from a file.
Terminal I/O is in raw mode.

If you press the escape char, you get the v09 prompt. At the prompt you
can enter the following things.
 
 X         to exit the simulator.
 R         to reset the emulated 6809 (very useful).
 Lfilename (no space in between) to log terminal output to a file.
           Control chars and cr are filtered to make the output a normal
           text file. L without a file name stops logging.
 Sfilename to send a specified file to the simulator through its terminal
           input. LF is converted to CR to mimic raw terminal input.
 Ufilename (terminal upload command) to send a file to the 6809 using the
	   X-modem protocol. The 6809 must already run an X-modem receiving
           program.
 Dfilename (terminal download command) to receive a file from the 6809 using
           the X-modem protocol. The 6809 must already run an X-modem
	   sending program.

THE MONITOR PROGRAM

To run the monitor program on the 6809 simulator you just type.

./v09 -l 0xe400 monitor

If all goes well you see something like

Welcome to BUGGY 1.0

and you can type text. Excellent, you are now running 6809 code.

The monitor program has the following single-letter commands.

Daddr,len  Hex/ascii dump of memory region.
Daddr      length=64 bytes by default.
D          address is address after previous dump.

Examples:
  DE400,100
Dump 256 bytes starting at $E400
  D
Dump the next 64 bytes.

Eaddr bytes Enter hexadecimal bytes at address.
Eaddr"ascii" Enter ascii at address.
Eaddr      Enter interactively at address (until empty line).

Examples:
  E0400 86449D033F
Enter the bytes 86 44 9D 03 3F at address $400. 
  E5000"Welcome"
Enter the ASCII codes of "Welcome" at address $400.


Faddr bytes   Find byte string or ascii string from address.
Faddr"ascii"

Find the specified string in memory, starting at the specified address. The
I/O addresses $E000-$E0FF are skipped. The addresses of the first 16
occurrences are shown.

Example
 FE400"SEX"
Search for the word "SEX" starting in the monitor.

Maddr1,addr2,len Move region of memory from addr1 to addr2. If addr2 is
                 1 higher than addr1, a region is filled. 
Example:
 M400,500,80
Move 128 bytes from address $400 to $500.

Sbytes     Enter Motorola S records.

S records are usually entered from a file, either ASCII transfer (S command
from the v09 prompt) or X-MODEM transfer (XX command in monitor, U command
from v09 prompt). Most Motorola cross assemblers generate S records. 

SSaddr,len  Dump memory region as Motorola S records.

These S records can be loaded later by the monitor program.

Usually you capture the S records into a file (use L command at v09 prompt)
or use XSS instead.
The XSS command is the same as SS, except that it outputs the S records
through the X-modem protocol (use D command at v09 prompt).

SOaddr    Set origin address for S-record transfer.

Before entering S records, it sets the first memory address where S records
will be loaded, regardless of the address contained in the S records.

Before the SS command, it sets the first address that will go into the S
records.

Examples.
  SO800
  S1130400etc...
Load the S records at address $800 even though the address in the S records
is $400
  SO8000
  SS400,100
Save the memory region of 256 bytes starting at $400 as S records. The S
records contain addresses starting at $8000.

Aaddr      Enter line-by-line assembler.

You are in the assembler until you make an error or until you enter an empty
line.

  A400
  LDB #$4B
  JSR $03
  SWI
  <empty line>

Uaddr,len  Disassemble memory region.
Uaddr      (disassemble 21 bytes)
U          

Examples:
  UE400,20
Diassemble first 32 bytes of monitor program.
  U
Disassemble next 21 bytes.

Baddr      Set/reset breakpoint at address.
B          Display active breakpoints.

Examples:
  B403
  B408
Set the breakpoints at the addresses $403 and $408.
  B
Show the breakpoints.
  B403
Remove the breakpoint at $403.

Jaddr      JSR to specified address.
Gaddr      Go to specified address.
G          Go to address in PC register.

The registers are loaded from where they are saved (on the stack) and at the
breakpoints SWI instructions are entered. Next the code is executed at the
indicated address. The SWI instruction (or RTS for the J command) returns to
the monitor, saving the registers.

Hexpr      Calculate simple expression in hex with + and -      

Examples:
  H4444+A5
  H4444-44F3

P         Put a temporary breakpoint after current instruction and exeucte it,

P is similar to T, because it usually executes one instruction and returns
to the monitor after it. That does not work for jumps though. Normally you
use P only with JSR instructions if you want to execute the whole subroutine
without single-stepping through it. Now that the T command is unimplemented,
P is the only single step command.

R         Register display.  
Rregvalue Enter new value into register Supported registers:
          X,Y,U,S,A,B,D(direct page),P(program counter),C(condition code).

The R command uses the saved register values (on the stack). There are some
restrictions on changing the S register.

Examples:
  R
Display all registers.
  RB03
  RP4444
Load the B register with $03 and the program counter with $4444

Tnum       Single step trace. UNIMPLEMENTED!!!!
T

Iaddr      Display the contents of the given address. (used to read input 
           port)

Example:
  IE001
Show the ACIA status.

XLaddr     Load binary data using X-modem protocol

Example:
  XL400
Type your escape character and at the v09 prompt type
  ubasic
to load the binary file "basic" at address $400.

XSaddr,len Save binary data using X-modem protocol.

Example:
  XS400,100
to save the memory region of 128 bytes starting at $400
Type your escape character and at the v09 prompt type:
  dfoo

Now the bytes are saved into the file "foo".

XSSaddr,len Save memory region as S records through X-modem protocol.

See SS command for more details.

XX         Execute commands received through X-modem protocol 
           This is usually used to receive S-records.  

Example:
 XX
Now type the escape character and at the v09 prompt type 
 usfile
where sfile is a file with S-records.

XOnl,eof   Set X-modem text output options, first number type of newline.
           1=LF,2=CR,3=CRLF, second number filler byte at end of file
           (sensible options include 0,4,1A) These options are used by
           the XSS command.

Example: Under a UNIX system you want X-modem's text output with just LF
         and a filler byte of 0. Type
      
         XO1,0

Apart from the monitor commands, the monitor program contains I/O routines
that can be used by applications started from it. 

The elementary routines are:
$00 getchar  Input one character into B register.
$03 putchar  Output one character in B register.
$06 getline  Input line at address in X, length in B.
$09 putline  Output string at address in X, length in B.
$0C putcr    Output a newline.

There are other routines that redirect these I/O operations through the
X-modem protocol.

EXAMPLE PROGRAMS

The following example programs you can run from the 6809 monitor.
All of them start at address $400. For example to run the program bin2dec
you type.

XL400

Then press your escape character (default is control-] ).

Then at the v09 prompt type 

ubin2dec

Now you see some lines displaying the progress of the X-modem session.
If that is finished, you type

G400

Now it runs and exits to the monitor with SWI, so that the registers are
displayed.  


cond09.asm
cond09.inc  Nonsense program to show conditional assembly and the like.

bench09.asm Benchmark program. Executes tight loop. Takes 83 secs on
            25 MHz 386. Should take about 8 sec. on 1MHz real 6809. :-(

test09.asm  Tests some nasty features of the 6809. Prints a few lines
            of PASSED nn and should never print ERROR nn.

bin2dec.asm Unusual way to convert numbers to decimal using DAA instruction.
            Prints some test numbers.

basic.asm Tiny BASIC by John Byrns. Docs are in basic.doc.
            To test it start the monitor and run basic.
	    
            Then press your escape char.
            At the v09 prompt type: sexampl.bas

	    Now a BASIC program is input.
	    Type RUN to run it.
	
	    Leave BASIC by pressing the escape char and entering x at the
	    prompt.
	    
kernel09 and the *.4 files. FORTH for the 6809. To run it, type
            XX
 
            Then press the escape char and at the v09 prompt type
 
            ukernel09
         
            Then type 

            G400
           
	    From FORTH type

            XLOAD

            Then press your escape char and at the v09 prompt type

            uextend09.4

            From FORTH type

            XLOAD

            Then press your escape char and at the v09 prompt type
   
            utetris.4

 	    From FORTH type

	    TT

            And play tetris under FORTH on the 6809!


mon2.asm is an alternative version of the monitor program.

alt09.rom is a version of the ROM that contains the alternative monitor and
Forth. Forth is transferrred to RAM by a small loader.
To start Forth type G8000. To start it again, type G400.



Links/References
================


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
