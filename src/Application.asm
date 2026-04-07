;
; Main application
;
Application_MAX_SLOTS: equ 8

Application: MACRO
	buffer:
		dw 0
	addressStart:
		dw 0
	addressEnd:
		dw 0
	addressCurrent:
		dw 0
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

; hl = buffer
; ix = this
Application_Construct:
	ld (ix + Application.buffer + 0),l
	ld (ix + Application.buffer + 1),h
	ld hl,Application_messageWelcome
	call System_PrintLn
	call System_PrintCrLf
	push ix
	call Application_GetCLI
	call CLI_Construct
	pop ix
	call Application_ConstructFlashDevices
	call Application_ConstructAddress
	ld a,(ix + Application.cli.flags)
	and 1 << CLI_FLAG_PROGRAM | 1 << CLI_FLAG_VERIFY
	ret z
	call Application_FindFile
	ret

; ix = this
Application_ConstructFlashDevices: PROC
	ld e,ixl
	ld d,ixh
	ld hl,Application.cli.slots
	add hl,de
	ld de,ConstructFlashDevice
	call Application_CreateFlashIterator
	push ix
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
Application_ConstructAddress: PROC
	call Application_GetMaxCapacity
	jr z,NoMaxCapacity
	ld l,(ix + Application.cli.addressStart + 0)
	ld h,(ix + Application.cli.addressStart + 1)
	and a
	sbc hl,de
	call nc,CLI_ThrowAddress
	add hl,de
	ld (ix + Application.addressStart + 0),l
	ld (ix + Application.addressStart + 1),h
	ld (ix + Application.addressEnd + 0),e
	ld (ix + Application.addressEnd + 1),d
	ld l,(ix + Application.cli.addressEnd + 0)
	ld h,(ix + Application.cli.addressEnd + 1)
	ld a,l
	or h
	ret z
	ld (ix + Application.addressEnd + 0),l
	ld (ix + Application.addressEnd + 1),h
	scf
	sbc hl,de
	call nc,CLI_ThrowAddress
	ret
NoMaxCapacity:
	ld l,(ix + Application.cli.addressStart + 0)
	ld h,(ix + Application.cli.addressStart + 1)
	ld e,(ix + Application.cli.addressEnd + 0)
	ld d,(ix + Application.cli.addressEnd + 1)
	ld (ix + Application.addressStart + 0),l
	ld (ix + Application.addressStart + 1),h
	ld (ix + Application.addressEnd + 0),e
	ld (ix + Application.addressEnd + 1),d
	ret
	ENDP

; ix = this
Application_Destruct:
	ret

; ix = this
; ix <- CLI
Application_GetCLI:
	ld de,Application.cli
	add ix,de
	ret

; ix = this
; de <- file info block
Application_GetFileInfoBlock_DE:
	push ix
	ld de,Application.fileInfoBlock
	add ix,de
	ex (sp),ix
	pop de
	ret

; ix = this
; ix <- flash devices
Application_GetFlashDevices:
	ld de,Application.flashDevices
	add ix,de
	ret

; de = function
; ix = this
; iy <- flash iterator
Application_CreateFlashIterator:
	push af
	push bc
	push hl
	ld a,(ix + Application.cli.slotCount)
	ld c,ixl
	ld b,ixh
	ld hl,Application.flashDevices
	add hl,bc
	ld iy,Application.flashIterator
	add iy,bc
	ld bc,FlashDevice._size
	call ArrayIterator_Construct
	pop hl
	pop bc
	pop af
	ret

; ix = this
; f <- c: done (end before start)
; de <- start address / 1000H
; hl <- length / 1000H
Application_InitAddress:
	ld e,(ix + Application.addressStart + 0)
	ld d,(ix + Application.addressStart + 1)
	ld (ix + Application.addressCurrent + 0),e
	ld (ix + Application.addressCurrent + 1),d
	ld l,(ix + Application.addressEnd + 0)
	ld h,(ix + Application.addressEnd + 1)
	scf
	sbc hl,de
	inc hl
	ret

; ix = this
; f <- c: done
; de <- next address / 1000H
; hl <- remaining / 1000H
Application_NextAddress:
	ld e,(ix + Application.addressCurrent + 0)
	ld d,(ix + Application.addressCurrent + 1)
	inc de
	ld (ix + Application.addressCurrent + 0),e
	ld (ix + Application.addressCurrent + 1),d
	call Application_PrintProgress
	ld l,(ix + Application.addressEnd + 0)
	ld h,(ix + Application.addressEnd + 1)
	scf
	sbc hl,de
	inc hl
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
	ld de,Print
	call Application_CreateFlashIterator
	push ix
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
Application_Erase:
	bit CLI_FLAG_ERASE,(ix + Application.cli.flags)
	ret z
	bit CLI_FLAG_CHIP,(ix + Application.cli.flags)
	jr z,Application_EraseSector
	jr Application_EraseChip

