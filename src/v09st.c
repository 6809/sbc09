/* 6809 Simulator V09,
   By L.C. Benschop, Eidnhoven The Netherlands.
   This program is in the public domain.
   
   *** TURBO C VERSION ****   
 
   This program simulates a 6809 processor.

   System dependencies: short must be 16 bits.
                        char  must be 8 bits.
                        long must be more than 16 bits.
                        arrays up to 65536 bytes must be supported.
                        machine must be twos complement.
   Most Unix machines will work. For MSODS you need long pointers
   and you may have to malloc() the mem array of 65536 bytes.

   Define BIG_ENDIAN if you have a big-endian machine (680x0 etc)

   Define TRACE if you want an instruction trace on stderr.
   Define TERM_CONTROL for raw, nonblocking IO.    

   Special instructions:
   SWI2 writes char to stdout from register B.
   SWI3 reads char from stdout to register B, sets carry at EOF.
               (or when no key available when using TERM Control).
   SWI retains its normal function.
   CWAI and SYNC stop simulator.

   The program reads a binary image file at $100 and runs it from there.
   The file name must be given on the command line.
*/

#include <stdio.h>
#include <alloc.h>
#ifdef TERM_CONTROL
#include <conio.h>
#endif

typedef unsigned char Byte;
typedef unsigned short Word;

/* 6809 registers */
Byte ccreg,dpreg;
Word xreg,yreg,ureg,sreg,ureg,pcreg;

Byte d_reg[2];
Word *dreg=(Word *)d_reg;
#ifdef BIG_ENDIAN /* This is a dirty aliasing trick, but fast! */
 Byte *areg=d_reg;
 Byte *breg=d_reg+1;
#else
 Byte *breg=d_reg;
 Byte *areg=d_reg+1;
#endif

/* 6809 memory space */
Byte *mem;

#define GETWORD(a) (mem[a]<<8|mem[(a)+1])
#define SETWORD(a,n) {mem[a]=(n)>>8;mem[(a)+1]=n;}
/* Two bytes of a word are fetched separately because of
   the possible wrap-around at address $ffff and alignment
*/   


int iflag; /* flag to indicate prebyte $10 or $11 */
Byte ireg; /* Instruction register */

#define IMMBYTE(b) b=mem[pcreg++];
#define IMMWORD(w) {w=GETWORD(pcreg);pcreg+=2;}

#define PUSHBYTE(b) mem[--sreg]=b;
#define PUSHWORD(w) {sreg-=2;SETWORD(sreg,w)}
#define PULLBYTE(b) b=mem[sreg++];
#define PULLWORD(w) {w=GETWORD(sreg);sreg+=2;}

#define SIGNED(b) ((Word)(b&0x80?b|0xff00:b))

Word *ixregs[]={&xreg,&yreg,&ureg,&sreg};

int index;

/* Now follow the posbyte addressing modes. */

Word illaddr() /* illegal addressing mode, defaults to zero */
{
 return 0;
}

Word ainc()
{
 return (*ixregs[index])++;
}

Word ainc2()
{
 Word temp;
 temp=(*ixregs[index]);
 (*ixregs[index])+=2;
 return(temp);
}

Word adec()
{
 return --(*ixregs[index]);
}

Word adec2()
{
 Word temp;
 (*ixregs[index])-=2;
 temp=(*ixregs[index]);
 return(temp);
}

Word plus0()
{
 return(*ixregs[index]);
}

Word plusa()
{
 return(*ixregs[index])+SIGNED(*areg);
}

Word plusb()
{
 return(*ixregs[index])+SIGNED(*breg);
}

Word plusn()
{
 Byte b;
 IMMBYTE(b)
 return(*ixregs[index])+SIGNED(b);
}

Word plusnn()
{
 Word w;
 IMMWORD(w)
 return(*ixregs[index])+w;
}
 
Word plusd()
{
 return(*ixregs[index])+*dreg;
}


Word npcr()
{
 Byte b;
 IMMBYTE(b)
 return pcreg+SIGNED(b);
}

