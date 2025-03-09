;
; Command-line interface parser
;
CLI_BUFFER_SIZE: equ 255
CLI_MAX_SLOTS: equ 4

CLI: MACRO
	fileInfoBlockReference:
		dw 0
	slot:
		db 0FFH
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
	fileInfoBlock:
		FileInfoBlock
	_size:
	ENDM

; ix = this
; ix <- this
CLI_Construct:
	jr CLI_Parse

; ix = this
; ix <- this
CLI_Destruct:
	ret

; ix = this
; de <- file info block
CLI_GetFileInfoBlock_DE:
	ld e,(ix + CLI.fileInfoBlockReference)
	ld d,(ix + CLI.fileInfoBlockReference + 1)
	ld a,e
	or d
	ret

; ix = this
; ix <- file info block
CLI_GetFileInfoBlock:
	call CLI_GetFileInfoBlock_DE
	ld ixl,e
	ld ixh,d
	ret

; ix = this
CLI_Parse: PROC
	ld de,CLI_buffer
	ld hl,CLI_parametersEnvName
	ld b,CLI_BUFFER_SIZE
	call DOS_GetEnvironmentItem
	call nz,System_ThrowException
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
	call CLI_ParseOption
	jr Loop
Path:
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
	ld hl,CLI_unknownOptionError
	call System_ThrowExceptionWithMessage
OptionSlot:
	inc de
	call CLI_ParseSlot
	ld (ix + CLI.slot),c
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
	ld hl,CLI_unknownOptionError
	call System_ThrowExceptionWithMessage
	ENDP

; de = buffer position
; ix = this
CLI_ParsePath: PROC
	ld a,(ix + CLI.fileInfoBlockReference)
	or (ix + CLI.fileInfoBlockReference + 1)
	ld hl,CLI_multiplePathsError
	call nz,System_ThrowExceptionWithMessage
	push de
Loop:
	ld a,(de)
	inc de
	cp " " + 1
	jr nc,Loop
	dec de
	and a
	jr z,FindFile
	xor a
	ld (de),a
	inc de
FindFile:
	pop hl
	push de
	ex de,hl
	push ix
	ld bc,CLI.fileInfoBlock
	add ix,bc
	ld b,0
	call DOS_FindFirstEntry
	call DOS_TerminateIfError
	ld e,ixl
	ld d,ixh
	pop ix
	ld (ix + CLI.fileInfoBlockReference),e
	ld (ix + CLI.fileInfoBlockReference + 1),d
	pop de
	ret
	ENDP

; de = buffer position
; ix = this
; c <- value
; de <- buffer position after number
CLI_ParseNumber: PROC
	ld c,0
	ld hl,CLI_unknownOptionError
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
	ld hl,CLI_parameterError
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

CLI_unknownOptionError:
	db "Unknown command line option.",13,10,0

CLI_parameterError:
	db "Missing or invalid command line option parameter.",13,10,0

CLI_multiplePathsError:
	db "Can not specify more than one file path.",13,10,0

CLI_buffer:
	ds CLI_BUFFER_SIZE