; ix = this
Application_EraseChip: PROC
	ld hl,Application_messageErasingChip
	call System_PrintLn
	call Application_CheckProgrammable
	ld de,ChipErase
	call Application_CreateFlashIterator
	push ix
	call ArrayIterator_ForEach
	pop ix
	ret
; ix = flash device
ChipErase:
	equ FlashDevice_ChipErase
	ENDP

; ix = this
Application_EraseSector: PROC
	ld hl,Application_messageErasing
	call System_PrintLn
	call Application_CheckProgrammable
	call Application_InitAddress
	ret c
	ld e,(ix + Application.addressStart + 0)
	ld d,(ix + Application.addressStart + 1)
	call Application_IsSectorAligned
	ld hl,Application_warningEraseAlignment
	call nz,System_PrintLn
	jr nz,SkipEndCheck
	ld e,(ix + Application.addressEnd + 0)
	ld d,(ix + Application.addressEnd + 1)
	call Application_IsSectorAligned
	ld hl,Application_warningEraseAlignment
	call nz,System_PrintLn
SkipEndCheck:
	ld de,SectorErase
	call Application_CreateFlashIterator
	call Loop
	call System_PrintCrLf
	ret
; ix = flash iterator
Loop:
	push ix
	ld l,(ix + Application.addressStart + 0)
	ld h,(ix + Application.addressStart + 1)
	ld e,(ix + Application.addressCurrent + 0)
	ld d,(ix + Application.addressCurrent + 1)
	call ArrayIterator_ForEach
	pop ix
	call Application_NextAddress
	jr nc,Loop
	ret
; hl = start address / 1000H
; de = physical address / 1000H
; ix = flash device
SectorErase:
	push de
	push hl
	push ix
	push de
	call FlashDevice_GetCFIQuery
	pop de
	and a
	sbc hl,de
	call nz,CFIQuery_IsSectorAligned
	pop ix
	call z,FlashDevice_SectorErase
	pop hl
	pop de
	ret
	ENDP

; ix = this
Application_Program: PROC
	bit CLI_FLAG_PROGRAM,(ix + Application.cli.flags)
	ret z
	ld hl,Application_messageProgramming
	call System_PrintLn
	call Application_CheckProgrammable
	call Application_InitAddress
	ret c
	call Application_GetFileInfoBlock_DE
	call Application_PrintCapacityWarning
	ld a,1
	call DOS_OpenFileHandle
	call DOS_TerminateIfError
	call Application_SetFileStart
	ld de,ProgramBlock
	call Application_CreateFlashIterator
	call Loop
	call DOS_CloseFileHandle
	call DOS_TerminateIfError
	call System_PrintCrLf
	ret
; b = file handle
; de = physical address / 1000H
; ix = this
; iy = flash iterator
Loop:
	push bc
	ld e,(ix + Application.buffer + 0)
	ld d,(ix + Application.buffer + 1)
	ld hl,FlashDevice_BLOCK_SIZE
	call DOS_ReadFromFileHandle
	pop bc
	cp .EOF
	ret z
	call DOS_TerminateIfError
	push bc
	push ix
	ld c,l
	ld b,h
	ld l,(ix + Application.buffer + 0)
	ld h,(ix + Application.buffer + 1)
	ld e,(ix + Application.addressCurrent + 0)
	ld d,(ix + Application.addressCurrent + 1)
	call ArrayIterator_ForEach
	pop ix
	pop bc
	call Application_NextAddress
	jr nc,Loop
	ret
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
	call Application_InitAddress
	ret c
	call Application_GetFileInfoBlock_DE
	call Application_PrintCapacityWarning
	ld a,1
	call DOS_OpenFileHandle
	call DOS_TerminateIfError
	call Application_SetFileStart
	ld de,VerifyBlock
	call Application_CreateFlashIterator
	call Loop
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
; ix = this
; iy = flash iterator
; f <- nz: not equal
Loop:
	push bc
	ld e,(ix + Application.buffer + 0)
	ld d,(ix + Application.buffer + 1)
	ld hl,FlashDevice_BLOCK_SIZE
	call DOS_ReadFromFileHandle
	pop bc
	cp .EOF
	ret z
	call DOS_TerminateIfError
	push bc
	push ix
	ld c,l
	ld b,h
	ld l,(ix + Application.buffer + 0)
	ld h,(ix + Application.buffer + 1)
	ld e,(ix + Application.addressCurrent + 0)
	ld d,(ix + Application.addressCurrent + 1)
	call ArrayIterator_ForEach
	pop ix
	pop bc
	ret nz
	call Application_NextAddress
	jr nc,Loop
	xor a
	ret
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
	call Application_InitAddress
	ret c
	push hl
	call Application_CreateFile
	ld a,2
	call DOS_OpenFileHandle
	call DOS_TerminateIfError
	pop de
	call Application_PreAllocateSize
	ld de,ReadBlock
	call Application_CreateFlashIterator
	call Loop
	call DOS_CloseFileHandle
	call DOS_TerminateIfError
	call System_PrintCrLf
	ret
