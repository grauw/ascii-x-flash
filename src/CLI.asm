;
; Command-line interface parser
;
CLI_BUFFER_SIZE: equ 255
CLI_FLAG_HELP: equ 0
CLI_FLAG_ERASE: equ 1
CLI_FLAG_CHIP: equ 2
CLI_FLAG_PROGRAM: equ 3
CLI_FLAG_VERIFY: equ 4
CLI_FLAG_DUMP: equ 5
CLI_FLAG_INFO: equ 6

CLI: MACRO
	flags:
		db 0
	path:
		dw 0
	fileStart:
		dd 0
	addressStart:
		dw 0
	addressEnd:
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
CLI_PrintBasicHelp:
	ld hl,CLI_messageBasicHelp
	jp System_PrintLn

; ix = this
CLI_PrintAdvancedHelp:
	ld hl,CLI_messageAdvancedHelp
	jp System_PrintLn

; ix = this
CLI_Parse: PROC
	call CLI_GetBuffer_DE
	ld iyl,e
	ld iyh,d
Loop:
	ld a,(iy)
	inc iy
	and a
	ret z
	cp "/"
	jr z,Option
	cp " " + 1
	jr nc,Path
	jr Loop
Option:
	call CLI_ParseOption
	jr Loop
Path:
	dec iy
	call CLI_ParsePath
	jr Loop
	ENDP

; ix = this
; iy = buffer position
; iy <- buffer position after path
CLI_ParsePath: PROC
	ld a,(ix + CLI.path)
	or (ix + CLI.path + 1)
	ld hl,CLI_errorMoreFiles
	call nz,System_ThrowExceptionWithMessage
	ld e,iyl
	ld d,iyh
	ld (ix + CLI.path),e
	ld (ix + CLI.path + 1),d
Loop:
	ld a,(iy)
	inc iy
	cp " " + 1
	jr nc,Loop
	dec iy
	and a
	ret z
	xor a
	ld (iy),a
	inc iy
	ret
	ENDP

; ix = this
; iy = buffer position
; iy <- buffer position after option
CLI_ParseOption: PROC
	ld a,(iy)
	inc iy
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
	cp "H"
	jr z,OptionHelp
	cp "F"
	jr z,OptionFile
	cp "A"
	jr z,OptionAddress
	jp CLI_ThrowUnknownOption
OptionSlot:
	call CLI_ParseSlot
	jp CLI_AddSlot
OptionErase:
	set CLI_FLAG_ERASE,(ix + CLI.flags)
	ld a,(iy)
	and 11011111B  ; upper-case
	cp "C"
	jp nz,CLI_ParseNoParameter
	inc iy
	set CLI_FLAG_CHIP,(ix + CLI.flags)
	jp CLI_ParseNoParameter
OptionProgram:
	set CLI_FLAG_PROGRAM,(ix + CLI.flags)
	ld a,(iy)
	inc iy
	cp "!"
	jp z,CLI_ParseNoParameter
	dec iy
	set CLI_FLAG_ERASE,(ix + CLI.flags)
	jp CLI_ParseNoParameter
OptionVerify:
	set CLI_FLAG_VERIFY,(ix + CLI.flags)
	jp CLI_ParseNoParameter
OptionDump:
	set CLI_FLAG_DUMP,(ix + CLI.flags)
	jp CLI_ParseNoParameter
OptionInfo:
	set CLI_FLAG_INFO,(ix + CLI.flags)
	jp CLI_ParseNoParameter
OptionHelp:
	set CLI_FLAG_HELP,(ix + CLI.flags)
	jp CLI_ParseNoParameter
OptionFile:
	ld a,(iy)
	inc iy
	and 11011111B  ; upper-case
	cp "S"
	jr z,OptionFileStart
	jp CLI_ThrowUnknownOption
OptionFileStart:
	call CLI_ParseHexNumber
	ld (ix + CLI.fileStart + 0),l
	ld (ix + CLI.fileStart + 1),h
	ld (ix + CLI.fileStart + 2),e
	ld (ix + CLI.fileStart + 3),d
	ret
