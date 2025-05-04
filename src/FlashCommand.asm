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
	exx
	FlashCommand_LoadUnlock_M
	FlashCommand_Unlock_M
	ld (hl),090H
	exx
	ret

; a <- 0: bad, 1: good, 2: bad status
FlashCommand_CheckContinuity: PROC
	call Check
	push af
	call ASCII16XMapper_Reset
	pop af
	ret
Check:
	ld hl,6000H + (5554ABH >> 14)
	ld (hl),l
	ld hl,7000H + (2AAB54H >> 14)
	ld (hl),l
	call FlashCommand_ClearStatus
	call FlashCommand_ReadStatus
	and 01H
	ld a,2
	ret nz
	ld a,0FFH
	ld (4000H + (5554ABH & 3FFFH)),a
	ld a,00H
	ld (8000H + (2AAB54H & 3FFFH)),a
	call FlashCommand_ReadStatus
	and 01H
	ret
	ENDP

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

; a = expected value
; hl = polling address
FlashCommand_CheckWait: PROC
	REPT 128
	cp (hl)
	ret z
	ENDM
	push af
	call FlashCommand_WaitDQ6
	jr nz,Error
	pop af
	cp (hl)
	ret z
Error:
	call FlashCommand_Reset
	ld hl,FlashCommand_errorOperation
	call System_ThrowExceptionWithMessage
	ENDP

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

; hl <- Command 1st cycle address
; de <- Command 2nd cycle address
FlashCommand_LoadUnlock_M: MACRO
	ld hl,4000H + FlashCommand_ADDRESS
	ld de,4000H + (FlashCommand_ADDRESS >> 1)
	ENDM

; hl = Command 1st cycle address
; de = Command 2nd cycle address
FlashCommand_Unlock_M: MACRO
	ld (hl),l
	ex de,hl
	ld (hl),l
	ex de,hl
	ENDM

FlashCommand_ChipErase:
	exx
	FlashCommand_LoadUnlock_M
	FlashCommand_Unlock_M
	ld (hl),080H
	FlashCommand_Unlock_M
	ld (hl),010H
	ld a,0FFH
	call FlashCommand_CheckWait
	exx
	ret

; hl = destination
; de = source
; bc = byte count
FlashCommand_ProgramByteBlock: PROC
	exx
	FlashCommand_LoadUnlock_M
	ld c,0A0H
	exx
	ld a,c
	dec bc
	inc b
	ld c,b
	ld b,a
	jr Program
Loop:
	call FlashCommand_CheckWait
	inc hl
Program:
	exx
	FlashCommand_Unlock_M
	ld (hl),c
	exx
	ld a,(de)
	ld (hl),a
	inc de
	djnz Loop
	dec c
	jr nz,Loop
	call FlashCommand_CheckWait
	inc hl
	ret
	ENDP

; hl = destination
; de = source
; bc = byte count
FlashCommand_ProgramBufferBlock: PROC
	exx
	FlashCommand_LoadUnlock_M
	exx
	jr Program
Loop:
	call FlashCommand_CheckWait
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
	jp Loop
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
