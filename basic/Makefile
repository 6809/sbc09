#
# Makefile examples SBC09/Sim6809
#
# created 1994 by L.C. Benschop
# 2014-06-25 - J.E. Klasek
#
# copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
# license: GNU General Public License version 2, see LICENSE for more details.
#

ASM=../a09

PROGS=basic fbasic

OTHER=floatnum.inc makeflot


all: $(ASM) $(PROGS)

$(ASM):
	$(MAKE) -c ../src a09 install

# ------------------------------------
# rules

.SUFFIXES: .asm

.asm:
	$(ASM) -l $@.lst  $<

# ------------------------------------

basic: basic.asm


fbasic: fbasic.asm floatnum.inc
	$(ASM) -l $@.lst fbasic.asm

floatnum.inc: floatnum.src makeflot
	./makeflot < floatnum.src > floatnum.inc

makeflot: makeflot.c


# ------------------------------------

cleanall: clean
	rm -f $(PROGS) $(OTHER)

clean:
	rm -f core *.BAK *.lst $(PROGS)