Word nnpcr()
{
 Word w;
 IMMWORD(w)
 return pcreg+w;
}            

Word direct()
{
 Word(w);
 IMMWORD(w)
 return w;
}

Word zeropage()
{ 
 Byte b;
 IMMBYTE(b)
 return dpreg<<8|b;
}


Word immediate()
{
 return pcreg++;
}

Word immediate2()
{
 Word temp;
 temp=pcreg;
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
 IMMBYTE(pb)
 index=(pb & 0x60) >> 5;
 if(pb & 0x80) {
  temp=(*pbtable[pb & 0x0f])();
  if( pb & 0x10) temp=GETWORD(temp);
  return temp;
 } else {
  temp=pb & 0x1f;
  if(temp & 0x10) temp|=0xfff0;
  return (*ixregs[index])+temp;
 }
}

Byte * eaddr0() /* effective address for NEG..JMP as byte poitner */
{
 switch( (ireg & 0x70) >> 4)
 {
  case 0: return mem+zeropage();
  case 1:case 2:case 3: return 0; /*canthappen*/
  case 4: return areg;
  case 5: return breg;
  case 6: return mem+postbyte();
  case 7: return mem+direct(); 
 }
} 

Word eaddr8()  /* effective address for 8-bits ops. */
{
 switch( (ireg & 0x30) >> 4)
 {
  case 0: return immediate();
  case 1: return zeropage();
  case 2: return postbyte();
  case 3: return direct();
 }
}

Word eaddr16() /* effective address for 16-bits ops. */
{
 switch( (ireg & 0x30) >> 4)
 {
  case 0: return immediate2();
  case 1: return zeropage();
  case 2: return postbyte();
  case 3: return direct();
 }
}
  
ill() /* illegal opcode==noop */ 
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

#define SETSTATUS(a,b,res) if((a^b^res)&0x10) SEH else CLH \
                           if((a^b^res^(res>>1))&0x80)SEV else CLV \
                           if(res&0x100)SEC else CLC SETNZ8((Byte)res) 
                           
add()
{
 Word aop,bop,res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];                           
 res=aop+bop;
 SETSTATUS(aop,bop,res)
 *aaop=res;
} 

sbc()
{
 Word aop,bop,res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];                           
 res=aop-bop-(ccreg&0x01);
 SETSTATUS(aop,bop,res)
 *aaop=res;
} 

sub()
{
 Word aop,bop,res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];                           
 res=aop-bop;
 SETSTATUS(aop,bop,res)
 *aaop=res;
} 

adc()
{
 Word aop,bop,res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];
 res=aop+bop+(ccreg&0x01);
 SETSTATUS(aop,bop,res)
 *aaop=res;
} 

cmp()
{
 Word aop,bop,res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];                           
 res=aop-bop;
 SETSTATUS(aop,bop,res)
} 

and()
{
 Byte aop,bop,res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];                           
 res=aop&bop;
 SETNZ8(res)
 CLV
 *aaop=res;
} 

or()
{
 Byte aop,bop,res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];                           
 res=aop|bop;
 SETNZ8(res)
 CLV
 *aaop=res;
} 

eor()
{
 Byte aop,bop,res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];                           
 res=aop^bop;
 SETNZ8(res)
 CLV
 *aaop=res;
} 

bit()
{
 Byte aop,bop,res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 aop=*aaop;
 bop=mem[eaddr8()];                           
 res=aop&bop;
 SETNZ8(res)
 CLV
} 

ld()
{
 Byte res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 res=mem[eaddr8()];                           
 SETNZ8(res)
 CLV
 *aaop=res;
}

st()
{
 Byte res;
 Byte* aaop;
 aaop=(ireg&0x40)?breg:areg;
 res=*aaop;
 mem[eaddr8()]=res;                           
 SETNZ8(res)
 CLV
} 

jsr()
{
 Word w;
 w=eaddr8();
 PUSHWORD(pcreg)
 pcreg=w;
}

bsr()
{
 Byte b;
 IMMBYTE(b)
 PUSHWORD(pcreg)
 pcreg+=SIGNED(b); 
}

neg()
{
 Byte *ea;
 Word a,r;
 a=0;
 ea=eaddr0();
 a=*ea;
 r=-a;
 SETSTATUS(0,a,r)
 *ea=r;
}

com()
{
 Byte *ea;
 Byte r;
 ea=eaddr0();
 r=0^*ea;
 SETNZ8(r)
 SEC CLV
 *ea=r;
}

lsr()
{
 Byte *ea;
 Byte r;
 ea=eaddr0();
 r=*ea;
 if(r&0x01)SEC else CLC
 r>>=1;
 SETNZ8(r)
 *ea=r;
}

ror()
{
 Byte *ea;
 Byte r,c;
 c=(ccreg&0x01)<<7;
 ea=eaddr0();
 r=*ea;
 if(r&0x01)SEC else CLC
 r=(r>>1)+c;
 SETNZ8(r)
 *ea=r;
}

asr()
{
 Byte *ea;
 Byte r;
 ea=eaddr0();
 r=*ea;
 if(r&0x01)SEC else CLC
 r>>=1;
 if(r&0x40)r|=0x80;
 SETNZ8(r)
 *ea=r;
}

asl()
{
 Byte *ea;
 Word a,r;
 ea=eaddr0();
 a=*ea;
 r=a<<1;
 SETSTATUS(a,a,r) 
 *ea=r;
}

rol()
{
 Byte *ea;
 Byte r,c;
 c=(ccreg&0x01);
 ea=eaddr0();
 r=*ea;
 if(r&0x80)SEC else CLC 
 r=(r<<1)+c; 
 SETNZ8(r)
 *ea=r;
}

inc()
{
 Byte *ea;
 Byte r;
 ea=eaddr0();
 r=*ea;
 r++;
 if(r==0x80)SEV else CLV
 SETNZ8(r)
 *ea=r;
}

dec()
{
 Byte *ea;
 Byte r;
 ea=eaddr0();
 r=*ea;
 r--;
 if(r==0x7f)SEV else CLV
 SETNZ8(r)
 *ea=r;
}

tst()
{
 Byte r;
 r=*eaddr0();
 SETNZ8(r)
 CLV
}

jmp()
{
 Byte *ea;
 ea=eaddr0();
 pcreg=ea-mem;
}

clr()
{
 Byte *ea;
 ea=eaddr0();
 *ea=0;CLN CLV SEZ CLC
}

extern (*instrtable[])();

flag0()
{
 if(iflag) /* in case flag already set by previous flag instr don't recurse */
 {
  pcreg--;
  return; 
 }
 iflag=1;
 ireg=mem[pcreg++];
 (*instrtable[ireg])();
 iflag=0;
}

flag1()
{
 if(iflag) /* in case flag already set by previous flag instr don't recurse */
 {
  pcreg--;
  return; 
 }
 iflag=2;
 ireg=mem[pcreg++];
 (*instrtable[ireg])();
 iflag=0;
}

nop()
{
}

sync()
{
 exit(0);
}

cwai()
{
 sync();
}

lbra()
{
 Word w;
 IMMWORD(w)
 pcreg+=w;
}

lbsr()
{
 Word w;
 IMMWORD(w)
 PUSHWORD(pcreg)
 pcreg+=w;
}

daa()
{
 Word a;
 a=*areg;
 if(ccreg&0x20)a+=6;
 if((a&0x0f)>9)a+=6;
 if(ccreg&0x01)a+=0x60;
 if((a&0xf0)>0x90)a+=0x60;
 if(a&0x100)SEC else CLC
 *areg=a;
}

orcc()
{
 Byte b; 
 IMMBYTE(b)
 ccreg|=b;
}

andcc()
{
 Byte b; 
 IMMBYTE(b)
 ccreg&=b;
}

mul()
{
 Word w;
 w=*areg * *breg;
 if(w)CLZ else SEZ
 if(w&0xff00) SEC else CLC
 *dreg=w;
}

sex()
{
 Word w;
 w=SIGNED(*breg);
 SETNZ16(w)
 *dreg=w;
}

