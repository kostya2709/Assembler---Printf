#.PHONY: all clean

FNAME=printf
TEST=test
CFLAGS= -f elf64
LFLAGS= -s -o

all: clean $(FNAME)

$(FNAME): $(FNAME).o
	@ld $(LFLAGS) $(FNAME) $(TEST).o
	@./$(FNAME)

$(FNAME).o:
#	@nasm $(CFLAGS) $(FNAME).asm
	@nasm $(CFLAGS) $(TEST).asm

clean:
	@rm -rf $(FNAME) *.o

cedb: all
	@edb --run $(FNAME)
	@clear

edb:
	@edb --run $(FNAME)
	@clear