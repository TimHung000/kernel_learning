ORG 0x7c00
BITS 16
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; check https://wiki.osdev.org/FAT
; BPB(BIOS Parameter Block)
jmp short start
nop


; FAT16 Header
OEMIdentifier           db 'PEACHOS ' ; 8 bytes
BytesPerSector          dw 0x200
SectorsPerCluster       db 0x80
ReservedSectors         dw 200
FATCopies               db 0x02
RootDirEntries          dw 0x40
NumSectors              dw 0x00
MediaType               db 0xF8
SectorsPerFat           dw 0x100
SectorsPerTrack         dw 0x20
NumberOfHeads           dw 0x40
HiddenSectors           dd 0x00
SectorBig               dd 0x773594

; Extended BPB (Dos 4.0)
DriveNumber             db 0x80
WinNTBit                db 0x00
Signature               db 0x29
VolumeID                dd 0xD105
VolumeIDString          db 'PEACHOS BOO' ; 11 bytes
SystemIDString          db 'FAT16   '



start:
    jmp 0:step2
step2:
    cli ; Clear Interrupts
    mov ax, 0x00
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti ; Enables Interrupts
.load_protected:
    cli
    lgdt[gdt_descriptor]
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    jmp CODE_SEG:load32


; GDT(Global Descriptor Table)
; https://wiki.osdev.org/GDT_Tutorial
; https://wiki.osdev.org/Global_Descriptor_Table
gdt_start:
gdt_null:
    dd 0x0 ; 32 bits 0
    dd 0x0 ; 32 bits 0 

; offset 0x8
gdt_code:     ; CS should point to this
    dw 0xffff ; Segment limit first 0-16 bits
    dw 0      ; Base first 0-15 bits
    db 0      ; Base 16-23 bits
    db 0x9a   ; Access byte
    db 11001111b ; High 4 bit flags and the low 4 bit flags
    db 0      ; Base 24-31

; offset 0x10
gdt_data:     ; DS, SS, ES, FS, GS
    dw 0xffff ; Segment limit first 0-16 bits
    dw 0      ; Base first 0-15 bits
    db 0      ; Base 16-23 bits
    db 0x92   ; Access byte
    db 11001111b ; High 4 bit flags and the low 4 bit flags
    db 0      ; Base 24-31

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start
 
 [BITS 32]
 load32:
    mov eax, 1 ; starting sector (0 is boot sector)
    mov ecx, 100 ; total number of sector we want to load
    mov edi, 0x0100000 ; 1M, the address that we want to load them into
    call ata_lba_read
    jmp CODE_SEG:0x0100000

; ATA (Advanced Technology Attachment) is a standard interface for connecting storage devices to computers
; https://wiki.osdev.org/ATA_PIO_Mode
; https://wiki.osdev.org/ATA_read/write_sectors
; storage driver
ata_lba_read:
    mov ebx, eax, ; Backup the LBA
    ; Send the highest 8 bits of the lba to hard disk controller
    shr eax, 24
    or eax, 0xE0 ; Select the  master drive
    mov dx, 0x1F6
    out dx, al
    ; Finished sending the highest 8 bits of the lba

    ; Send the total sectors to read
    mov eax, ecx
    mov dx, 0x1F2
    out dx, al
    ; Finished sending the total sectors to read

    ; Send more bits of the LBA
    mov eax, ebx ; Restore the backup LBA
    mov dx, 0x1F3
    out dx, al
    ; Finished sending more bits of the LBA

    ; Send more bits of the LBA
    mov dx, 0x1F4
    mov eax, ebx ; Restore the backup LBA
    shr eax, 8
    out dx, al
    ; Finished sending more bits of the LBA

    ; Send upper 16 bits of the LBA
    mov dx, 0x1F5
    mov eax, ebx ; Restore the backup LBA
    shr eax, 16
    out dx, al
    ; Finished sending upper 16 bits of the LBA

    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

    ; Read all sectors into memory
.next_sector:
    push ecx

;Checking if we need to read
.try_again:
    mov dx, 0x1f7
    in al, dx
    test al, 8
    jz .try_again ; test failed

; We need to read 256 words at a time
    mov ecx, 256
    mov dx, 0x1F0
    rep insw ; INSW : Input word from I/) port specified in DX into memory location specified with ES:(E)DI
    pop ecx
    loop .next_sector
    ; End of reading sectors into memory
    ret


times 510-($ - $$) db 0
dw 0xAA55