abx()
{
 xreg += *breg;
}

rts()
{
 PULLWORD(pcreg)
}

rti()
{
 Byte x;
 x=ccreg&0x80;
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

swi()
{
 int w;
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
#ifndef TERM_CONTROL  
   w=getchar();
   if(w==EOF)SEC else CLC
#else
   if(kbhit()) {
     w=getch();
     CLC
   } else {
     w=255;
     SEC
   }
#endif   
   *breg=w;
 }
}
    
Word *wordregs[]={(Word*)d_reg,&xreg,&yreg,&ureg,&sreg,&pcreg,&sreg,&pcreg};
#ifdef BIG_ENDIAN
Byte *byteregs[]={d_reg,d_reg+1,&ccreg,&dpreg};
#else
Byte *byteregs[]={d_reg+1,d_reg,&ccreg,&dpreg};
#endif

tfr()
{
 Byte b;
 IMMBYTE(b)
 if(b&0x80) { 
  *byteregs[b&0x03]=*byteregs[(b&0x30)>>4];
 } else {
  *wordregs[b&0x07]=*wordregs[(b&0x70)>>4];
 }
}

exg()
{
 Byte b;
 Word w;
 IMMBYTE(b)
 if(b&0x80) {
  w=*byteregs[b&0x03]; 
  *byteregs[b&0x03]=*byteregs[(b&0x30)>>4];
  *byteregs[(b&0x30)>>4]=w;
 } else {
  w=*wordregs[b&0x07];
  *wordregs[b&0x07]=*wordregs[(b&0x70)>>4];
  *wordregs[(b&0x70)>>4]=w;
 } 
}

br(int f)
{
 Byte b;
 Word w;
 if(!iflag) {
  IMMBYTE(b)
  if(f) pcreg+=SIGNED(b);
 } else {
  IMMWORD(w)
  if(f) pcreg+=w;
 }
}   

#define NXORV  ((ccreg&0x08)^(ccreg&0x02))

bra()
{ 
 br(1);
}

brn()
{
 br(0);
}

bhi()
{
 br(!(ccreg&0x05));
}

bls()
{
 br(ccreg&0x05);
}

bcc()
{
 br(!(ccreg&0x01));
}

bcs()
{
 br(ccreg&0x01);
}

bne()
{
 br(!(ccreg&0x04));
}

beq()
{
 br(ccreg&0x04);
}

bvc()
{
 br(!(ccreg&0x02));
}

bvs()
{
 br(ccreg&0x02);
}

bpl()
{
 br(!(ccreg&0x08));
}

bmi()
{
 br(ccreg&0x08);
}

bge()
{
 br(!NXORV);
}

blt()
{
 br(NXORV);
} 

bgt()
{
 br(!(NXORV||ccreg&0x04));
}

ble()
{
 br(NXORV||ccreg&0x04);
}   

leax()
{
 Word w;
 w=postbyte();
 if(w) CLZ else SEZ
 xreg=w;
}

leay()
{
 Word w;
 w=postbyte();
 if(w) CLZ else SEZ
 yreg=w;
}

leau()
{
 ureg=postbyte();
}

leas()
{
 sreg=postbyte();
}

#define SWAPUS {temp=sreg;sreg=ureg;ureg=temp;}

pshs()
{
 Byte b;
 IMMBYTE(b)
 if(b&0x80)PUSHWORD(pcreg)
 if(b&0x40)PUSHWORD(ureg)
 if(b&0x20)PUSHWORD(yreg)
 if(b&0x10)PUSHWORD(xreg)
 if(b&0x08)PUSHBYTE(dpreg)
 if(b&0x04)PUSHBYTE(*breg)
 if(b&0x02)PUSHBYTE(*areg)
 if(b&0x01)PUSHBYTE(ccreg)
}

puls()
{
 Byte b;
 IMMBYTE(b)
 if(b&0x01)PULLBYTE(ccreg)
 if(b&0x02)PULLBYTE(*areg)
 if(b&0x04)PULLBYTE(*breg)
 if(b&0x08)PULLBYTE(dpreg)
 if(b&0x10)PULLWORD(xreg)
 if(b&0x20)PULLWORD(yreg)
 if(b&0x40)PULLWORD(ureg)
 if(b&0x80)PULLWORD(pcreg)
}

