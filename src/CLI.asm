;
; Command-line interface parser
;
CLI_BUFFER_SIZE: equ 255

CLI: MACRO
	usage:
		db -1
	erase:
		db 0
	program:
		db 0
	verify:
		db 0
	dump:
		db 0
	info:
		db 0
	path:
		dw 0
	slotCount:
		db 0
	slots:
		REPT Application_MAX_SLOTS
	slot:
		Slot
		ENDM
	buffer:
		ds CLI_BUFFER_SIZE
	_size:
	ENDM

; ix = this
CLI_Construct:
	call CLI_GetBuffer_DE
	ld hl,CLI_parametersEnvName
	ld b,255
	call DOS_GetEnvironmentItem
	call nz,System_ThrowException
	call CLI_Parse
	call CLI_Verify
	ret

; ix = this
; de <- buffer
; Modifies: hl
CLI_GetBuffer_DE:
	ld e,ixl
	ld d,ixh
	ld hl,CLI.buffer
	add hl,de
	ex de,hl
	ret

; ix = this
; de <- path
CLI_GetPath_DE:
	ld e,(ix + CLI.path + 0)
	ld d,(ix + CLI.path + 1)
	ret

; c = slot ID
; ix = this
CLI_AddSlot: PROC
	ld b,Application_MAX_SLOTS
	push ix
Loop:
	ld a,(ix + CLI.slots.0.slot.id)
	cp c
	ld hl,CLI_errorSameSlot
	call z,System_ThrowExceptionWithMessage
	cp Slot_NONE
	jr z,Set
	inc ix
	djnz Loop
	ld hl,CLI_errorTooManySlots
	call System_ThrowExceptionWithMessage
Set:
	ld (ix + CLI.slots.0.slot.id),c
	ld bc,CLI.slots
	add ix,bc
	call Slot_CheckExpanded
	ld hl,CLI_errorSlotExpansion
	call nz,System_ThrowExceptionWithMessage
	pop ix
	inc (ix + CLI.slotCount)
	ret
	ENDP

; ix = this
CLI_Parse: PROC
	call CLI_GetBuffer_DE
Loop:
	ld a,(de)
	inc de
	and a
	ret z
	cp "/"
	jr z,Option
	cp " " + 1
	jr nc,Path
	jr Loop
Option:
	ld (ix + CLI.usage),0
	call CLI_ParseOption
	jr Loop
Path:
	ld (ix + CLI.usage),0
	dec de
	call CLI_ParsePath
	jr Loop
	ENDP

; de = buffer position
; ix = this
; de <- buffer position after path
CLI_ParsePath: PROC
	ld a,(ix + CLI.path)
	or (ix + CLI.path + 1)
	ld hl,CLI_errorMultiplePaths
	call nz,System_ThrowExceptionWithMessage
	ld (ix + CLI.path),e
	ld (ix + CLI.path + 1),d
Loop:
	ld a,(de)
	inc de
	cp " " + 1
	jr nc,Loop
	dec de
	and a
	ret z
	xor a
	ld (de),a
	inc de
	ret
	ENDP

; de = buffer position
; ix = this
; de <- buffer position after option
CLI_ParseOption: PROC
	ld a,(de)
	inc de
	and 11011111B  ; upper-case
	cp "S"
	jr z,OptionSlot
	cp "E"
	jr z,OptionErase
	cp "P"
	jr z,OptionProgram
	cp "V"
	jr z,OptionVerify
	cp "D"
	jr z,OptionDump
	cp "I"
	jr z,OptionInfo
	ld hl,CLI_errorUnknownOption
	call System_ThrowExceptionWithMessage
OptionSlot:
	call CLI_ParseSlot
	jp CLI_AddSlot
OptionErase:
	ld (ix + CLI.erase),-1
	jp CLI_ParseNoParameter
OptionProgram:
	ld (ix + CLI.program),-1
	jp CLI_ParseNoParameter
OptionVerify:
	ld (ix + CLI.verify),-1
	jp CLI_ParseNoParameter
OptionDump:
	ld (ix + CLI.dump),-1
	jp CLI_ParseNoParameter