; b = file handle
; ix = this
; iy = flash iterator
Loop:
	push bc
	push ix
	ld l,(ix + Application.addressCurrent + 0)
	ld h,(ix + Application.addressCurrent + 1)
	ld e,(ix + Application.buffer + 0)
	ld d,(ix + Application.buffer + 1)
	ld bc,FlashDevice_BLOCK_SIZE
	call ArrayIterator_ForEach
	pop ix
	pop bc
	push bc
	ld e,(ix + Application.buffer + 0)
	ld d,(ix + Application.buffer + 1)
	ld hl,FlashDevice_BLOCK_SIZE
	call DOS_WriteToFileHandle
	call DOS_TerminateIfError
	pop bc
	call Application_NextAddress
	jr nc,Loop
	ret
; hl = source / 1000H
; de = destination
; bc = byte count (<= 1000H)
; ix = flash device
ReadBlock:
	push bc
	push de
	push hl
	call FlashDevice_ReadBlock
	pop hl
	pop de
	pop bc
	ret
	ENDP

; ix = this
Application_CheckProgrammable: PROC
	ld de,IsProgrammable
	call Application_CreateFlashIterator
	push ix
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

; ix = this
; f <- z: max capacity is zero
; de <- max capacity / 1000H
Application_GetMaxCapacity: PROC
	ld de,GetMaxCapacity
	call Application_CreateFlashIterator
	push ix
	ld de,0
	call ArrayIterator_ForEach
	pop ix
	ret
; de = current max capacity / 1000H
; ix = flash device
; f <- z: max capacity is zero
; de <- new max capacity / 1000H
GetMaxCapacity:
	ld l,(ix + FlashDevice.capacity + 0)
	ld h,(ix + FlashDevice.capacity + 1)
	and a
	sbc hl,de
	ret c
	adc hl,de
	ex de,hl
	ret
	ENDP

; de = physical address / 1000H
; ix = this
; f <- z: aligned, nz: not aligned
; de <- physical address / 1000H
Application_IsSectorAligned: PROC
	push de
	ld de,IsSectorAligned
	call Application_CreateFlashIterator
	pop de
	push ix
	call ArrayIterator_ForEach
	pop ix
	ret
; de = physical address / 1000H
; ix = flash device
; f <- z: aligned or above capacity, nz: not aligned
; de <- physical address / 1000H
IsSectorAligned:
	ld l,(ix + FlashDevice.capacity + 0)
	ld h,(ix + FlashDevice.capacity + 1)
	scf
	sbc hl,de
	jr c,AboveCapacity
	push ix
	push de
	call FlashDevice_GetCFIQuery
	pop de
	call CFIQuery_IsSectorAligned
	pop ix
	ret z
	jp ArrayIterator_ForEach.Break
AboveCapacity:
	xor a
	ret
	ENDP

; de = physical address / 1000H
; ix = this
; f <- c: exceeds capacity
; de <- physical address / 1000H
; Modifies: a
Application_CheckCapacity: PROC
	push de
	ld de,CheckCapacity
	call Application_CreateFlashIterator
	pop de
	push ix
	call ArrayIterator_ForEach
	pop ix
	ret
; de = physical address / 1000H
; ix = this
; f <- c: exceeds capacity
; de <- physical address / 1000H
; Modifies: a
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

; ix = this
Application_SetFileStart:
	ld l,(ix + Application.cli.fileStart + 0)
	ld h,(ix + Application.cli.fileStart + 1)
	ld e,(ix + Application.cli.fileStart + 2)
	ld d,(ix + Application.cli.fileStart + 3)
	ld a,0
	push bc
	call DOS_MoveFileHandlePointer
	call DOS_TerminateIfError
	pop bc
	ret

