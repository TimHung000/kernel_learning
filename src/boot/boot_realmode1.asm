ORG 0
BITS 16

; check https://wiki.osdev.org/FAT
; BPB(BIOS Parameter Block)
_start:
    jmp short start
    nop
; 33 bytes for BIOS Parameter Block
times 33 db 0

start:
    jmp 0x7c0:step2

step2:
    cli ; Clear Interrupts
    mov ax, 0x7c0
    mov ds, ax
    mov es, ax
    mov ax, 0x00
    mov ss, ax
    mov sp, 0x7c00
    sti ; Enables Interrups
    
    ;interrupt list (https://www.ctyme.com/intr/int-13.htm)
    ;Int 13/AH=02h - DISK - READ SECTOR(S) INTO MEMORY
    mov ah, 2 ; READ SECTOR COMMAND
    mov al, 1 ; ONE SECTOR TO READ
    mov ch, 0 ; Cylinder low eight bits
    mov cl, 2 ; Read sector two
    mov dh, 0 ; Head number
    mov bx, buffer
    int 0x13
    jc error

    mov si, buffer
    call print
    jmp $

error:
    mov si, erro_message
    call print
    jmp $

print:
    mov bx, 0
.loop:
    lodsb
    cmp al, 0
    je .done
    call print_char
    jmp .loop
.done:
    ret

print_char:
    mov ah, 0eh
    int 10h
    ret

erro_message: db 'Failed to load sector', 0

times 510-($ - $$) db 0
dw 0xAA55

buffer: