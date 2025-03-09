;
;
;
Application: MACRO
	cli:
		CLI
	slotRestore1:
		db 0
	slotRestore2:
		db 0
	flashROM:
		FlashROM
	ENDM

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
Application_Construct:
	ld h,40H
	call Memory_GetSlot
	ld (ix + Application.slotRestore1),a
	ld h,80H
	call Memory_GetSlot
	ld (ix + Application.slotRestore2),a
	push ix
	call Application_GetCLI
	call CLI_Construct
	pop ix
	ld a,(ix + Application.cli.slot)
	inc a
	ld hl,Application_messageUsage
	call z,System_ThrowExceptionWithMessage
	ld h,40H
	ld a,(ix + Application.cli.slot)
	call Memory_SetSlot
	ld h,80H
	ld a,(ix + Application.cli.slot)
	call Memory_SetSlot
	push ix
	call Application_GetFlashROM
	call FlashROM_Construct
	IF CFIQuery_SHIM
	push ix
	call FlashROM_GetCFIQuery
	ld a,0
	ld hl,CFIQuery_shim
	call CFIQuery_Construct
	pop ix
	ENDIF
	pop ix
	ret

; ix = this
Application_Destruct:
	push ix
	call Application_GetFlashROM
	call FlashROM_Destruct
	pop ix
	ld h,40H
	ld a,(ix + Application.slotRestore1)
	call Memory_SetSlot
	ld h,80H
	ld a,(ix + Application.slotRestore1)
	call Memory_SetSlot
	push ix
	call Application_GetCLI
	call CLI_Destruct
	pop ix
	ret

Application_Run:
	call Application_Test
	call Application_PrintInfo
	call Application_Erase
	call Application_Program
	call Application_Verify
	call Application_Dump
	ret

Application_Test:
	call FlashROM_GetMapperAddress_Test
	ret

Application_PrintInfo: PROC
	ld hl,Application_messageQuery
	call System_Print
	call Application_PrintSlot
	ld hl,Application_messageQuery2
	call System_Print
	bit 0,(ix + Application.cli.info)
	jr nz,Verbose
	push ix
	call Application_GetFlashROM
	call FlashROM_Print
	pop ix
	ret
Verbose:
	push ix
	call Application_GetFlashROM
	call FlashROM_PrintVerbose
	pop ix
	ret
	ENDP

Application_Erase:
	bit 0,(ix + Application.cli.erase)
	ret z
	ld hl,Application_messageErasingChip
	call System_Print
	push ix
	call Application_GetFlashROM
	call FlashROM_IsProgrammable
	ld hl,Application_errorFlash
	call nz,System_ThrowExceptionWithMessage
	call Application_GetFlashROM
	call FlashROM_ChipErase
	pop ix
	ret

Application_Program: PROC
	bit 0,(ix + Application.cli.program)
	ret z
	ld hl,Application_messageProgramming
	call System_Print
	push ix
	call Application_GetFlashROM
	call FlashROM_IsProgrammable
	ld hl,Application_errorFlash
	call nz,System_ThrowExceptionWithMessage
	pop ix
	push ix
	call Application_GetCLI
	call CLI_GetFileInfoBlock_DE
	pop ix
	ld hl,Application_errorNoFile
	call z,System_ThrowExceptionWithMessage
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
Loop:
	push bc
	push de
	ld de,Application_buffer
	ld hl,1000H
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
	ld a,"."
	call System_PrintChar
	pop de
	pop bc
	inc de
	jr Loop
Program:
	ld a,(ix + FlashROM.cfiQuery.maxBufferWrite)
	cp 8
	jp nc,FlashROM_ProgramBufferedBlock
	jp FlashROM_ProgramBlock
	ENDP

Application_Verify: PROC
	bit 0,(ix + Application.cli.verify)
	ret z
	ld hl,Application_messageVerifying
	call System_Print
	push ix
	call Application_GetCLI
	call CLI_GetFileInfoBlock_DE
	pop ix
	ld hl,Application_errorNoFile
	call z,System_ThrowExceptionWithMessage
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
Loop:
	push bc
	push de
	ld de,Application_buffer
	ld hl,1000H
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
	push af
	ld a,"."
	call System_PrintChar
	pop af
	pop de
	pop bc
	inc de
	ret nz
	jr Loop
	ENDP

Application_Dump: PROC
	bit 0,(ix + Application.cli.dump)
	ret z
	ld hl,Application_messageDumping
	call System_Print
	call System_ThrowException
	ENDP

Application_PrintSlot:
	ld a,(ix + Application.cli.slot)
	and 3
	add a,"0"
	call System_PrintChar
	bit 7,(ix + Application.cli.slot)
	ret z
	ld a,"-"
	call System_PrintChar
	ld a,(ix + Application.cli.slot)
	rrca
	rrca
	and 3
	add a,"0"
	call System_PrintChar
	ret

;
Application_errorNoSlot:
	db "No slot specified.",13,10,0
Application_errorNoFile:
	db "No file specified.",13,10,0
Application_errorFlash:
	db "Flash ROM error.",13,10,0
Application_messageQuery:
	db "Querying slot ",0
Application_messageQuery2:
	db " for FlashROM information:",13,10,10,0
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

Application_messageUsage:
	db "Usage: asciixf [options] [<file.rom>]",13,10
	db 13,10
	db "Options:",13,10
	db "  /s  Slot number (required). Format: p or p-s.",13,10
	db "  /e  Erase flash ROM.",13,10
	db "  /p  Program flash ROM from file.",13,10
	db "  /v  Verify flash ROM with file.",13,10
	db "  /d  Dump flash ROM to file.",13,10
	db "  /i  Display flash ROM information.",13,10,0

Application_buffer:
	ds 1000H