OptionAddress:
	ld a,(iy)
	inc iy
	and 11011111B  ; upper-case
	cp "S"
	jr z,OptionAddressStart
	cp "E"
	jr z,OptionAddressEnd
	jp CLI_ThrowUnknownOption
OptionAddressStart:
	call CLI_ParseAddress
	ld (ix + CLI.addressStart + 0),l
	ld (ix + CLI.addressStart + 1),h
	ret
OptionAddressEnd:
	call CLI_ParseAddress
	ld a,l
	or h
	call z,CLI_ThrowAddress
	ld (ix + CLI.addressEnd + 0),l
	ld (ix + CLI.addressEnd + 1),h
	ret
	ENDP

; ix = this
; iy = buffer position
; iy <- buffer position after option
CLI_ParseNoParameter:
	ld a,(iy)
	cp " " + 1
	ret c
	jp CLI_ThrowUnknownOption

; ix = this
; iy = buffer position
; c <- slot ID
; iy <- buffer position after slot ID
CLI_ParseSlot:
	ld c,0
	ld a,(iy)
	inc iy
	sub "0"
	call c,CLI_ThrowParameter
	cp 4
	call nc,CLI_ThrowParameter
	ld c,a
	ld a,(iy)
	cp " " + 1
	ret c
	inc iy
	cp "-"
	call nz,CLI_ThrowParameter
	ld a,(iy)
	inc iy
	sub "0"
	call c,CLI_ThrowParameter
	cp 4
	call nc,CLI_ThrowParameter
	add a,a
	add a,a
	or 80H
	or c
	ld c,a
	ld a,(iy)
	cp " " + 1
	call nc,CLI_ThrowParameter
	ret

; ix = this
; iy = buffer position
; hl <- address / 1000H
; iy <- buffer position after address
CLI_ParseAddress:
	call CLI_ParseHexNumber
	ld a,l
	and a
	call nz,CLI_ThrowAddress
	ld a,h
	ld l,e
	ld h,d
	REPT 4
	add a,a
	adc hl,hl
	call c,CLI_ThrowAddress
	ENDM
	and a
	call nz,CLI_ThrowAddress
	ret

; ix = this
; iy = buffer position
; dehl <- number
; iy <- buffer position after number
CLI_ParseHexNumber: PROC
	ld hl,0
	ld de,0
	ld b,0
Loop:
	REPT 4
	add hl,hl
	rl e
	rl d
	call c,CLI_ThrowParameter
	ENDM
Separator:
	call Digit
	ld c,a
	add hl,bc
	ld a,(iy)
	cp " " + 1
	ret c
	cp "'"  ; digit separator
	jr nz,Loop
	inc iy
	jr Separator
Digit:
	ld a,(iy)
	inc iy
	sub "0"
	call c,CLI_ThrowParameter
	cp 10
	ret c
	add a,"0"
	and 11011111B  ; upper-case
	sub "A"
	call c,CLI_ThrowParameter
	cp 6
	call nc,CLI_ThrowParameter
	add a,10
	ret
	ENDP

; ix = this
CLI_Verify:
	call CLI_VerifyCombinations
	call CLI_VerifySlots
	call CLI_VerifyPath
	call CLI_VerifyAddress
	ret

; ix = this
CLI_VerifyCombinations:
	bit CLI_FLAG_DUMP,(ix + CLI.flags)
	ret z
	ld a,(ix + CLI.flags)
	and 1 << CLI_FLAG_ERASE | 1 << CLI_FLAG_PROGRAM | 1 << CLI_FLAG_VERIFY
	ld hl,CLI_errorDumpCombination
	call nz,System_ThrowExceptionWithMessage
	ret

; ix = this
CLI_VerifySlots:
	ld a,(ix + CLI.flags)
	and ~(1 << CLI_FLAG_HELP)
	ret z
	ld a,(ix + CLI.slotCount)
	cp 1
	ld hl,CLI_errorNoSlot
	call c,System_ThrowExceptionWithMessage
	ret z
	bit CLI_FLAG_DUMP,(ix + CLI.flags)
	ld hl,CLI_errorTooManySlots
	call nz,System_ThrowExceptionWithMessage
	ret

