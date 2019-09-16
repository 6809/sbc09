/* 6809 Simulator V09,

   created 1994 by L.C. Benschop.
   copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
   license: GNU General Public License version 2, see LICENSE for more details.

   This program simulates a 6809 processor.

   System dependencies: short must be 16 bits.
                        char  must be 8 bits.
                        long must be more than 16 bits.
                        arrays up to 65536 bytes must be supported.
                        machine must be twos complement.
   Most Unix machines will work. For MSODS you need long pointers
   and you may have to malloc() the mem array of 65536 bytes.

   Define CPU_BIG_ENDIAN with != 0 if you have a big-endian machine (680x0 etc)
   Usually UNIX systems get this automatically from BIG_ENDIAN and BYTE_ORDER
   definitions ...

   Define TRACE if you want an instruction trace on stderr.
   Define TERM_CONTROL if you want nonblocking non-echoing key input.
   * THIS IS DIRTY !!! *

   Special instructions:
   SWI2 writes char to stdout from register B.
   SWI3 reads char from stdout to register B, sets carry at EOF.
               (or when no key available when using term control).
   SWI retains its normal function.
   CWAI and SYNC stop simulator.

   The program reads a binary image file at $100 and runs it from there.
   The file name must be given on the command line.

   Revisions:
        2012-06-05 johann AT klasek at
                Fixed: com with C "NOT" operator ... 0^(value) did not work!
        2012-06-06
                Fixed: changes from 1994 release (flag handling)
                        reestablished.
        2012-07-15 JK
                New: option parsing, new option -d (dump memory on exit)
        2013-10-07 JK
                New: print ccreg with flag name in lower/upper case depending on flag state.
        2013-10-20 JK
                New: Show instruction disassembling in trace mode.
        2014-07-01 JK
                Fixed: disassembling output: cmpd
        2014-07-11 JK
                Fixed: undocumented tfr/exg register combinations.
                        http://www.6809.org.uk/dragon/illegal-opcodes.shtml
        2016-10-06 JK
                Fixed: wrong cmpu cycles
        2017-10-20 JK
                Fixed: H flag only changed for add and adc.

*/

#include <stdio.h>
#ifdef TERM_CONTROL
#include <fcntl.h>
int tflags;
#endif
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <string.h>
#include <ctype.h>

void finish();

void cr();

static int fdump=0;


/* Default: no big endian ... */
#ifndef CPU_BIG_ENDIAN
/* check if environment provides some information about this ... */
# if defined(BIG_ENDIAN) && defined(BYTE_ORDER)
#  if BIG_ENDIAN == BYTE_ORDER
#   define CPU_BIG_ENDIAN 1
#  else
#   define CPU_BIG_ENDIAN 0
#  endif
# endif
#endif


typedef unsigned char Byte;
typedef unsigned short Word;

/* 6809 registers */
Byte ccreg,dpreg;
Word xreg,yreg,ureg,sreg,ureg,pcreg;

Byte fillreg = 0xff;
Word wfillreg = 0xffff;

Word pcreg_prev;

Byte d_reg[2];
Word *dreg=(Word *)d_reg;


/* This is a dirty aliasing trick, but fast! */
#if CPU_BIG_ENDIAN
 Byte *areg=d_reg;
 Byte *breg=d_reg+1;
#else
 Byte *breg=d_reg;
 Byte *areg=d_reg+1;
#endif


/* 6809 memory space */
static Byte mem[65536];

#define GETWORD(a) (mem[a]<<8|mem[(a)+1])
#define SETWORD(a,n) {mem[a]=(n)>>8;mem[(a)+1]=n;}
/* Two bytes of a word are fetched separately because of
   the possible wrap-around at address $ffff and alignment
*/


int iflag; /* flag to indicate prebyte $10 or $11 */
Byte ireg; /* Instruction register */

#define IMMBYTE(b) b=mem[pcreg++];
#define IMMWORD(w) {w=GETWORD(pcreg);pcreg+=2;}

/* sreg */
#define PUSHBYTE(b) mem[--sreg]=b;
#define PUSHWORD(w) {sreg-=2;SETWORD(sreg,w)}
#define PULLBYTE(b) b=mem[sreg++];
#define PULLWORD(w) {w=GETWORD(sreg);sreg+=2;}

/* ureg */
#define PUSHUBYTE(b) mem[--ureg]=b;
#define PUSHUWORD(w) {ureg-=2;SETWORD(ureg,w)}
#define PULLUBYTE(b) b=mem[ureg++];
#define PULLUWORD(w) {w=GETWORD(ureg);ureg+=2;}

#define SIGNED(b) ((Word)(b&0x80?b|0xff00:b))

Word *ixregs[]={&xreg,&yreg,&ureg,&sreg};

static int idx;

/* disassembled instruction buffer */
static char dinst[6];

/* disassembled operand buffer */
static char dops[32];

/* disassembled instruction len (optional, on demand) */
static int da_len;

/* instruction cycles */
static int cycles;
unsigned long cycles_sum;

void da_inst(char *inst, char *reg, int cyclecount) {
        *dinst = 0;
        *dops = 0;
        if (inst != NULL) strcat(dinst, inst);
        if (reg != NULL) strcat(dinst, reg);
        cycles += cyclecount;
}