pshu()
{
 Word temp;
 SWAPUS
 pshs();
 SWAPUS
}

pulu()
{
 Word temp;
 SWAPUS
 puls();
 SWAPUS
}

#define SETSTATUSD(a,b,res) {if((res&0x10000l)!=0) SEC else CLC \
                            if((((res>>1)^a^b^res)&0x8000l)!=0) SEV else CLV \
                            SETNZ16((Word)res)}

addd()
{
 unsigned long aop,bop,res;
 Word ea;
 aop=*dreg&0xffff;
 ea=eaddr16();
 bop=GETWORD(ea)&0xffff;
 res=aop+bop;
 SETSTATUSD(aop,bop,res)
 *dreg=res;
}

subd()
{
 unsigned long aop,bop,res;
 Word ea;
 if(iflag==2)aop=ureg; else aop=*dreg;
 aop&=0xffff;
 ea=eaddr16();
 bop=GETWORD(ea)&0xffff;
 res=aop-bop;
 SETSTATUSD(aop,bop,res)
 if(iflag==0) *dreg=res; 
}

cmpx()
{
 unsigned long aop,bop,res;
 Word ea;
 switch(iflag) {
  case 0: aop=xreg;break;
  case 1: aop=yreg;break;
  case 2: aop=sreg;
 }
 aop&=0xffff;
 ea=eaddr16();
 bop=GETWORD(ea)&0xffff;
 res=aop-bop;
 SETSTATUSD(aop,bop,res)
}

ldd()
{
 Word ea,w;
 ea=eaddr16();
 w=GETWORD(ea);
 SETNZ16(w)
 *dreg=w;
}

ldx()
{
 Word ea,w;
 ea=eaddr16();
 w=GETWORD(ea);
 SETNZ16(w)
 if (iflag==0) xreg=w; else yreg=w;
}

ldu()
{
 Word ea,w;
 ea=eaddr16();
 w=GETWORD(ea);
 SETNZ16(w)
 if (iflag==0) ureg=w; else sreg=w;
}

std()
{
 Word ea,w;
 ea=eaddr16();
 w=*dreg;
 SETNZ16(w)
 SETWORD(ea,w)
}

stx()
{
 Word ea,w;
 ea=eaddr16();
 if (iflag==0) w=xreg; else w=yreg;
 SETNZ16(w)
 SETWORD(ea,w)
}

stu()
{
 Word ea,w;
 ea=eaddr16();
 if (iflag==0) w=ureg; else w=sreg;
 SETNZ16(w)
 SETWORD(ea,w)
}

int (*instrtable[])() = {
 neg , ill , ill , com , lsr , ill , ror , asr ,
 asl , rol , dec , ill , inc , tst , jmp , clr ,
 flag0 , flag1 , nop , sync , ill , ill , lbra , lbsr ,
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

read_image(char* name)
{
 FILE *image;
 if((image=fopen(name,"rb"))!=NULL) {
  fread(mem+0x100,0xff00,1,image);
  fclose(image);
 }
}

main(int argc,char *argv[])
{
 mem=farmalloc(65536);
 read_image(argv[1]);
 pcreg=0x100;
 sreg=0;
 dpreg=0;
 iflag=0;
 for(;;){
  #ifdef TRACE
   fprintf(stderr,"pc=%04x ",pcreg);
  #endif
  ireg=mem[pcreg++];
  #ifdef TRACE
   fprintf(stderr,"i=%02x ",ireg);
   if((ireg&0xfe)==0x10)
    fprintf(stderr,"%02x ",mem[pcreg]);else fprintf(stderr,"   ");
     fprintf(stderr,"x=%04x y=%04x u=%04x s=%04x a=%02x b=%02x cc=%02x\n",
                   xreg,yreg,ureg,sreg,*areg,*breg,ccreg);
  #endif
  (*instrtable[ireg])();
 }
}