OptionInfo:
	ld (ix + CLI.info),-1
	jp CLI_ParseNoParameter
	ENDP

; de = buffer position
; ix = this
; de <- buffer position after option
CLI_ParseNoParameter:
	ld a,(de)
	cp " " + 1
	ret c
	ld hl,CLI_errorUnknownOption
	call System_ThrowExceptionWithMessage

; de = buffer position
; ix = this
; c <- slot ID
; de <- buffer position after slot ID
CLI_ParseSlot:
	ld c,0
	ld hl,CLI_errorParameter
	ld a,(de)
	inc de
	sub "0"
	call c,System_ThrowExceptionWithMessage
	cp 4
	call nc,System_ThrowExceptionWithMessage
	ld c,a
	ld a,(de)
	cp " " + 1
	ret c
	inc de
	cp "-"
	call nz,System_ThrowExceptionWithMessage
	ld a,(de)
	inc de
	sub "0"
	call c,System_ThrowExceptionWithMessage
	cp 4
	call nc,System_ThrowExceptionWithMessage
	add a,a
	add a,a
	or 80H
	or c
	ld c,a
	ld a,(de)
	cp " " + 1
	call nc,System_ThrowExceptionWithMessage
	ret

; ix = this
CLI_Verify: PROC
	bit 0,(ix + CLI.usage)
	ld hl,CLI_messageUsage
	call nz,System_ThrowExceptionWithMessage
	ld a,(ix + CLI.slotCount)
	cp 1
	ld hl,CLI_errorNoSlot
	call c,System_ThrowExceptionWithMessage
	bit 0,(ix + CLI.program)
	jr nz,Program
	bit 0,(ix + CLI.verify)
	jr nz,Verify
	bit 0,(ix + CLI.dump)
	jr nz,Dump
	ret
Program:
Verify:
	ld a,(ix + CLI.path + 0)
	or (ix + CLI.path + 1)
	ld hl,CLI_errorNoFile
	call z,System_ThrowExceptionWithMessage
	bit 0,(ix + CLI.dump)
	ld hl,CLI_errorDumpProgramVerify
	call nz,System_ThrowExceptionWithMessage
	ret
Dump:
	ld a,(ix + CLI.path + 0)
	or (ix + CLI.path + 1)
	ld hl,CLI_errorNoFile
	call z,System_ThrowExceptionWithMessage
	bit 0,(ix + CLI.program)
	ld hl,CLI_errorDumpProgramVerify
	call nz,System_ThrowExceptionWithMessage
	bit 0,(ix + CLI.verify)
	ld hl,CLI_errorDumpProgramVerify
	call nz,System_ThrowExceptionWithMessage
	ld a,(ix + CLI.slotCount)
	cp 2
	ld hl,CLI_errorTooManySlots
	call nc,System_ThrowExceptionWithMessage
	ret
	ENDP

;
CLI_parametersEnvName:
	db "PARAMETERS",0
CLI_errorUnknownOption:
	db "Unknown command line option.",0
CLI_errorParameter:
	db "Missing or invalid command line option parameter.",0
CLI_errorMultiplePaths:
	db "Can not specify more than one file path.",0
CLI_errorDumpProgramVerify:
	db "Can not combine dump with program or verify.",0
CLI_errorSlotExpansion:
	db "Specified slot expansion incorrect.",0
CLI_errorSameSlot:
	db "Same slot specified multiple times.",0
CLI_errorTooManySlots:
	db "Too many slots specified.",0
CLI_errorNoSlot:
	db "No slot specified.",0
CLI_errorNoFile:
	db "No file specified.",0
CLI_messageUsage:
	db "Usage: asciixf [options] [<file.rom>]",13,10
	db 13,10
	db "Options:",13,10
	db "  /s  Slot number (required). Format: p or p-s.",13,10
	db "      Specify up to 8 for bulk flashing.",13,10
	db "  /e  Erase flash ROM.",13,10
	db "  /p  Program flash ROM from file.",13,10
	db "  /v  Verify flash ROM with file.",13,10
	db "  /d  Dump flash ROM to file.",13,10
	db "  /i  Display flash ROM information.",0
