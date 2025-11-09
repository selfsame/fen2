CC = gcc
CFLAGS = -g -Wall -Wextra -fsanitize=address
LDFLAGS = -lSDL3 -llua -lm

SRC = src/main.c src/keys.c
OBJ = $(SRC:.c=.o)

fen2: $(OBJ)
	$(CC) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f fen2 $(OBJ)

.PHONY: clean
