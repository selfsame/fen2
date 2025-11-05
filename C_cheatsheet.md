Basic Syntax

```c
#include <stdio.h>  // Standard I/O
#include <stdlib.h> // Standard library
#include <string.h> // String functions

int main() {
    printf("Hello World\n");
    return 0;
}
```

## Data Types

```c
char c = 'A';           // 1 byte
int i = 42;             // 4 bytes  
float f = 3.14f;        // 4 bytes
double d = 3.14159;     // 8 bytes
short s = 100;          // 2 bytes
long l = 1000000L;      // 8 bytes
```

## Pointers

```c
int x = 10;
int *ptr = &x;          // Pointer to x
*ptr = 20;              // Dereference and assign

int arr[5] = {1,2,3,4,5};
int *arr_ptr = arr;     // Array decays to pointer
```

## Memory Management

```c
// Dynamic allocation
int *arr = malloc(10 * sizeof(int));
int *arr2 = calloc(10, sizeof(int)); // Zero-initialized

// Reallocate
arr = realloc(arr, 20 * sizeof(int));

// Free memory
free(arr);
```

## Strings

```c
char str1[] = "Hello";           // Stack allocation
char *str2 = "World";            // Read-only string literal
char str3[20];                   // Buffer

// String functions
strcpy(str3, str1);              // Copy
strcat(str3, " ");               // Concatenate  
strlen(str1);                    // Length
strcmp(str1, str2);              // Compare
```

## Structs

```c
struct Point {
    int x;
    int y;
};

struct Point p1 = {10, 20};
p1.x = 30;

typedef struct {
    char name[50];
    int age;
} Person;

Person p = {"Alice", 25};
```

## Functions

```c
// Function declaration
int add(int a, int b);

// Function definition  
int add(int a, int b) {
    return a + b;
}

// Function pointer
int (*func_ptr)(int, int) = &add;
int result = func_ptr(5, 3);
```

## Control Flow

```c
// If-else
if (x > 0) {
    // do something
} else if (x == 0) {
    // do something else
} else {
    // default
}

// Loops
for (int i = 0; i < 10; i++) {
    printf("%d\n", i);
}

while (condition) {
    // loop body
}

do {
    // loop body
} while (condition);
```

## Arrays

```c
int arr[5] = {1, 2, 3, 4, 5};
int matrix[3][3] = {
    {1, 2, 3},
    {4, 5, 6},
    {7, 8, 9}
};

// Array length
int len = sizeof(arr) / sizeof(arr[0]);
```

## File I/O

```c
FILE *file = fopen("file.txt", "r");
if (file == NULL) {
    perror("Error opening file");
    return 1;
}

char buffer[100];
fgets(buffer, 100, file);  // Read line
fprintf(file, "Writing: %d\n", 42);  // Write formatted

fclose(file);
```

## Common Patterns

```c
// String to number
char *str = "123";
int num = atoi(str);
long lnum = atol(str);
double dnum = atof(str);

// Number to string
char buf[20];
sprintf(buf, "%d", num);

// Command line arguments
int main(int argc, char *argv[]) {
    for (int i = 0; i < argc; i++) {
        printf("Arg %d: %s\n", i, argv[i]);
    }
}
```

## Preprocessor

```c
#define MAX_SIZE 100
#define MIN(a,b) ((a) < (b) ? (a) : (b))

#ifndef HEADER_H
#define HEADER_H
// Header content
#endif
```

## Error Handling

```c
#include <errno.h>

FILE *f = fopen("nonexistent.txt", "r");
if (f == NULL) {
    printf("Error: %s\n", strerror(errno));
    perror("fopen failed");
}
```

## Useful Headers

- `<stdio.h>` - Input/output
- `<stdlib.h>` - Memory allocation, conversion
- `<string.h>` - String manipulation  
- `<math.h>` - Math functions
- `<time.h>` - Time/date functions
- `<ctype.h>` - Character classification
- `<assert.h>` - Debugging assertions

## Compilation

```bash
gcc -o program main.c utils.c  # Compile
gcc -g -o program main.c       # Debug symbols
gcc -Wall -Wextra main.c       # All warnings
```