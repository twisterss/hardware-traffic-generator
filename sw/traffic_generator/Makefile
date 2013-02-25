include Makefile.conf

FLAGS=$(CFLAGS) $(LIBSZE2_CFLAGS) $(LIBSZE2_LIBS) $(LIBCOMBO_LIBS)

all: traffic_generator

traffic_generator: traffic_generator.c traffic_generator.h
	$(CC) $(FLAGS) $< ../../../../netfpga-1g/NF2/projects/svm_classifier/sw/watch/flow_manager.c -o $@

.PHONY: clean
clean:
	rm -rf *.o traffic_generator
