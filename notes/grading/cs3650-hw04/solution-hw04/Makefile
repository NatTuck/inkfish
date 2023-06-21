
CFLAGS := -g
LDLIBS := -lbsd

all: length-sort top-triples

length-sort: length-sort.o svec.o
	gcc $(CFLAGS) -o $@ $^ $(LDLIBS)

length-sort.o: length-sort.c svec.h
	gcc $(CFLAGS) -c -o $@ $<

svec.o: svec.c svec.h
	gcc $(CFLAGS) -c -o $@ $<

top-triples: top-triples.o hashmap.o
	gcc $(CFLAGS) -o $@ $^ $(LDLIBS)

top-triples.o: top-triples.c hashmap.h
	gcc $(CFLAGS) -c -o $@ $<

hashmap.o: hashmap.c hashmap.h
	gcc $(CFLAGS) -c -o $@ $<

clean:
	rm -f *.o length-sort top-triples valgrind.out *.plist

.PHONY: all clean
