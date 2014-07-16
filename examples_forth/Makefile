#
# Makefile examples_forth SBC09/Sim6809
#
# created 1994 by L.C. Benschop
# 2013-10-28 - Jens Diemer: add "clean" section
# 2014-07-16 - J.E. Klasek
#
# copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
# license: GNU General Public License version 2, see LICENSE for more details.
#

ASM=../a09

PROGS=forthload.s



all: $(ASM) $(PROGS)

$(ASM):
	$(MAKE) -c ../src a09 install


# ------------------------------------
# rules

.SUFFIXES: .asm .s

.asm.s:
	$(ASM) -s $@  $<

#
# ------------------------------------

forthload.s: forthload.asm


# ------------------------------------

cleanall: clean

clean:
	rm -f core *.BAK *.lst $(PROGS)

