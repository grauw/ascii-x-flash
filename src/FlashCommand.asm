;
; FlashROM commands
;
FlashCommand_ADDRESS: equ 0AAAH

FlashCommand_CFIQuery:
	ld a,0
	ld (6000H),a
	ld a,98H
	ld (4000H + 0AAH),a
	ret

FlashCommand_AutoSelect:
	call FlashCommand_LoadAddressExx
	exx
	FlashCommand_Unlock_M
	ld (hl),090H
	exx
	ret

; c <- 0: bad, 1: good, 2: bad status
FlashCommand_CheckContinuity:
	ld c,2
	ld hl,6000H + (5554ABH >> 14)
	ld (hl),l
	ld hl,7000H + (2AAB54H >> 14)
	ld (hl),l
	call FlashCommand_ClearStatus
	call FlashCommand_ReadStatus
	bit 0,a
	jp nz,ASCII16XMapper_Reset  ; bad
	ld c,0
	ld a,0FFH
	ld (4000H + (5554ABH & 3FFFH)),a
	ld a,00H
	ld (8000H + (2AAB54H & 3FFFH)),a
	call FlashCommand_ReadStatus
	bit 0,a
	jp z,ASCII16XMapper_Reset  ; bad
	ld c,1
	jp ASCII16XMapper_Reset

; Modifies: a
FlashCommand_Reset:
	ld a,0F0H
	ld (4000H),a
	ret

; hl = polling address
; a <- status (DQ6 1: toggling, DQ2 1: toggling)
; f <- nz: error
FlashCommand_WaitDQ6:
	ld a,(hl)
	and 01000100B  ; DQ6 busy toggle, DQ2 erase toggle
	xor (hl)
	bit 6,a        ; DQ6 busy toggle
	ret z
	bit 5,a        ; DQ5 error
	jr z,FlashCommand_WaitDQ6
	ld a,(hl)
	and 01000100B  ; DQ6 busy toggle, DQ2 erase toggle
	xor (hl)
	bit 6,a        ; DQ6 busy toggle
	ret

; Modifies: a
FlashCommand_ClearStatus:
	ld a,71H
	ld (4000H + FlashCommand_ADDRESS),a
	ret

; a <- status
FlashCommand_ReadStatus:
	ld a,70H
	di
	ld (4000H + FlashCommand_ADDRESS),a
	ei
	ld a,(4000H)
	ret

; hl' <- Command 1st cycle address
; de' <- Command 2nd cycle address
FlashCommand_LoadAddressExx:
	exx
	ld hl,4000H + FlashCommand_ADDRESS
	ld de,4000H + (FlashCommand_ADDRESS >> 1)
	exx
	ret

; hl = Command 1st cycle address
; de = Command 2nd cycle address
FlashCommand_Unlock_M: MACRO
	ld (hl),l
	ex de,hl
	ld (hl),l
	ex de,hl
	ENDM

FlashCommand_ChipErase:
	call FlashCommand_LoadAddressExx
	exx
	FlashCommand_Unlock_M
	ld (hl),080H
	FlashCommand_Unlock_M
	ld (hl),010H
	call FlashCommand_WaitDQ6
	exx
	ret z
	call FlashCommand_Reset
	ld hl,FlashCommand_errorOperation
	call System_ThrowExceptionWithMessage

; hl = destination
; de = source
; bc = byte count
FlashCommand_ProgramByteBlock: PROC
	call FlashCommand_LoadAddressExx
	exx
	ld c,0A0H
	exx
	ld a,c
	dec bc
	inc b
	ld c,b
	ld b,a
	jr Program
Loop:
	inc hl
	djnz Program
	dec c
	ret z
Program:
	exx
	FlashCommand_Unlock_M
	ld (hl),c
	exx
	ld a,(de)
	ld (hl),a
	inc de
	REPT 36
	cp (hl)
	jr z,Loop
	ENDM
	call FlashCommand_WaitDQ6
	jr nz,Error
	dec de
	ld a,(de)
	inc de
	cp (hl)
	jp z,Loop
Error:
	call FlashCommand_Reset
	ld hl,FlashCommand_errorOperation
	call System_ThrowExceptionWithMessage
	ENDP

; hl = destination
; de = source
; bc = byte count
FlashCommand_ProgramBufferBlock: PROC
	call FlashCommand_LoadAddressExx
	jr Program
Loop:
	inc hl
	ld a,b
	or c
	ret z
Program:
	exx
	FlashCommand_Unlock_M
	exx
	ld (hl),025H
	inc b
	dec b
	dec bc
	jp nz,FullPage
	ld (hl),c
	inc c
	dec c
	jp z,LastByte
	ex de,hl
	ldir
	ex de,hl
	jp LastByte
FullPage:
	ld (hl),255
	ex de,hl
	REPT 255
	ldi
	ENDM
	ex de,hl
LastByte:
	ld a,(de)
	ld (hl),a
	ld (hl),029H
	inc de
	REPT 64
	cp (hl)
	jp z,Loop
	ENDM
	call FlashCommand_WaitDQ6
	jr nz,Error
	dec de
	ld a,(de)
	inc de
	cp (hl)
	jp z,Loop
Error:
	call FlashCommand_Reset
	ld hl,FlashCommand_errorOperation
	call System_ThrowExceptionWithMessage
	ENDP

; hl = source
; de = destination
; bc = byte count
; f <- nz: not equal
FlashCommand_VerifyBlock: PROC
Loop:
	ld a,(de)
	inc de
	cpi
	ret nz
	jp pe,Loop
	ret
	ENDP

; hl = source
; de = destination
; bc = byte count
FlashCommand_ReadBlock:
	equ System_FastLDIR

;
FlashCommand_errorOperation:
	db "Operation failed.",0
