CC ?= cc
CFLAGS = -std=c99 -Wall -Wextra -O2 -Isrc

DOMAIN = src/protocol.c src/observation.c src/decide.c

slimes: $(DOMAIN) src/transport.c src/main.c
	$(CC) $(CFLAGS) -o $@ $(DOMAIN) src/transport.c src/main.c

test_protocol: test/test_protocol.c $(DOMAIN)
	$(CC) $(CFLAGS) -o $@ test/test_protocol.c $(DOMAIN)

test_decide: test/test_decide.c $(DOMAIN)
	$(CC) $(CFLAGS) -o $@ test/test_decide.c $(DOMAIN)

test: test_protocol test_decide
	@./test_protocol; p=$$?; ./test_decide; d=$$?; \
	if [ $$((p + d)) -ne 0 ]; then exit 1; fi

clean:
	rm -f slimes test_protocol test_decide

.PHONY: test clean
