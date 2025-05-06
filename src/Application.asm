;
; Main application
;
Application_MAX_SLOTS: equ 8

Application: MACRO
	slotRestore1:
		Slot
	slotRestore2:
		Slot
	cli:
		CLI
	fileInfoBlock:
		FileInfoBlock
	flashDevices:
		REPT Application_MAX_SLOTS
	flashDevice:
		FlashDevice
		ENDM
	flashIterator:
		ArrayIterator Application_MAX_SLOTS
	ENDM

; ix = this
Application_Construct: PROC
	ld hl,Application_messageWelcome
	call System_PrintLn
	call System_PrintCrLf
	ld h,40H
	call Memory_GetSlot
	ld (ix + Application.slotRestore1.id),a
	ld h,80H
	call Memory_GetSlot
	ld (ix + Application.slotRestore2.id),a
	push ix
	call Application_GetCLI
	call CLI_Construct
	pop ix
	push ix
	ld e,ixl
	ld d,ixh
	ld hl,Application.cli.slots
	add hl,de
	ld de,ConstructFlashDevice
	call Application_CreateFlashIterator
	call ArrayIterator_ForEach
	pop ix
	ret
; hl = slots
; ix = flash device
ConstructFlashDevice:
	push hl
	ld a,(hl)
	call FlashDevice_Construct
	pop hl
	inc hl
	ret
	ENDP

; ix = this
Application_Destruct:
	ld h,40H
	ld a,(ix + Application.slotRestore1.id)
	call Memory_SetSlot
	ld h,80H
	ld a,(ix + Application.slotRestore1.id)
	call Memory_SetSlot
	ret

; ix = this
; ix <- CLI
Application_GetCLI:
	ld de,Application.cli
	add ix,de
	ret

; ix = this
; ix <- flash devices
Application_GetFlashDevices:
	ld de,Application.flashDevices
	add ix,de
	ret

; de = function
; ix = this
; ix <- flash iterator
Application_CreateFlashIterator:
	push af
	push bc
	push hl
	ld a,(ix + Application.cli.slotCount)
	ld c,ixl
	ld b,ixh
	ld hl,Application.flashDevices
	add hl,bc
	ld ix,Application.flashIterator
	add ix,bc
	ld bc,FlashDevice._size
	call ArrayIterator_Construct
	pop hl
	pop bc
	pop af
	ret

; ix = this
Application_Run:
	call Application_Test
	ld a,(ix + Application.cli.flags)
	or (ix + Application.cli.slotCount)
	and a
	jp z,CLI_PrintBasicHelp
	bit CLI_FLAG_HELP,(ix + Application.cli.flags)
	jp nz,CLI_PrintAdvancedHelp
	call Application_PrintInfo
	call Application_Erase
	call Application_Program
	call Application_Verify
	call Application_Dump
	ret

; ix = this
Application_Test:
	call ASCII16XMapper_GetAddress_Test
	ret

; ix = this
Application_PrintInfo: PROC
	ld a,(ix + Application.cli.flags)
	and 1 << CLI_FLAG_INFO
	push ix
	ld de,Print
	call Application_CreateFlashIterator
	call ArrayIterator_ForEach
	pop ix
	ret
; a = nz: verbose
; ix = flash device
Print:
	push af
	call FlashDevice_Print
	pop af
	ret
	ENDP

; ix = this
Application_Erase: PROC
	bit CLI_FLAG_ERASE,(ix + Application.cli.flags)
	ret z
	ld hl,Application_messageErasingChip
	call System_PrintLn
	call Application_CheckProgrammable
	push ix
	ld de,ChipErase
	call Application_CreateFlashIterator
	call ArrayIterator_ForEach
	pop ix
	ret
; ix = flash device
ChipErase:
	equ FlashDevice_ChipErase
	ENDP

