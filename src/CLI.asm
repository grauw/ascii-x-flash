;
; Command-line interface parser
;
CLI_BUFFER_SIZE: equ 255

CLI: MACRO
	slot:
		Slot
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

; ix = this
CLI_Parse: PROC
	call CLI_GetBuffer_DE
Loop:
	ld a,(de)
	and a
	ret z
	cp "/"
	jr z,Option
	cp " " + 1
	jr nc,Path
	inc de
	jr Loop
Option:
	ld (ix + CLI.usage),0
	call CLI_ParseOption
	jr Loop
Path:
	ld (ix + CLI.usage),0
	call CLI_ParsePath
	jr Loop
	ENDP

; de = buffer position
; ix = this
CLI_ParseOption: PROC
	inc de
	ld a,(de)
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
	inc de
	call CLI_ParseSlot
	ld (ix + CLI.slot.id),c
	jr Next
OptionErase:
	ld (ix + CLI.erase),-1
	inc de
	jr Next
OptionProgram:
	ld (ix + CLI.program),-1
	inc de
	jr Next
OptionVerify:
	ld (ix + CLI.verify),-1
	inc de
	jr Next
OptionDump:
	ld (ix + CLI.dump),-1
	inc de
	jr Next
OptionInfo:
	ld (ix + CLI.info),-1
	inc de
	jr Next
Next:
	ld a,(de)
	cp " " + 1
	ret c
	ld hl,CLI_errorUnknownOption
	call System_ThrowExceptionWithMessage
	ENDP

; de = buffer position
; de <- buffer position after path
; ix = this
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

; ix = this
CLI_Verify: PROC
	bit 0,(ix + CLI.usage)
	ld hl,CLI_messageUsage
	call nz,System_ThrowExceptionWithMessage
	ld a,(ix + CLI.slot.id)
	cp Slot_NONE
	ld hl,CLI_errorNoSlot
	call z,System_ThrowExceptionWithMessage
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
	ret
	ENDP

; de = buffer position
; ix = this
; c <- value
; de <- buffer position after number
CLI_ParseNumber: PROC
	ld c,0
	ld hl,CLI_errorUnknownOption
Loop:
	ld a,(de)
	cp " " + 1
	ret c
	sub "0"
	call c,System_ThrowExceptionWithMessage
	cp 10
	call nc,System_ThrowExceptionWithMessage
	call Multiply10AndAdd
	inc de
	jr Loop
Multiply10AndAdd:
	ld b,a
	ld a,c
	ld c,b
	add a,a
	call c,System_ThrowExceptionWithMessage
	ld b,a
	add a,a
	call c,System_ThrowExceptionWithMessage
	add a,a
	call c,System_ThrowExceptionWithMessage
	add a,b
	call c,System_ThrowExceptionWithMessage
	add a,c
	call c,System_ThrowExceptionWithMessage
	ld c,a
	ret
	ENDP

; de = buffer position
; ix = this
; c <- slot ID
; de <- buffer position after slot ID
CLI_ParseSlot:
	ld c,0
	ld hl,CLI_errorParameter
	ld a,(de)
	sub "0"
	call c,System_ThrowExceptionWithMessage
	cp 4
	call nc,System_ThrowExceptionWithMessage
	ld c,a
	inc de
	ld a,(de)
	cp " " + 1
	ret c
	cp "-"
	call nz,System_ThrowExceptionWithMessage
	inc de
	ld a,(de)
	sub "0"
	call c,System_ThrowExceptionWithMessage
	cp 4
	call nc,System_ThrowExceptionWithMessage
	add a,a
	add a,a
	or 80H
	or c
	ld c,a
	inc de
	ld a,(de)
	cp " " + 1
	call nc,System_ThrowExceptionWithMessage
	ret

;
CLI_parametersEnvName:
	db "PARAMETERS",0
CLI_errorUnknownOption:
	db "Unknown command line option.",13,10,0
CLI_errorParameter:
	db "Missing or invalid command line option parameter.",13,10,0
CLI_errorMultiplePaths:
	db "Can not specify more than one file path.",13,10,0
CLI_errorDumpProgramVerify:
	db "Can not combine dump with program or verify.",13,10,0
CLI_errorNoSlot:
	db "No slot specified.",13,10,0
CLI_errorNoFile:
	db "No file specified.",13,10,0
CLI_messageUsage:
	db "Usage: asciixf [options] [<file.rom>]",13,10
	db 13,10
	db "Options:",13,10
	db "  /s  Slot number (required). Format: p or p-s.",13,10
	db "  /e  Erase flash ROM.",13,10
	db "  /p  Program flash ROM from file.",13,10
	db "  /v  Verify flash ROM with file.",13,10
	db "  /d  Dump flash ROM to file.",13,10
	db "  /i  Display flash ROM information.",13,10,0
