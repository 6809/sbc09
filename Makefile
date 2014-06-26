#
# Makefile Sim6809
#
# created 1994 by L.C. Benschop
# 2013-10-28 - Jens Diemer: add "clean" section
# 2014-06-25 - J.E. Klasek
#
# copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
# license: GNU General Public License version 2, see LICENSE for more details.
#

ASM=a09
CFLAGS=-O3 -fomit-frame-pointer -DTERM_CONTROL

all: v09 v09t ef09 uslash crc16 crc32 input printval erat-sieve

v09: v09.c

v09t: v09.c
	$(CC) $(CFLAGS) -DTRACE -o $@ $<

a09: a09.c


# ------------------------------------

bench09: bench09.asm $(ASM)
	$(ASM) $<

test09: test09.asm $(ASM)
	$(ASM) $<

input: input.asm $(ASM)
	$(ASM) $<

uslash: uslash.asm $(ASM)
	$(ASM) -l $@.lst  $<

crc16: crc16.asm $(ASM)
	$(ASM) -l $@.lst  $<

crc32: crc32.asm $(ASM)
	$(ASM) -l $@.lst  $<

ef09: ef09.asm $(ASM)
	$(ASM) -l $@.lst  $<

printval: printval.asm $(ASM)
	$(ASM) -l $@.lst  $<

erat-sieve: erat-sieve.asm
	$(ASM) -l $@.lst  $<

# ------------------------------------

cleanall: clean
	rm -f v09 $(ASM) bench09 test09 ef09

clean:
	rm -f core *.BAK

archive: clean
	@(cd ..; \
	tar cvfz sim6809.tgz sim6809 )

# ------------------------------------

DIST=sim6809-jk-edition
FILES=ef09.asm bench09.asm test09.asm printval.asm uslash.asm crc32.asm erat-sieve.asm input.asm crc16.asm $(ASM).c v09.c v09tc.c README info.txt erat-sieve.txt $(ASM) v09 v09t

dist:
	mkdir -p $(DIST)
	cp -p $(FILES) $(DIST)/.
	cp -p Makefile.dist $(DIST)/Makefile
	cp -p info.en.txt $(DIST)/info.txt
	tar cvfz $(DIST).tgz $(DIST)
	rm -rf $(DIST)