; ix = this
Application_Program: PROC
	bit CLI_FLAG_PROGRAM,(ix + Application.cli.flags)
	ret z
	ld hl,Application_messageProgramming
	call System_PrintLn
	call Application_CheckProgrammable
	call Application_FindFile
	call Application_CheckCapacity
	ld a,1
	call DOS_OpenFileHandle
	call DOS_TerminateIfError
	push ix
	ld de,ProgramBlock
	call Application_CreateFlashIterator
	ld de,0000H
	call Loop
	pop ix
	call DOS_CloseFileHandle
	call DOS_TerminateIfError
	call System_PrintCrLf
	ret
; b = file handle
; de = physical address / 1000H
; ix = flash iterator
Loop:
	push bc
	push de
	ld de,Application_buffer
	ld hl,FlashDevice_BLOCK_SIZE
	call DOS_ReadFromFileHandle
	pop de
	pop bc
	cp .EOF
	ret z
	call DOS_TerminateIfError
	push bc
	push de
	push ix
	ld c,l
	ld b,h
	ld hl,Application_buffer
	call ArrayIterator_ForEach
	pop ix
	pop de
	pop bc
	inc de
	call Application_PrintProgress
	jr Loop
; hl = source
; de = destination / 1000H
; bc = byte count (<= 1000H)
; ix = flash device
ProgramBlock:
	push bc
	push de
	push hl
	call FlashDevice_ProgramBlock
	pop hl
	pop de
	pop bc
	ret
	ENDP

; ix = this
Application_Verify: PROC
	bit CLI_FLAG_VERIFY,(ix + Application.cli.flags)
	ret z
	ld hl,Application_messageVerifying
	call System_PrintLn
	call Application_FindFile
	call Application_CheckCapacity
	ld a,1
	call DOS_OpenFileHandle
	call DOS_TerminateIfError
	push ix
	ld de,VerifyBlock
	call Application_CreateFlashIterator
	ld de,0000H
	call Loop
	pop ix
	push af
	call DOS_CloseFileHandle
	call DOS_TerminateIfError
	call System_PrintCrLf
	pop af
	ld hl,Application_messageVerifySuccess
	jp z,System_PrintLn
	ld hl,Application_messageVerifyFail
	jp System_PrintLn
; b = file handle
; de = physical address / 1000H
; ix = flash iterator
Loop:
	push bc
	push de
	ld de,Application_buffer
	ld hl,FlashDevice_BLOCK_SIZE
	call DOS_ReadFromFileHandle
	pop de
	pop bc
	cp .EOF
	ret z
	call DOS_TerminateIfError
	push bc
	push de
	push ix
	ld c,l
	ld b,h
	ld hl,Application_buffer
	call ArrayIterator_ForEach
	pop ix
	pop de
	pop bc
	inc de
	push af
	call Application_PrintProgress
	pop af
	ret nz
	jr Loop
; hl = source
; de = destination / 1000H
; bc = byte count (<= 1000H)
; ix = flash device
; f <- nz: not equal
VerifyBlock:
	push bc
	push de
	push hl
	call FlashDevice_VerifyBlock
	pop hl
	pop de
	pop bc
	ret z
	jp ArrayIterator_ForEach.Break
	ENDP

; ix = this
Application_Dump: PROC
	bit CLI_FLAG_DUMP,(ix + Application.cli.flags)
	ret z
	ld hl,Application_messageDumping
	call System_PrintLn
	call Application_CreateFile
	ld a,2
	call DOS_OpenFileHandle
	call DOS_TerminateIfError
	push ix
	call Application_GetFlashDevices
	ld de,0000H
	call Loop
	pop ix
	call DOS_CloseFileHandle
	call DOS_TerminateIfError
	call System_PrintCrLf
	ret
