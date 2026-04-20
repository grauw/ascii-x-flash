;
; FlashROM commands
;
FlashCommand_ADDRESS: equ 0AAAH

; hl <- Command 1st cycle address
; de <- Command 2nd cycle address
FlashCommand_LoadUnlock_M: MACRO
	ld hl,4000H | FlashCommand_ADDRESS
	ld de,4000H | FlashCommand_ADDRESS >> 1
	ENDM

; hl = Command 1st cycle address
; de = Command 2nd cycle address
FlashCommand_Unlock_M: MACRO
	ld (hl),l
	ex de,hl
	ld (hl),l
	ex de,hl
	ENDM

; Modifies: a
FlashCommand_Reset:
	ld a,0F0H
	ld (4000H),a
	ret

; Modifies: a
FlashCommand_AbortReset:
	ld a,FlashCommand_ADDRESS
	ld (4000H | FlashCommand_ADDRESS),a
	ld a,FlashCommand_ADDRESS >> 1
	ld (4000H | FlashCommand_ADDRESS >> 1),a
	ld a,0F0H
	ld (4000H | FlashCommand_ADDRESS),a
	ret

; Modifies: a
FlashCommand_CFIQuery:
	ld a,0
	ld (6000H),a
	ld a,98H
	ld (4000H | 0AAH),a
	ret

FlashCommand_AutoSelect:
	exx
	FlashCommand_LoadUnlock_M
	FlashCommand_Unlock_M
	ld (hl),090H
	exx
	ret

; f <- nz: error
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
; f <- nz: error
FlashCommand_SectorErase:
	exx
	FlashCommand_LoadUnlock_M
	FlashCommand_Unlock_M
	ld (hl),080H
	FlashCommand_Unlock_M
	exx
	ld (hl),030H
	ld a,0FFH
	call FlashCommand_CheckWait
	ret

; hl = destination
; de = source
; bc = byte count
; f <- nz: error
; hl, de, bc <- updated
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
	call Program
	ret z
	ld a,b
	ld b,c
	ld c,a
	cp 1
	ret c
	dec b
	and a
	ret
Loop:
	call FlashCommand_CheckWait
	inc hl
	ret nz
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

; a = write buffer size - 1
; hl = destination (buffer page aligned)
; de = source
; bc = byte count (multiple of buffer size)
; f <- nz: error
; hl, de, bc <- updated
FlashCommand_ProgramBufferBlock: PROC
	push ix
	exx
	ld ix,Write
	ld c,a
	cpl
	ld e,a
	ld d,0
	add ix,de
	add ix,de
	FlashCommand_LoadUnlock_M
	exx
	call Program
	pop ix
	ret
Loop:
	call FlashCommand_CheckWait
	inc hl
	ret nz
Program:
	exx
	FlashCommand_Unlock_M
	ld a,c
	exx
	ld (hl),025H
	ld (hl),a
	ex de,hl
	jp ix
Write:
	REPT 255
	ldi
	ENDM
	ld a,(hl)
	ldi
	ex de,hl
	dec hl
	ld (hl),029H
	jp pe,Loop
	call FlashCommand_CheckWait
	inc hl
	ret
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

; a = expected value
; hl = polling address
; f <- nz: error
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
	ret
Error:
	bit 1,a  ; DQ1 abort
	jr nz,Abort
	call FlashCommand_Reset
	pop af
	ret
Abort:
	call FlashCommand_AbortReset
	pop af
	ret
	ENDP

; hl = polling address
; a <- status (DQ6 1: toggling, DQ2 1: toggling, DQ5: error, DQ1: abort)
; f <- nz: error
FlashCommand_WaitDQ6:
	ld a,(hl)
	and 01000100B  ; DQ6 busy toggle, DQ2 erase toggle
	xor (hl)
	bit 6,a        ; DQ6 busy toggle
	ret z
	and 00100010B  ; DQ5 error, DQ1 abort
	jr z,FlashCommand_WaitDQ6
	ld a,(hl)
	and 01000100B  ; DQ6 busy toggle, DQ2 erase toggle
	xor (hl)
	bit 6,a        ; DQ6 busy toggle
	ret

; a <- 0: bad, 1: good, 2: bad status
FlashCommand_CheckContinuity: PROC
	call Check
	push af
	call ASCII16XMapper_Reset
	pop af
	ret
Check:
	ld hl,6000H | 5554ABH >> 14
	ld (hl),l
	ld hl,7000H | 2AAB54H >> 14
	ld (hl),l
	call FlashCommand_ClearExtendedStatus
	call FlashCommand_ReadExtendedStatus
	and 01H
	ld a,2
	ret nz
	ld a,0FFH
	ld (4000H | 5554ABH & 3FFFH),a
	ld a,00H
	ld (8000H | 2AAB54H & 3FFFH),a
	call FlashCommand_ReadExtendedStatus
	and 01H
	ret
	ENDP

; Modifies: a
FlashCommand_ClearExtendedStatus:
	ld a,71H
	ld (4000H | FlashCommand_ADDRESS),a
	ret

; a <- status
FlashCommand_ReadExtendedStatus:
	ld a,70H
	di
	ld (4000H | FlashCommand_ADDRESS),a
	ei
	ld a,(4000H)
	ret
