#
# Makefile examples SBC09/Sim6809
#
# created 1994 by L.C. Benschop
# 2013-10-28 - Jens Diemer: add "clean" section
# 2014-06-25 - J.E. Klasek
#
# copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
# license: GNU General Public License version 2, see LICENSE for more details.
#

ASM=../a09

EXAMPLES=basic bench09 bin2dec cond09 crc16 crc32 ef09 erat-sieve printval test09 uslash



all: $(ASM) $(EXAMPLES)

$(ASM):
	$(MAKE) -c ../src a09 install

# ------------------------------------
# rules

.SUFFIXES: .asm

.asm:
	$(ASM) -l $@.lst  $<

# ------------------------------------

basic: basic.asm

bench09: bench09.asm

bin2dec: bin2dec.asm

cond09: cond09.asm

crc16: crc16.asm

crc32: crc32.asm

ef09: ef09.asm

erat-sieve: erat-sieve.asm

printval: printval.asm

input: input.asm

test09: test09.asm

uslash: uslash.asm



# ------------------------------------

cleanall: clean

clean:
	rm -f core *.BAK *.lst $(EXAMPLES)

