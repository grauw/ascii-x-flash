;
; Main application
;
Application: MACRO
	slotRestore1:
		Slot
	slotRestore2:
		Slot
	cli:
		CLI
	fileInfoBlock:
		FileInfoBlock
	flashROM:
		FlashROM
	ENDM

; ix = this
Application_Construct:
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
	ld a,(ix + Application.cli.slot.id)
	call Application_GetFlashROM
	call FlashROM_Construct
	pop ix
	ret

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
; ix <- FlashROM
Application_GetFlashROM:
	ld de,Application.flashROM
	add ix,de
	ret

; ix = this
Application_Run:
	call Application_Test
	call Application_PrintInfo
	call Application_Erase
	call Application_Program
	call Application_Verify
	call Application_Dump
	ret

; ix = this
Application_Test:
	call FlashROM_GetMapperAddress_Test
	ret

; ix = this
Application_PrintInfo:
	ld a,(ix + Application.cli.info)
	push ix
	call Application_GetFlashROM
	call FlashROM_Print
	pop ix
	ret

; ix = this
Application_Erase:
	bit 0,(ix + Application.cli.erase)
	ret z
	ld hl,Application_messageErasingChip
	call System_Print
	call Application_CheckProgrammable
	push ix
	call Application_GetFlashROM
	call FlashROM_ChipErase
	pop ix
	ret

; ix = this
Application_Program: PROC
	bit 0,(ix + Application.cli.program)
	ret z
	ld hl,Application_messageProgramming
	call System_Print
	call Application_CheckProgrammable
	call Application_FindFile
	ld a,1
	call DOS_OpenFileHandle
	call DOS_TerminateIfError
	push ix
	call Application_GetFlashROM
	ld de,0000H
	call Loop
	pop ix
	call DOS_CloseFileHandle
	call DOS_TerminateIfError
	call System_PrintCrLf
	ret
; b = file handle
; de = physical address / 1000H
; ix = flash ROM
Loop:
	push bc
	push de
	ld de,Application_buffer
	ld hl,FlashROM_BLOCK_SIZE
	call DOS_ReadFromFileHandle
	pop de
	pop bc
	cp .EOF
	ret z
	call DOS_TerminateIfError
	push bc
	push de
	ld c,l
	ld b,h
	ld hl,Application_buffer
	di
	call Program
	ei
	pop de
	pop bc
	inc de
	call Application_PrintProgress
	jr Loop
Program:
	ld a,(ix + FlashROM.cfiQuery.maxBufferWrite)
	cp 8
	jp nc,FlashROM_ProgramBufferedBlock
	jp FlashROM_ProgramBlock
	ENDP

; ix = this
Application_Verify: PROC
	bit 0,(ix + Application.cli.verify)
	ret z
	ld hl,Application_messageVerifying
	call System_Print
	call Application_FindFile
	ld a,1
	call DOS_OpenFileHandle
	call DOS_TerminateIfError
	push ix
	call Application_GetFlashROM
	ld de,0000H
	call Loop
	pop ix
	push af
	call DOS_CloseFileHandle
	call DOS_TerminateIfError
	call System_PrintCrLf
	pop af
	ld hl,Application_messageVerifySuccess
	jp z,System_Print
	ld hl,Application_messageVerifyFail
	jp System_Print
; b = file handle
; de = physical address / 1000H
; ix = flash ROM
Loop:
	push bc
	push de
	ld de,Application_buffer
	ld hl,FlashROM_BLOCK_SIZE
	call DOS_ReadFromFileHandle
	pop de
	pop bc
	cp .EOF
	ret z
	call DOS_TerminateIfError
	push bc
	push de
	ld c,l
	ld b,h
	ld hl,Application_buffer
	di
	call FlashROM_VerifyBlock
	ei
	pop de
	pop bc
	inc de
	push af
	call Application_PrintProgress
	pop af
	ret nz
	jr Loop
	ENDP

; ix = this
Application_Dump: PROC
	bit 0,(ix + Application.cli.dump)
	ret z
	ld hl,Application_messageDumping
	call System_Print
	call System_ThrowException
	ENDP

; ix = this
Application_CheckProgrammable:
	push ix
	call Application_GetFlashROM
	call FlashROM_IsProgrammable
	ld hl,Application_errorFlash
	call nz,System_ThrowExceptionWithMessage
	pop ix
	ret

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

;
Application_errorFlash:
	db "FlashROM error.",13,10,0
Application_messageErasingChip:
	db "Erasing chip...",13,10,0
Application_messageProgramming:
	db "Programming...",13,10,0
Application_messageVerifying:
	db "Verifying...",13,10,0
Application_messageDumping:
	db "Dumping...",13,10,0
Application_messageVerifySuccess:
	db "Verification successful.",13,10,0
Application_messageVerifyFail:
	db "Verification failed.",13,10,0

Application_buffer:
	ds FlashROM_BLOCK_SIZE