; ix = this
CLI_VerifyPath:
	ld a,(ix + CLI.flags)
	and 1 << CLI_FLAG_PROGRAM | 1 << CLI_FLAG_VERIFY | 1 << CLI_FLAG_DUMP
	ret z
	ld a,(ix + CLI.path + 0)
	or (ix + CLI.path + 1)
	ld hl,CLI_errorNoFile
	call z,System_ThrowExceptionWithMessage
	ret

; ix = this
CLI_VerifyAddress:
	ld e,(ix + CLI.addressStart + 0)
	ld d,(ix + CLI.addressStart + 1)
	ld hl,-ASCII16XMapper_MAX_ADDRESS
	add hl,de
	call c,CLI_ThrowAddress
	ex de,hl
	ld e,(ix + CLI.addressEnd + 0)
	ld d,(ix + CLI.addressEnd + 1)
	ld a,e
	or d
	ret z
	sbc hl,de
	call nc,CLI_ThrowAddress
	ld hl,-ASCII16XMapper_MAX_ADDRESS - 1
	add hl,de
	call c,CLI_ThrowAddress
	ret

CLI_ThrowUnknownOption:
	ld hl,CLI_errorUnknownOption
	jp System_ThrowExceptionWithMessage

CLI_ThrowParameter:
	ld hl,CLI_errorParameter
	jp System_ThrowExceptionWithMessage

CLI_ThrowAddress:
	ld hl,CLI_errorAddress
	jp System_ThrowExceptionWithMessage

;
CLI_parametersEnvName:
	db "PARAMETERS",0
CLI_errorUnknownOption:
	db "Unknown command line option.",0
CLI_errorParameter:
	db "Missing or invalid command line option parameter.",0
CLI_errorDumpCombination:
	db "Can not combine dump with other operations.",0
CLI_errorSlotExpansion:
	db "Specified slot expansion incorrect.",0
CLI_errorSameSlot:
	db "Same slot specified multiple times.",0
CLI_errorTooManySlots:
	db "Too many slots specified.",0
CLI_errorNoSlot:
	db "No slot specified.",0
CLI_errorMoreFiles:
	db "Can not specify more than one file.",0
CLI_errorNoFile:
	db "No file specified.",0
CLI_errorAddress:
	db "Invalid address specified.",0
CLI_messageBasicHelp:
	db "Usage: asciixf [options] [<file.rom>]",13,10
	db 13,10
	db "Options:",13,10
	db 13,10
	db "  /s  Slot number (required). Format: p or p-s.",13,10
	db "  /p  Program flash ROM from file. Erase first.",13,10
	db "  /v  Verify flash ROM with file.",13,10
	db "  /h  Show advanced options.",13,10
	db 13,10
	db "Example:",13,10
	db 13,10
	db "  asciixf /s2 /p /v example.rom",0
CLI_messageAdvancedHelp:
	db "Usage: asciixf [options] [<file.rom>]",13,10
	db 13,10
	db "Options:",13,10
	db 13,10
	db "  /s  Slot number (required). Format: p or p-s.",13,10
	db "      Specify up to 8 for bulk flashing.",13,10
	db "  /e  Erase flash ROM.",13,10
	db "  /ec Erase flash ROM (chip erase).",13,10
	db "  /p  Program flash ROM from file. Erase first.",13,10
	db "  /p! Program flash ROM from file. No erase.",13,10
	db "  /v  Verify flash ROM with file.",13,10
	db "  /d  Dump flash ROM to file.",13,10
	db "  /i  Display flash ROM information.",13,10
	db "  /h  Show advanced options.",13,10
	db "  /fs File start offset.",13,10
	db "  /as Address range start.",13,10
	db "  /ae Address range end (exclusive).",13,10
	db 13,10
	db "Addresses are hex bytes aligned to 1000H.",13,10
	db "They can contain a ' as digit separator.",13,10
	db 13,10
	db "Example:",13,10
	db 13,10
	db "  asciixf /s2 /p /v example.rom",0
