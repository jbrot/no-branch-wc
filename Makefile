all: no-branch-wc

no-branch-wc: wc.o
	ld -lSystem -o no-branch-wc wc.o

wc.o: wc.asm
	nasm -fmacho64 wc.asm

clean:
	rm -f *.o
	rm -f no-branch-wc
