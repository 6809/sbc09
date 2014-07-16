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

V09FLAGS= -DUSE_TERMIOS #-DBIG_ENDIAN


SIM_BIN=v09s v09st 

APPS=mon2.s

# will be installed to ".."
BIN=a09 v09 $(SIM_BIN) v09.rom

TARGETS=$(BIN) $(APPS)

OTHER=monitor.s makerom

all: $(TARGETS)

# ------------------------------------

a09: a09.c

v09: v09.o engine.o io.o
	$(CC) -o v09 $(CFLAGS) v09.o engine.o io.o

v09.o: v09.c v09.h
	$(CC) -c $(CFLAGS) $(V09FLAGS) v09.c

engine.o: engine.c v09.h
	$(CC) -c $(CFLAGS) $(V09FLAGS) engine.c

io.o: io.c v09.h
	$(CC) -c $(CFLAGS) $(V09FLAGS) io.c

v09.rom: makerom monitor.s 
	./makerom <monitor.s

monitor.s: monitor.asm
	./a09 -s monitor.s -l monitor.lst monitor.asm

mon2.s: mon2.asm
	./a09 -s mon2.s -l mon2.lst mon2.asm

makerom: makerom.c
	$(CC) -o makerom makerom.c

# ------------------------------------

v09s: v09s.c

v09st: v09s.c
	$(CC) $(CFLAGS) -DTRACE -o $@ $<

# ------------------------------------

install:
	-for bin in $(BIN); do \
	  [ -r $$bin ] && cp -p $$bin .. && echo "installing ../$$bin ..." ;\
	done ;\
	exit 0

# ------------------------------------

cleanall: clean
	rm -f $(TARGETS) $(OTHER)
	(cd ..; rm -f $(BIN) )

clean:
	rm -f core *.BAK *.o *.lst

# ------------------------------------