void da_inst_cat(char *inst, int cyclecount) {
        if (inst != NULL) strcat(dinst, inst);
        cycles += cyclecount;
}

void da_ops(char *part1, char* part2, int cyclecount) {
        if (part1 != NULL) strcat(dops, part1);
        if (part2 != NULL) strcat(dops, part2);
        cycles += cyclecount;
}

void da_reg(Byte b)
{
  char *reg[] = { "d", "x", "y", "u", "s", "pc", "?", "?",
                  "a", "b", "cc", "dp", "?", "?", "?", "?" };
  da_ops( reg[(b>>4) & 0xf], ",", 0);
  da_ops( reg[b & 0xf], NULL, 0);
}

/* Now follow the posbyte addressing modes. */

Word illaddr() /* illegal addressing mode, defaults to zero */
{
 return 0;
}

static char *dixreg[] = { "x", "y", "u", "s" };

Word ainc()
{
 da_ops(",",dixreg[idx],2);
 da_ops("+",NULL,0);
 return (*ixregs[idx])++;
}

Word ainc2()
{
 Word temp;
 da_ops(",",dixreg[idx],3);
 da_ops("++",NULL,0);
 temp=(*ixregs[idx]);
 (*ixregs[idx])+=2;
 return(temp);
}

Word adec()
{
 da_ops(",-",dixreg[idx],2);
 return --(*ixregs[idx]);
}

Word adec2()
{
 Word temp;
 da_ops(",--",dixreg[idx],3);
 (*ixregs[idx])-=2;
 temp=(*ixregs[idx]);
 return(temp);
}

Word plus0()
{
 da_ops(",",dixreg[idx],0);
 return(*ixregs[idx]);
}

Word plusa()
{
 da_ops("a,",dixreg[idx],1);
 return(*ixregs[idx])+SIGNED(*areg);
}

Word plusb()
{
 da_ops("b,",dixreg[idx],1);
 return(*ixregs[idx])+SIGNED(*breg);
}

Word plusn()
{
 Byte b;
 char off[6];
 IMMBYTE(b)
 /* negative offsets alway decimal, otherwise hex */
 if (b & 0x80) sprintf(off,"%d,", -(b ^ 0xff)-1);
 else sprintf(off,"$%02x,",b);
 da_ops(off,dixreg[idx],1);
 return(*ixregs[idx])+SIGNED(b);
}

Word plusnn()
{
 Word w;
 IMMWORD(w)
 char off[6];
 sprintf(off,"$%04x,",w);
 da_ops(off,dixreg[idx],4);
 return(*ixregs[idx])+w;
}

Word plusd()
{
 da_ops("d,",dixreg[idx],4);
 return(*ixregs[idx])+*dreg;
}


Word npcr()
{
 Byte b;
 char off[11];

 IMMBYTE(b)
 sprintf(off,"$%04x,pcr",(pcreg+SIGNED(b))&0xffff);
 da_ops(off,NULL,1);
 return pcreg+SIGNED(b);
}

Word nnpcr()
{
 Word w;
 char off[11];

 IMMWORD(w)
 sprintf(off,"$%04x,pcr",(pcreg+w)&0xffff);
 da_ops(off,NULL,5);
 return pcreg+w;
}

Word direct()
{
 Word(w);
 char off[6];

 IMMWORD(w)
 sprintf(off,"$%04x",w);
 da_ops(off,NULL,3);
 return w;
}

Word zeropage()
{
 Byte b;
 char off[6];

 IMMBYTE(b)
 sprintf(off,"$%02x", b);
 da_ops(off,NULL,2);
 return dpreg<<8|b;
}


Word immediate()
{
 char off[6];

 sprintf(off,"#$%02x", mem[pcreg]);
 da_ops(off,NULL,0);
 return pcreg++;
}

Word immediate2()
{
 Word temp;
 char off[7];

 temp=pcreg;
 sprintf(off,"#$%04x", (mem[pcreg]<<8)+mem[(pcreg+1)&0xffff]);
 da_ops(off,NULL,0);
 pcreg+=2;
 return temp;
}

Word (*pbtable[])()={ ainc, ainc2, adec, adec2,
                      plus0, plusb, plusa, illaddr,
                      plusn, plusnn, illaddr, plusd,
                      npcr, nnpcr, illaddr, direct, };

Word postbyte()
{
 Byte pb;
 Word temp;
 char off[6];

 IMMBYTE(pb)
 idx=((pb & 0x60) >> 5);
 if(pb & 0x80) {
  if( pb & 0x10)
        da_ops("[",NULL,3);
  temp=(*pbtable[pb & 0x0f])();
  if( pb & 0x10) {
        temp=GETWORD(temp);
        da_ops("]",NULL,0);
  }
  return temp;
 } else {
  temp=pb & 0x1f;
  if(temp & 0x10) temp|=0xfff0; /* sign extend */
  sprintf(off,"%d,",(temp & 0x10) ? -(temp ^ 0xffff)-1 : temp);
  da_ops(off,dixreg[idx],1);
  return (*ixregs[idx])+temp;
 }
}

