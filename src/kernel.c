#include "kernel.h"
#include <stdint.h>
#include <stddef.h>
#include "idt/idt.h"
#include "io/io.h"
#include "memory/heap/kheap.h"
#include "memory/paging/paging.h"
#include "string/string.h"
#include "fs/file.h"
#include "disk/disk.h"
#include "fs/pparser.h"
#include "disk/streamer.h"


uint16_t* video_mem = 0;
uint16_t terminal_row = 0;
uint16_t terminal_col = 0;

uint16_t terminal_make_char(char c, char colour) {
    return (colour << 8) | c;
}

void terminal_putchar(int x, int y, char c, char colour) {
    video_mem[(y * VGA_WIDTH) +x] = terminal_make_char(c, colour);
}

void terminal_writechar(char c, char colour) {
    if (c == '\n') {
        terminal_row++;
        terminal_col = 0;
        return;
    }
    terminal_putchar(terminal_col, terminal_row, c, colour);
    terminal_col++;
    if (terminal_col >= VGA_WIDTH) {
        terminal_col = 0;
        terminal_row++;
    }
}

void terminal_initialize() {
    video_mem = (uint16_t*)(0xB8000);
    for (int y = 0; y < VGA_HEIGHT; y++) {
        for (int x = 0; x < VGA_WIDTH; x++) {
            terminal_putchar(x, y, ' ', 0);
        }
    }
}

void print(const char* str) {
    size_t len = strlen(str);
    for (int i = 0; i < len; i++)
        terminal_writechar(str[i], 15);
}


static struct paging_4gb_chunk* kernel_chunk = 0;
void kernel_main() {
    // char* video_mem = (char*)(0xB8000);
    // video_mem[0] = 'A';
    // video_mem[1] = 3;
    terminal_initialize();
    print("Hello world!\ntest");

    // Initialize the heap
    kheap_init();

    // Initialize filesystems
    fs_init();

    // Search and initialize the disks
    disk_search_and_init();

    // Initialize the interrupt descriptor table
    idt_init();

    // Setup paging
    kernel_chunk = paging_new_4gb(PAGING_IS_WRITABLE | PAGING_IS_PRESENT | PAGING_ACCESS_FROM_ALL);

    // Switch to kernel paging chunk
    paging_switch(paging_4gb_chunk_get_directory(kernel_chunk));

    // Enable paging
    enable_paging();
    
    // Enable the system interrupts
    enable_interrupts();

    int fd = fopen("0:/hello.txt", "r");
    if (fd) {
        struct file_stat s;
        fstat(fd, &s);
        fclose(fd);
        print("testing\n");
    }

    while(1) {}

}