; b = file handle
; de = physical address / 1000H
; ix = flash device
Loop:
	push bc
	push de
	push bc
	ex de,hl
	ld bc,FlashDevice_BLOCK_SIZE
	ld de,Application_buffer
	di
	call FlashDevice_ReadBlock
	ei
	pop bc
	ld de,Application_buffer
	ld hl,FlashDevice_BLOCK_SIZE
	call DOS_WriteToFileHandle
	pop de
	pop bc
	call DOS_TerminateIfError
	inc de
	call Application_PrintProgress
	call FlashDevice_CheckCapacity
	jr nc,Loop
	ret
	ENDP

; ix = this
Application_CheckProgrammable: PROC
	push ix
	ld de,IsProgrammable
	call Application_CreateFlashIterator
	call ArrayIterator_ForEach
	ld hl,Application_errorFlash
	call nz,System_ThrowExceptionWithMessage
	pop ix
	ret
; ix = flash device
; f <- nz: not programmable
IsProgrammable:
	call FlashDevice_IsProgrammable
	ret z
	jp ArrayIterator_ForEach.Break
	ENDP

; de = file info block
; ix = this
; f <- c: exceeds capacity
; de <- file info block
Application_CheckCapacity: PROC
	push de
	push ix
	push de
	ld de,CheckCapacity
	call Application_CreateFlashIterator
	ex (sp),ix
	ld l,(ix + FileInfoBlock.fileSize + 0)
	ld h,(ix + FileInfoBlock.fileSize + 1)
	ld e,(ix + FileInfoBlock.fileSize + 2)
	ld d,(ix + FileInfoBlock.fileSize + 3)
	pop ix
	call Check
	ld hl,Application_warningCapacity
	call c,System_PrintLn
	pop ix
	pop de
	ret
Check:
	ld a,l
	or h
	or e
	or d
	ret z
	call Dec_DEHL
	call Sla_DEHL
	call nc,Sla_DEHL
	call nc,Sla_DEHL
	call nc,Sla_DEHL
	call nc,ArrayIterator_ForEach
	ret
Dec_DEHL:
	ld bc,-1
	add hl,bc
	ret c
	dec de
	ret
Sla_DEHL:
	add hl,hl
	ex de,hl
	adc hl,hl
	ex de,hl
	ret
; de = physical address / 1000H
; ix = this
; f <- c: out of range
CheckCapacity:
	call FlashDevice_CheckCapacity
	ret nc
	jp ArrayIterator_ForEach.Break
	ENDP

; de = address
; Modifies: af
Application_PrintProgress:
	ld a,0FH
	and e
	ret nz
	ld a,"."
	jp System_PrintChar

; ix = this
; de <- file info block
Application_FindFile:
	push ix
	call Application_GetCLI
	call CLI_GetPath_DE
	pop ix
	push ix
	ld bc,Application.fileInfoBlock
	add ix,bc
	ld b,0
	call DOS_FindFirstEntry
	call DOS_TerminateIfError
	ld e,ixl
	ld d,ixh
	pop ix
	ret

; ix = this
; de <- file info block
Application_CreateFile:
	push ix
	call Application_GetCLI
	call CLI_GetPath_DE
	pop ix
	push ix
	ld bc,Application.fileInfoBlock
	add ix,bc
	ld b,0
	call DOS_FindNewEntry
	call DOS_TerminateIfError
	ld e,ixl
	ld d,ixh
	pop ix
	ret

;
Application_messageWelcome:
	db "ASCII-X flash tool v1.1 by Grauw",0
Application_errorFlash:
	db "FlashROM error.",0
Application_warningCapacity:
	db "File exceeds capacity, truncating.",0
Application_messageErasingChip:
	db "Erasing chip...",0
Application_messageProgramming:
	db "Programming...",0
Application_messageVerifying:
	db "Verifying...",0
Application_messageDumping:
	db "Dumping...",0
Application_messageVerifySuccess:
	db "Verification successful.",0
Application_messageVerifyFail:
	db "Verification failed.",0

Application_buffer:
	ds FlashDevice_BLOCK_SIZE