; b = file handle
; de = size / 1000H
; ix = this
; b <- file handle
Application_PreAllocateSize:
	push bc
	push de
	ld bc,2103H
	call Application_CheckNextorVersion
	pop de
	pop bc
	ret c
	ld a,e
	or d
	ret z
	dec de
	ld l,0FFH
	ld h,e
	ld e,d
	ld d,0
	REPT 4
	scf
	adc hl,hl
	rl e
	rl d
	ENDM
	ld a,0
	push bc
	call DOS_MoveFileHandlePointer
	call DOS_TerminateIfError
	pop bc
	ld a,0FFH
	ld e,(ix + Application.buffer + 0)
	ld d,(ix + Application.buffer + 1)
	ld (de),a
	ld hl,1
	push bc
	call DOS_WriteToFileHandle
	call DOS_TerminateIfError
	pop bc
	ld hl,0
	ld de,0
	ld a,0
	push bc
	call DOS_MoveFileHandlePointer
	call DOS_TerminateIfError
	pop bc
	ret

; bc = Nextor version (MmrrH = M.m.rr)
; f <- z: not Nextor or same Nextor, c: older version
Application_CheckNextorVersion:
	push bc
	call Application_GetNextorVersion
	pop bc
	ret z
	sbc hl,bc
	ret

; f <- z: not Nextor, nc
; hl <- Nextor version (MmrrH = M.m.rr), 0: not Nextor
Application_GetNextorVersion:
	push ix
	push iy
	ld b,5AH
	ld hl,1234H
	ld de,0ABCDH
	ld ix,0
	ld c,_DOSVER
	call BDOS
	ex (sp),iy
	pop de
	ex (sp),ix
	pop hl
	ld a,h
	and a
	ret z
	ex de,hl
	ld a,e
	add a,a
	add a,a
	add a,a
	add a,a
	or h
	ld h,a
	ret

; de = file info block
; ix = this
; de <- file size / 1000H (rounded up)
Application_GetFileSize: PROC
	push ix
	ld ixl,e
	ld ixh,d
	ld l,(ix + FileInfoBlock.fileSize + 0)
	ld h,(ix + FileInfoBlock.fileSize + 1)
	ld e,(ix + FileInfoBlock.fileSize + 2)
	ld d,(ix + FileInfoBlock.fileSize + 3)
	pop ix
	ld c,(ix + Application.cli.fileStart + 0)
	ld b,(ix + Application.cli.fileStart + 1)
	and a
	sbc hl,bc
	ld c,(ix + Application.cli.fileStart + 2)
	ld b,(ix + Application.cli.fileStart + 3)
	ex de,hl
	sbc hl,bc
	ex de,hl
	jr c,Zero
	ld bc,1000H - 1
	add hl,bc
	ex de,hl
	ld bc,0
	adc hl,bc
	ex de,hl
	REPT 4
	add hl,hl
	rl e
	rl d
	jr c,Cap
	ENDM
	ld hl,-ASCII16XMapper_MAX_ADDRESS
	add hl,de
	ret nc
Cap:
	ld de,ASCII16XMapper_MAX_ADDRESS
	ret
Zero:
	ld de,0
	ret
	ENDP

; de = file info block
; ix = this
; de <- file info block
Application_PrintCapacityWarning: PROC
	push de
	call CheckCapacity
	ld hl,Application_warningCapacity
	call c,System_PrintLn
	pop de
	ret
CheckCapacity:
	ld a,(ix + Application.cli.addressEnd + 0)
	or (ix + Application.cli.addressEnd + 1)
	ret nz
	call Application_GetFileSize
	ld a,e
	or d
	ret z
	ld l,(ix + Application.addressStart + 0)
	ld h,(ix + Application.addressStart + 1)
	add hl,de
	ret c
	ex de,hl
	dec de
	jp Application_CheckCapacity
	ENDP

;
Application_messageWelcome:
	db "ASCII-X flash tool v1.2.2 by Grauw",0
Application_errorFlash:
	db "FlashROM error.",0
Application_warningCapacity:
	db "File exceeds capacity, truncating.",0
Application_messageErasing:
	db "Erasing...",0
Application_messageErasingChip:
	db "Erasing chip...",0
Application_warningEraseAlignment:
	db "Address not sector aligned, erasing full sector.",0
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