Byte * eaddr0() /* effective address for NEG..JMP as byte pointer */
{
 switch( (ireg & 0x70) >> 4)
 {
  case 0: return mem+zeropage();
  case 1:case 2:case 3: return 0; /*canthappen*/

  case 4: da_inst_cat("a",-2); return areg;
  case 5: da_inst_cat("b",-2); return breg;
  case 6: da_inst_cat(NULL,2); return mem+postbyte();
  case 7: return mem+direct();
 }
}

Word eaddr8()  /* effective address for 8-bits ops. */
{
 switch( (ireg & 0x30) >> 4)
 {
  case 0: return immediate();
  case 1: return zeropage();
  case 2: da_inst_cat(NULL,2); return postbyte();
  case 3: return direct();
 }
}

Word eaddr16() /* effective address for 16-bits ops. */
{
 switch( (ireg & 0x30) >> 4)
 {
  case 0: da_inst_cat(NULL,-1); return immediate2();
  case 1: da_inst_cat(NULL,-1); return zeropage();
  case 2: da_inst_cat(NULL,1); return postbyte();
  case 3: da_inst_cat(NULL,-1); return direct();
 }
}

void ill() /* illegal opcode==noop */
{
}

/* macros to set status flags */
#define SEC ccreg|=0x01;
#define CLC ccreg&=0xfe;
#define SEZ ccreg|=0x04;
#define CLZ ccreg&=0xfb;
#define SEN ccreg|=0x08;
#define CLN ccreg&=0xf7;
#define SEV ccreg|=0x02;
#define CLV ccreg&=0xfd;
#define SEH ccreg|=0x20;
#define CLH ccreg&=0xdf;

/* set N and Z flags depending on 8 or 16 bit result */
#define SETNZ8(b) {if(b)CLZ else SEZ if(b&0x80)SEN else CLN}
#define SETNZ16(b) {if(b)CLZ else SEZ if(b&0x8000)SEN else CLN}


#define SETSTATUS(a,b,res) if((a^b^res^(res>>1))&0x80)SEV else CLV \
                           if(res&0x100)SEC else CLC SETNZ8((Byte)res)

#define SETSTATUS_H(a,b,res) if((a^b^res)&0x10) SEH else CLH \
                           if((a^b^res^(res>>1))&0x80)SEV else CLV \
                           if(res&0x100)SEC else CLC SETNZ8((Byte)res)

