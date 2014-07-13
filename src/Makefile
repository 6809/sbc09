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

CFLAGS=-O3 -fomit-frame-pointer -DTERM_CONTROL


BIN=a09 v09 v09t 


all: $(BIN)


# ------------------------------------

a09: a09.c

v09: v09.c

v09t: v09.c install
	$(CC) $(CFLAGS) -DTRACE -o $@ $<

# ------------------------------------

install:
	-@for bin in $(BIN); do \
	  [ -r $$bin ] && cp -p $$bin .. && echo "installing ../$$bin ..." ;\
	done ;\
	exit 0

# ------------------------------------

cleanall: clean
	rm -f $(BIN)
	(cd ..; rm -f $(BIN) )

clean:
	rm -f core *.BAK

# ------------------------------------

