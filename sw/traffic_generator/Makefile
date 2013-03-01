include Makefile.conf

FLAGS=$(CFLAGS) $(LIBSZE2_CFLAGS) $(LIBSZE2_LIBS) $(LIBCOMBO_LIBS)

all: traffic_generator

traffic_generator: traffic_generator.c traffic_generator.h
	$(CC) $(FLAGS) $< -o $@

.PHONY: clean
clean:
	rm -rf *.o traffic_generator