void add()
{
 Word aop,bop,res;
 Byte* aaop;
 da_inst("add",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop+bop;
 SETSTATUS_H(aop,bop,res)
 *aaop=res;
}

void sbc()
{
 Word aop,bop,res;
 Byte* aaop;
 da_inst("sbc",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop-bop-(ccreg&0x01);
 SETSTATUS(aop,bop,res)
 *aaop=res;
}

void sub()
{
 Word aop,bop,res;
 Byte* aaop;
 da_inst("sub",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop-bop;
 SETSTATUS(aop,bop,res)
 *aaop=res;
}

void adc()
{
 Word aop,bop,res;
 Byte* aaop;
 da_inst("adc",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop+bop+(ccreg&0x01);
 SETSTATUS_H(aop,bop,res)
 *aaop=res;
}

void cmp()
{
 Word aop,bop,res;
 Byte* aaop;
 da_inst("cmp",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop-bop;
 SETSTATUS(aop,bop,res)
}

void and()
{
 Byte aop,bop,res;
 Byte* aaop;
 da_inst("and",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop&bop;
 SETNZ8(res)
 CLV
 *aaop=res;
}

void or()
{
 Byte aop,bop,res;
 Byte* aaop;
 da_inst("or",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop|bop;
 SETNZ8(res)
 CLV
 *aaop=res;
}

void eor()
{
 Byte aop,bop,res;
 Byte* aaop;
 da_inst("eor",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop^bop;
 SETNZ8(res)
 CLV
 *aaop=res;
}

void bit()
{
 Byte aop,bop,res;
 Byte* aaop;
 da_inst("bit",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop&bop;
 SETNZ8(res)
 CLV
}

void ld()
{
 Byte res;
 Byte* aaop;
 da_inst("ld",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 res=mem[eaddr8()];
 SETNZ8(res)
 CLV
 *aaop=res;
}

void st()
{
 Byte res;
 Byte* aaop;
 da_inst("st",(ireg&0x40)?"b":"a",2);
 aaop=(ireg&0x40)?breg:areg;
 res=*aaop;
 mem[eaddr8()]=res;
 SETNZ8(res)
 CLV
}

void jsr()
{
 Word w;

 da_inst("jsr",NULL,5);
 da_len=-pcreg;
 w=eaddr8();
 da_len += pcreg +1;
 PUSHWORD(pcreg)
 pcreg=w;
}

void bsr()
{
 Byte b;
 char off[6];
 
 IMMBYTE(b)
 da_inst("bsr",NULL,7);
 da_len = 2;
 PUSHWORD(pcreg)
 pcreg+=SIGNED(b);
 sprintf(off,"$%04x", pcreg&0xffff);
 da_ops(off,NULL,0);
}

void neg()
{
 Byte *ea;
 Word a,r;

 a=0;
 da_inst("neg",NULL,4);
 ea=eaddr0();
 a=*ea;
 r=-a;
 SETSTATUS(0,a,r)
 *ea=r;
}

void com()
{
 Byte *ea;
 Byte r;

 da_inst("com",NULL,4);
 ea=eaddr0();
/*
 fprintf(stderr,"DEBUG: com before r=%02X *ea=%02X\n", r, *ea);
*/
 r= ~*ea;
/*
 fprintf(stderr,"DEBUG: com after r=%02X *ea=%02X\n", r, *ea);
*/
 SETNZ8(r)
 SEC CLV
 *ea=r;
}

void lsr()
{
 Byte *ea;
 Byte r;

 da_inst("lsr",NULL,4);
 ea=eaddr0();
 r=*ea;
 if(r&0x01)SEC else CLC
 /* according to Motorola 6809 and Hitachi 6309 Programmer's Reference
  * half-carry is not changed
  */
 r>>=1;
 SETNZ8(r)
 *ea=r;
}

void ror()
{
 Byte *ea;
 Byte r,c;

 c=(ccreg&0x01)<<7;
 da_inst("ror",NULL,4);
 ea=eaddr0();
 r=*ea;
 if(r&0x01)SEC else CLC
 r=(r>>1)+c;
 SETNZ8(r)
 *ea=r;
}

void asr()
{
 Byte *ea;
 Byte r;

 da_inst("asr",NULL,4);
 ea=eaddr0();
 r=*ea;
 if(r&0x01)SEC else CLC
 if(r&0x10)SEH else CLH
 r>>=1;
 if(r&0x40)r|=0x80;
 SETNZ8(r)
 *ea=r;
}

void asl()
{
 Byte *ea;
 Word a,r;

 da_inst("asl",NULL,4);
 ea=eaddr0();
 a=*ea;
 r=a<<1;
 /* according to Motorola 6809 and Hitachi 6309 Programmer's Reference
  * half-carry is not defined, but for an arithmetic operation the
  * flag behaves like an add operation where the operator is added to
  * itself.
  */
 SETSTATUS_H(a,a,r)
 *ea=r;
}

void rol()
{
 Byte *ea;
 Byte r,c;

 c=(ccreg&0x01);
 da_inst("rol",NULL,4);
 ea=eaddr0();
 r=*ea;
 if(r&0x80)SEC else CLC
 if((r&0x80)^((r<<1)&0x80))SEV else CLV
 r=(r<<1)+c;
 SETNZ8(r)
 *ea=r;
}

void inc()
{
 Byte *ea;
 Byte r;

 da_inst("inc",NULL,4);
 ea=eaddr0();
 r=*ea;
 r++;
 if(r==0x80)SEV else CLV
 SETNZ8(r)
 *ea=r;
}

void dec()
{
 Byte *ea;
 Byte r;

 da_inst("dec",NULL,4);
 ea=eaddr0();
 r=*ea;
 r--;
 if(r==0x7f)SEV else CLV
 SETNZ8(r)
 *ea=r;
}

void tst()
{
 Byte r;
 Byte *ea;

 da_inst("tst",NULL,4);
 ea=eaddr0();
 r=*ea;
 SETNZ8(r)
 CLV
}

void jmp()
{
 Byte *ea;

 da_len = -pcreg;
 da_inst("jmp",NULL,1);
 ea=eaddr0();
 da_len += pcreg + 1;
 pcreg=ea-mem;
}

void clr()
{
 Byte *ea;

 da_inst("clr",NULL,4);
 ea=eaddr0();
 *ea=0;CLN CLV SEZ CLC
}

extern void (*instrtable[])();

void flag0()
{
 if(iflag) /* in case flag already set by previous flag instr don't recurse */
 {
  pcreg--;
  return;
 }
 iflag=1;
 ireg=mem[pcreg++];
 da_inst(NULL,NULL,1);
 (*instrtable[ireg])();
 iflag=0;
}

void flag1()
{
 if(iflag) /* in case flag already set by previous flag instr don't recurse */
 {
  pcreg--;
  return;
 }
 iflag=2;
 ireg=mem[pcreg++];
 da_inst(NULL,NULL,1);
 (*instrtable[ireg])();
 iflag=0;
}

void nop()
{
 da_inst("nop",NULL,2);
}

void sync_inst()
{
 finish();
}

void cwai()
{
 sync_inst();
}

void lbra()
{
 Word w;
 char off[6];

 IMMWORD(w)
 pcreg+=w;
 da_len = 3;
 da_inst("lbra",NULL,5);
 sprintf(off,"$%04x", pcreg&0xffff);
 da_ops(off,NULL,0);
}

void lbsr()
{
 Word w;
 char off[6];

 da_len = 3;
 da_inst("lbsr",NULL,9);
 IMMWORD(w)
 PUSHWORD(pcreg)
 pcreg+=w;
 sprintf(off,"$%04x", pcreg&0xffff);
 da_ops(off,NULL,0);
}

void daa()
{
 Word a;
 da_inst("daa",NULL,2);
 a=*areg;
 if(ccreg&0x20)a+=6;
 if((a&0x0f)>9)a+=6;
 if(ccreg&0x01)a+=0x60;
 if((a&0xf0)>0x90)a+=0x60;
 if(a&0x100)SEC
 *areg=a;
}

void orcc()
{
 Byte b;
 char off[7];
 IMMBYTE(b)
 sprintf(off,"#$%02x", b);
 da_inst("orcc",NULL,3);
 da_ops(off,NULL,0);
 ccreg|=b;
}

void andcc()
{
 Byte b;
 char off[6];
 IMMBYTE(b)
 sprintf(off,"#$%02x", b);
 da_inst("andcc",NULL,3);
 da_ops(off,NULL,0);

 ccreg&=b;
}

void mul()
{
 Word w;
 w=*areg * *breg;
 da_inst("mul",NULL,11);
 if(w)CLZ else SEZ
 if(w&0x80) SEC else CLC
 *dreg=w;
}

void sex()
{
 Word w;
 da_inst("sex",NULL,2);
 w=SIGNED(*breg);
 SETNZ16(w)
 *dreg=w;
}

void abx()
{
 da_inst("abx",NULL,3);
 xreg += *breg;
}

void rts()
{
 da_inst("rts",NULL,5);
 da_len = 1;
 PULLWORD(pcreg)
}

void rti()
{
 Byte x;
 x=ccreg&0x80;
 da_inst("rti",NULL,(x?15:6));
 da_len = 1;
 PULLBYTE(ccreg)
 if(x)
 {
  PULLBYTE(*areg)
  PULLBYTE(*breg)
  PULLBYTE(dpreg)
  PULLWORD(xreg)
  PULLWORD(yreg)
  PULLWORD(ureg)
 }
 PULLWORD(pcreg)
}

void swi()
{
 int w;
 da_inst("swi",(iflag==1)?"2":(iflag==2)?"3":"",5);
 switch(iflag)
 {
  case 0:
   PUSHWORD(pcreg)
   PUSHWORD(ureg)
   PUSHWORD(yreg)
   PUSHWORD(xreg)
   PUSHBYTE(dpreg)
   PUSHBYTE(*breg)
   PUSHBYTE(*areg)
   PUSHBYTE(ccreg)
   ccreg|=0xd0;
   pcreg=GETWORD(0xfffa);
   break;
  case 1:
   putchar(*breg);
   fflush(stdout);
   break;
  case 2:
   w=getchar();
   if(w==EOF)SEC else CLC
   *breg=w;
 }
}


Word *wordregs[]={(Word*)d_reg,&xreg,&yreg,&ureg,&sreg,&pcreg,&wfillreg,&wfillreg};

#if CPU_BIG_ENDIAN
Byte *byteregs[]={d_reg,d_reg+1,&ccreg,&dpreg,&fillreg,&fillreg,&fillreg,&fillreg};
#else
Byte *byteregs[]={d_reg+1,d_reg,&ccreg,&dpreg,&fillreg,&fillreg,&fillreg,&fillreg};
#endif

void tfr()
{
 Byte b;
 da_inst("tfr",NULL,7);
 IMMBYTE(b)
 da_reg(b);
 Word v;
 // see http://www.6809.org.uk/dragon/illegal-opcodes.shtml
 // source in higher nibble (highest bit set means 8 bit reg.)
 if(b&0x80) {
  v=*byteregs[(b&0x70)>>4] | 0xff00;
 } else {
  v=*wordregs[(b&0x70)>>4];
 }
 // dest in lower nibble (highest bit set means 8 bit reg.)
 if(b&0x8) {
  *byteregs[b&0x07]=v &0xff;
  fillreg=0xff;  // keep fillvalue
 } else {
  *wordregs[b&0x07]=v;
  wfillreg = 0xffff;  // keep fillvalue
 }
}

void exg()
{
 Byte b;
 Word f;
 Word t;
 da_inst("exg",NULL,8);
 // see http://www.6809.org.uk/dragon/illegal-opcodes.shtml
 // 8 <-> 16, high byte is filled with $ff!
 IMMBYTE(b)
 da_reg(b);
 if(b&0x80) {
  f=*byteregs[(b&0x70)>>4] | 0xff00;
 } else {
  f=*wordregs[(b>>4)&0x07];
 }
 if(b&0x8) {
  t=*byteregs[b&0x07] | 0xff00;
 } else {
  t=*wordregs[b&0x07];
 }
 if(b&0x80) {
  *byteregs[(b&0x70)>>4] = t;
  fillreg=0xff;  // keep fillvalue
 } else {
  *wordregs[(b>>4)&0x07] = t;
  wfillreg = 0xffff;  // keep fillvalue
 }
 if(b&0x8) {
  *byteregs[b&0x07] = f;
  fillreg=0xff;  // keep fillvalue
 } else {
  *wordregs[b&0x07] = f;
  wfillreg = 0xffff;  // keep fillvalue
 }
}

void br(int f)
{
 Byte b;
 Word w;
 char off[7];
 Word dest;

 if(!iflag) {
  IMMBYTE(b)
  dest = pcreg+SIGNED(b);
  if(f) pcreg+=SIGNED(b);
  da_len = 2;
 } else {
  IMMWORD(w)
  dest = pcreg+w;
  if(f) pcreg+=w;
  da_len = 3;
 }
 sprintf(off,"$%04x", dest&0xffff);
 da_ops(off,NULL,0);
}

#define NXORV  ((ccreg&0x08)^(ccreg&0x02))

void bra()
{
 da_inst(iflag?"l":"","bra",iflag?5:3);
 br(1);
}

void brn()
{
 da_inst(iflag?"l":"","brn",iflag?5:3);
 br(0);
}

void bhi()
{
 da_inst(iflag?"l":"","bhi",iflag?5:3);
 br(!(ccreg&0x05));
}

void bls()
{
 da_inst(iflag?"l":"","bls",iflag?5:3);
 br(ccreg&0x05);
}

void bcc()
{
 da_inst(iflag?"l":"","bcc",iflag?5:3);
 br(!(ccreg&0x01));
}

void bcs()
{
 da_inst(iflag?"l":"","bcs",iflag?5:3);
 br(ccreg&0x01);
}

void bne()
{
 da_inst(iflag?"l":"","bne",iflag?5:3);
 br(!(ccreg&0x04));
}

void beq()
{
 da_inst(iflag?"l":"","beq",iflag?5:3);
 br(ccreg&0x04);
}

void bvc()
{
 da_inst(iflag?"l":"","bvc",iflag?5:3);
 br(!(ccreg&0x02));
}

void bvs()
{
 da_inst(iflag?"l":"","bvs",iflag?5:3);
 br(ccreg&0x02);
}

void bpl()
{
 da_inst(iflag?"l":"","bpl",iflag?5:3);
 br(!(ccreg&0x08));
}

void bmi()
{
 da_inst(iflag?"l":"","bmi",iflag?5:3);
 br(ccreg&0x08);
}

void bge()
{
 da_inst(iflag?"l":"","bge",iflag?5:3);
 br(!NXORV);
}

void blt()
{
 da_inst(iflag?"l":"","blt",iflag?5:3);
 br(NXORV);
}

void bgt()
{
 da_inst(iflag?"l":"","bgt",iflag?5:3);
 br(!(NXORV||ccreg&0x04));
}

void ble()
{
 da_inst(iflag?"l":"","ble",iflag?5:3);
 br(NXORV||ccreg&0x04);
}

void leax()
{
 Word w;
 da_inst("leax",NULL,4);
 w=postbyte();
 if(w) CLZ else SEZ
 xreg=w;
}

void leay()
{
 Word w;
 da_inst("leay",NULL,4);
 w=postbyte();
 if(w) CLZ else SEZ
 yreg=w;
}

void leau()
{
 da_inst("leau",NULL,4);
 ureg=postbyte();
}

void leas()
{
 da_inst("leas",NULL,4);
 sreg=postbyte();
}


int bit_count(Byte b)
{
  Byte mask=0x80;
  int count=0;
  int i;
  char *reg[] = { "pc", "u", "y", "x", "dp", "b", "a", "cc" };

  for(i=0; i<=7; i++) {
        if (b & mask) {
                count++;
                da_ops(count > 1 ? ",":"", reg[i],1+(i<4?1:0));
        }
        mask >>= 1;
  }
  return count;
}


void pshs()
{
 Byte b;
 IMMBYTE(b)
 da_inst("pshs",NULL,5);
 bit_count(b);
 if(b&0x80)PUSHWORD(pcreg)
 if(b&0x40)PUSHWORD(ureg)
 if(b&0x20)PUSHWORD(yreg)
 if(b&0x10)PUSHWORD(xreg)
 if(b&0x08)PUSHBYTE(dpreg)
 if(b&0x04)PUSHBYTE(*breg)
 if(b&0x02)PUSHBYTE(*areg)
 if(b&0x01)PUSHBYTE(ccreg)
}

void puls()
{
 Byte b;
 IMMBYTE(b)
 da_inst("puls",NULL,5);
 da_len = 2;
 bit_count(b);
 if(b&0x01)PULLBYTE(ccreg)
 if(b&0x02)PULLBYTE(*areg)
 if(b&0x04)PULLBYTE(*breg)
 if(b&0x08)PULLBYTE(dpreg)
 if(b&0x10)PULLWORD(xreg)
 if(b&0x20)PULLWORD(yreg)
 if(b&0x40)PULLWORD(ureg)
 if(b&0x80)PULLWORD(pcreg)
}

void pshu()
{
 Byte b;
 IMMBYTE(b)
 da_inst("pshu",NULL,5);
 bit_count(b);
 if(b&0x80)PUSHUWORD(pcreg)
 if(b&0x40)PUSHUWORD(ureg)
 if(b&0x20)PUSHUWORD(yreg)
 if(b&0x10)PUSHUWORD(xreg)
 if(b&0x08)PUSHUBYTE(dpreg)
 if(b&0x04)PUSHUBYTE(*breg)
 if(b&0x02)PUSHUBYTE(*areg)
 if(b&0x01)PUSHUBYTE(ccreg)
}

void pulu()
{
 Byte b;
 IMMBYTE(b)
 da_inst("pulu",NULL,5);
 da_len = 2;
 bit_count(b);
 if(b&0x01)PULLUBYTE(ccreg)
 if(b&0x02)PULLUBYTE(*areg)
 if(b&0x04)PULLUBYTE(*breg)
 if(b&0x08)PULLUBYTE(dpreg)
 if(b&0x10)PULLUWORD(xreg)
 if(b&0x20)PULLUWORD(yreg)
 if(b&0x40)PULLUWORD(ureg)
 if(b&0x80)PULLUWORD(pcreg)
}

#define SETSTATUSD(a,b,res) {if(res&0x10000) SEC else CLC \
                            if(((res>>1)^a^b^res)&0x8000) SEV else CLV \
                            SETNZ16((Word)res)}

void addd()
{
 unsigned long aop,bop,res;
 Word ea;
 da_inst("addd",NULL,5);
 aop=*dreg & 0xffff;
 ea=eaddr16();
 bop=GETWORD(ea);
 res=aop+bop;
 SETSTATUSD(aop,bop,res)
 *dreg=res;
}

void subd()
{
 unsigned long aop,bop,res;
 Word ea;
 aop=*dreg & 0xffff;
 switch(iflag) {
  case 0:
        da_inst("subd",NULL,5);
        break;
  case 1:
        da_inst("cmpd",NULL,5);
        aop=*dreg & 0xffff;
        break;
  case 2:
        da_inst("cmpu",NULL,5);
        aop=ureg;
 }
 ea=eaddr16();
 bop=GETWORD(ea);
 res=aop-bop;
 SETSTATUSD(aop,bop,res)
 if(iflag==0) *dreg=res; /* subd result */
}

void cmpx()
{
 unsigned long aop,bop,res;
 Word ea;
 switch(iflag) {
  case 0:
        da_inst("cmpx",NULL,5);
        aop=xreg;
        break;
  case 1:
        da_inst("cmpy",NULL,5);
        aop=yreg;
        break;
  case 2:
        da_inst("cmps",NULL,5);
        aop=sreg;
 }
 ea=eaddr16();
 bop=GETWORD(ea);
 res=aop-bop;
 SETSTATUSD(aop,bop,res)
}

void ldd()
{
 Word ea,w;
 da_inst("ldd",NULL,4);
 ea=eaddr16();
 w=GETWORD(ea);
 SETNZ16(w)
 *dreg=w;
}

void ldx()
{
 Word ea,w;
 if (iflag) da_inst("ldy",NULL,4);
 else da_inst("ldx",NULL,4);
 ea=eaddr16();
 w=GETWORD(ea);
 SETNZ16(w)
 if (iflag==0) xreg=w; else yreg=w;
}

void ldu()
{
 Word ea,w;
 if (iflag) da_inst("lds",NULL,4);
 else da_inst("ldu",NULL,4);
 ea=eaddr16();
 w=GETWORD(ea);
 SETNZ16(w)
 if (iflag==0) ureg=w; else sreg=w;
}

void std()
{
 Word ea,w;
 da_inst("std",NULL,4);
 ea=eaddr16();
 w=*dreg;
 SETNZ16(w)
 SETWORD(ea,w)
}

void stx()
{
 Word ea,w;
 if (iflag) da_inst("sty",NULL,4);
 else da_inst("stx",NULL,4);
 ea=eaddr16();
 if (iflag==0) w=xreg; else w=yreg;
 SETNZ16(w)
 SETWORD(ea,w)
}

void stu()
{
 Word ea,w;
 if (iflag) da_inst("sts",NULL,4);
 else da_inst("stu",NULL,4);
 ea=eaddr16();
 if (iflag==0) w=ureg; else w=sreg;
 SETNZ16(w)
 SETWORD(ea,w)
}

void (*instrtable[])() = {
 neg , ill , ill , com , lsr , ill , ror , asr ,
 asl , rol , dec , ill , inc , tst , jmp , clr ,
 flag0 , flag1 , nop , sync_inst , ill , ill , lbra , lbsr ,
 ill , daa , orcc , ill , andcc , sex , exg , tfr ,
 bra , brn , bhi , bls , bcc , bcs , bne , beq ,
 bvc , bvs , bpl , bmi , bge , blt , bgt , ble ,
 leax , leay , leas , leau , pshs , puls , pshu , pulu ,
 ill , rts , abx , rti , cwai , mul , ill , swi ,
 neg , ill , ill , com , lsr , ill , ror , asr ,
 asl , rol , dec , ill , inc , tst , ill , clr ,
 neg , ill , ill , com , lsr , ill , ror , asr ,
 asl , rol , dec , ill , inc , tst , ill , clr ,
 neg , ill , ill , com , lsr , ill , ror , asr ,
 asl , rol , dec , ill , inc , tst , jmp , clr ,
 neg , ill , ill , com , lsr , ill , ror , asr ,
 asl , rol , dec , ill , inc , tst , jmp , clr ,
sub , cmp , sbc , subd , and , bit , ld , st ,
eor , adc ,  or , add , cmpx , bsr , ldx , stx ,
sub , cmp , sbc , subd , and , bit , ld , st ,
eor , adc ,  or , add , cmpx , jsr , ldx , stx ,
sub , cmp , sbc , subd , and , bit , ld , st ,
eor , adc ,  or , add , cmpx , jsr , ldx , stx ,
sub , cmp , sbc , subd , and , bit , ld , st ,
eor , adc ,  or , add , cmpx , jsr , ldx , stx ,
sub , cmp , sbc , addd , and , bit , ld , st ,
eor , adc ,  or , add , ldd , std , ldu , stu ,
sub , cmp , sbc , addd , and , bit , ld , st ,
eor , adc ,  or , add , ldd , std , ldu , stu ,
sub , cmp , sbc , addd , and , bit , ld , st ,
eor , adc ,  or , add , ldd , std , ldu , stu ,
sub , cmp , sbc , addd , and , bit , ld , st ,
eor , adc ,  or , add , ldd , std , ldu , stu ,
};

void read_image(char* name)
{
 FILE *image;
 if((image=fopen(name,"rb"))!=NULL) {
  fread(mem+0x100,0xff00,1,image);
  fclose(image);
 }
}

void dump()
{
 FILE *image;
 if((image=fopen("dump.v09","wb"))!=NULL) {
  fwrite(mem,0x10000,1,image);
  fclose(image);
 }
}

/* E F H I N Z V C */

char *to_bin(Byte b)
{
        static char binstr[9];
        Byte bm;
        char *ccbit="EFHINZVC";
        int i;

        for(bm=0x80, i=0; bm>0; bm >>=1, i++)
                binstr[i] = (b & bm) ? toupper(ccbit[i]) : tolower(ccbit[i]);
        binstr[8] = 0;
        return binstr;
}


void cr() {
   #ifdef TERM_CONTROL
   fprintf(stderr,"%s","\r\n");         /* CR+LF because raw terminal ... */
   #else
   fprintf(stderr,"%s","\n");
   #endif
}

#ifdef TRACE

/* max. bytes of instruction code per trace line */
#define I_MAX 4

void trace()
{
   int ilen;
   int i;

  if (
   1 ||                                         /* no trace filtering ... */
   !(ureg > 0x09c0 && ureg < 0x09f3) && (       /* CMOVE ausblenden! */
    pcreg_prev == 0x01de || /* DOLST */
    pcreg_prev == 0x037a || /* FDOVAR */
  /*
    ureg >= 0x0300 && ureg < 0x03f0 ||
    ureg >=0x1900 ||
    ureg > 0x118b && ureg < 0x11b2 ||
    pcreg_prev >= 0x01de && pcreg_prev < 0x0300 ||
    xreg >=0x8000 ||
    pcreg_prev >= 0x01de && pcreg_prev < 0x0300 ||
   */
    0
    )
   )
  {
   fprintf(stderr,"%04x ",pcreg_prev);
   if (da_len) ilen = da_len;
   else {
        ilen = pcreg-pcreg_prev; if (ilen < 0) ilen= -ilen;
   }
   for(i=0; i < I_MAX; i++) {
        if (i < ilen) fprintf(stderr,"%02x",mem[(pcreg_prev+i)&0xffff]);
        else fprintf(stderr,"  ");
   }
   fprintf(stderr," %-5s %-17s [%02d] ", dinst, dops, cycles);
   //if((ireg&0xfe)==0x10)
   // fprintf(stderr,"%02x ",mem[pcreg]);else fprintf(stderr,"   ");
   fprintf(stderr,"x=%04x y=%04x u=%04x s=%04x a=%02x b=%02x cc=%s",
                   xreg,yreg,ureg,sreg,*areg,*breg,to_bin(ccreg));
   fprintf(stderr,", s: %04x %04x, r: %04x",
        mem[sreg]<<8|mem[sreg+1],
        mem[sreg+2]<<8|mem[sreg+3],
        mem[yreg]<<8|mem[yreg+1]
   );
   cr();
  }
  da_len = 0;
}

#endif


static char optstring[]="d";

void main(int argc,char *argv[])
{
 char c;
 int a;

 /* initialize memory with pseudo random data ... */
 srandom(time(NULL));
 for(a=0x0100; a<0x10000;a++) {
        mem[(Word)a] = (Byte) (random() & 0xff);
 }

 while( (c=getopt(argc, argv, optstring)) >=0 ) {
        switch(c) {
          case 'd':
                fdump = 1;
                break;
          default:
                fprintf(stderr,"ERROR: Unknown option\n");
                exit(2);
        }
 }

 if (optind < argc) {
   read_image(argv[optind]);
 }
 else {
        fprintf(stderr,"ERROR: Missing image name\n");
        exit(2);
 }

 pcreg=0x100;
 sreg=0;
 dpreg=0;
 iflag=0;
 /* raw disables SIGINT, brkint reenables it ...
  */
#if defined(TERM_CONTROL) && ! defined(TRACE)
  /* raw, but still allow key signaling, especial if ^C is desired
     - if not, remove brkint and isig!
   */
  system("stty -echo nl raw brkint isig");
  tflags=fcntl(0,F_GETFL,0);
  fcntl(0,F_SETFL,tflags|O_NDELAY);
#endif

#ifdef TRACE
 da_len = 0;
#endif
 cycles_sum = 0;
 pcreg_prev = pcreg;

 for(;;){

  ireg=mem[pcreg++];
  cycles=0;
  (*instrtable[ireg])();                /* process instruction */
  cycles_sum += cycles;

#ifdef TRACE
  trace();
#endif

  pcreg_prev = pcreg;

 } /* for */
}



void finish()
{
 cr();
 fprintf(stderr,"Cycles: %lu", cycles_sum);
 cr();
#if defined(TERM_CONTROL) && ! defined(TRACE)
 system("stty -raw -nl echo brkint");
 fcntl(0,F_SETFL,tflags&~O_NDELAY);
#endif
 if (fdump) dump();
 exit(0);
}
