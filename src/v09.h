/* v09.h
   This file is part of the 6809 simulator v09

   created 1994 by L.C. Benschop.
   copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
   license: GNU General Public License version 2, see LICENSE for more details.

*/

typedef unsigned char Byte;
typedef unsigned short Word;

/* 6809 registers */
engine Byte ccreg,dpreg;
engine Word xreg,yreg,ureg,sreg,ureg,pcreg;

engine Byte d_reg[2];
extern Word *dreg;
extern Byte *breg,*areg;

/* 6809 memory space */
#ifdef MSDOS
 engine Byte * mem;
#else
 engine Byte mem[65536];
#endif

engine volatile int tracing,attention,escape,irq;
engine Word tracehi,tracelo;
engine char escchar;

#define IOPAGE 0xe000

void interpr(void);
void do_exit(void);
int do_input(int);
void set_term(char);
void do_trace(void);
void do_output(int,int);
void do_escape(void);


