;
; FlashROM device
;
FlashDevice_BLOCK_SIZE: equ 1000H

FlashDevice: MACRO
	super:
		SlotDevice
	x8x16:
		db 0
	manufacturerID:
		db 0
	deviceID:
		db 0,0,0
	continuity:
		db 0
	capacity:
		dw 0
	cfiQuery:
		CFIQuery
	_size:
	ENDM

; a = slot ID
; ix = this
FlashDevice_Construct:
	call SlotDevice_Construct
	call SlotDevice_Select
	call FlashDevice_ConstructCFIQuery
	call FlashDevice_ConstructManufacturerDeviceID
	call FlashDevice_ConstructContinuity
	call FlashDevice_ConstructCapacity
	ret

; ix = this
FlashDevice_ConstructCFIQuery:
	call FlashCommand_CFIQuery
	ld a,(4010H)
	sub "Q"
	sub 1
	sbc a,a
	cpl
	and 1
	ld (ix + FlashDevice.x8x16),a
	ld hl,4000H
	push ix
	call FlashDevice_GetCFIQuery
	call CFIQuery_Construct
	pop ix
	jp FlashCommand_Reset

; ix = this
FlashDevice_ConstructManufacturerDeviceID:
	call FlashCommand_AutoSelect
	ld a,(4000H + 00H)
	ld (ix + FlashDevice.manufacturerID),a
	ld a,(4000H + 02H)
	ld (ix + FlashDevice.deviceID + 0),a
	ld a,(4000H + 1CH)
	ld (ix + FlashDevice.deviceID + 1),a
	ld a,(4000H + 1EH)
	ld (ix + FlashDevice.deviceID + 2),a
	jp FlashCommand_Reset

; ix = this
FlashDevice_ConstructContinuity:
	ld (ix + FlashDevice.continuity),1
	call FlashDevice_SupportsContinuity
	ret nz
	call FlashCommand_CheckContinuity
	ld (ix + FlashDevice.continuity),c
	ret

; ix = this
FlashDevice_ConstructCapacity:
	push ix
	call FlashDevice_GetCFIQuery
	call CFIQuery_GetCapacity
	pop ix
	ld (ix + FlashDevice.capacity + 0),l
	ld (ix + FlashDevice.capacity + 1),h
	ret

; ix = this
; ix <- CFIQuery
; Modifies: de
FlashDevice_GetCFIQuery:
	ld de,FlashDevice.cfiQuery
	add ix,de
	ret

; ix = this
; f <- nz: not flash
FlashDevice_IsFlash:
	push ix
	call FlashDevice_GetCFIQuery
	call CFIQuery_HasSignature
	pop ix
	ret

; ix = this
; f <- nz: not programmable
FlashDevice_IsProgrammable:
	call FlashDevice_IsFlash
	ret nz
	ld a,(ix + FlashDevice.continuity)
	cp 1
	ret

; de = physical address / 1000H
; ix = this
; f <- c: out of range
; Modifies: a
FlashDevice_CheckCapacity: PROC
	ld a,(ix + FlashDevice.capacity + 1)
	sub 1
	jr c,CheckLSB
	sub d
	ret
CheckLSB:
	ld a,(ix + FlashDevice.capacity + 0)
	sbc a,e
	ret
	ENDP

; a = nz: verbose
; ix = this
FlashDevice_Print: PROC
	push af
	call FlashDevice_PrintQueryingSlot
	call System_PrintCrLf
	call FlashDevice_IsFlash
	ld hl,FlashDevice_messageNotFlash
	call nz,System_PrintLn
	call nz,System_PrintCrLf
	call FlashDevice_PrintManufacturerID
	call FlashDevice_PrintDeviceID
	call System_PrintCrLf
	pop af
	push ix
	call FlashDevice_GetCFIQuery
	call PrintCFI
	pop ix
	call System_PrintCrLf
	call FlashDevice_SupportsContinuity
	ret nz
	call FlashDevice_PrintContinuity
	call System_PrintCrLf
	ret
PrintCFI:
	and a
	jr nz,Verbose
	call CFIQuery_PrintDeviceSize
	call CFIQuery_PrintMaxBufferWrite
	ret
Verbose:
	call CFIQuery_Print
	call System_PrintCrLf
	call CFIQuery_PrintArray
	ret
	ENDP

; ix = this
FlashDevice_PrintQueryingSlot:
	ld hl,FlashDevice_messageQuery
	call System_Print
	call Slot_Print
	ld hl,FlashDevice_messageQuery2
	call System_PrintLn
	ret

; ix = this
FlashDevice_PrintManufacturerID:
	ld hl,FlashDevice_messageManufacturerID
	call System_Print
	ld a,(ix + FlashDevice.manufacturerID)
	call System_PrintHexA
	call System_PrintCrLf
	ret

; ix = this
FlashDevice_PrintDeviceID:
	ld hl,FlashDevice_messageDeviceID
	call System_Print
	ld a,(ix + FlashDevice.deviceID + 0)
	call System_PrintHexA
	ld a," "
	call System_PrintChar
	ld a,(ix + FlashDevice.deviceID + 1)
	call System_PrintHexA
	ld a," "
	call System_PrintChar
	ld a,(ix + FlashDevice.deviceID + 2)
	call System_PrintHexA
	call System_PrintCrLf
	ret

; Continuity check is only supported by Infineon S29GL064S.
; Manufacturer ID: 01
; Device ID: 7E1000 (04), 7E1001 (03), 7E0C01 (01, 02, V1, V2), 7E1301 (06, 07, V6, V7)
; ix = this
; f <- z: supported
FlashDevice_SupportsContinuity: PROC
	ld a,(ix + FlashDevice.manufacturerID)
	cp 01H
	ret nz
	ld a,(ix + FlashDevice.deviceID + 0)
	cp 7EH
	ret nz
	ld a,(ix + FlashDevice.deviceID + 1)
	cp 0CH
	jr z,Check01
	cp 13H
	jr z,Check01
	cp 10H
	ret nz
	ld a,(ix + FlashDevice.deviceID + 2)
	cp 00H
	ret z
Check01:
	ld a,(ix + FlashDevice.deviceID + 2)
	cp 01H
	ret
	ENDP

; ix = this
FlashDevice_PrintContinuity:
	ld a,(ix + FlashDevice.continuity)
	cp 1
	ld hl,FlashDevice_messageContinuityOk
	jp z,System_PrintLn
	cp 0
	ld hl,FlashDevice_messageContinuityBad
	jp z,System_PrintLn
	ld hl,FlashDevice_messageContinuityBadStatus
	jp System_PrintLn

; ix = this
FlashDevice_ChipErase:
	call SlotDevice_Select
	di
	call FlashCommand_ChipErase
	ei
	ret

; hl = source
; de = destination / 1000H
; bc = byte count (<= 1000H)
; ix = this
FlashDevice_ProgramBlock: PROC
	ld a,b
	or c
	ret z
	call FlashDevice_CheckCapacity
	ret c
	call SlotDevice_Select
	ex de,hl
	call ASCII16XMapper_SelectAddress
	di
	call Program
	ei
	jp ASCII16XMapper_Reset
Program:
	ld a,(ix + FlashDevice.cfiQuery.maxBufferWrite)
	cp 8
	jp nc,FlashCommand_ProgramBufferBlock
	jp FlashCommand_ProgramByteBlock
	ENDP

; hl = source
; de = destination / 1000H
; bc = byte count (<= 1000H)
; ix = this
; f <- nz: not equal
FlashDevice_VerifyBlock: PROC
	ld a,b
	or c
	ret z
	call FlashDevice_CheckCapacity
	jr c,OutOfRange
	call SlotDevice_Select
	ex de,hl
	call ASCII16XMapper_SelectAddress
	ex de,hl
	call FlashCommand_VerifyBlock
	jp ASCII16XMapper_Reset
OutOfRange:
	xor a
	ret
	ENDP

; hl = source / 1000H
; de = destination
; bc = byte count (<= 1000H)
; ix = this
FlashDevice_ReadBlock:
	ld a,b
	or c
	ret z
	call SlotDevice_Select
	call ASCII16XMapper_SelectAddress
	call FlashCommand_ReadBlock
	jp ASCII16XMapper_Reset

;
FlashDevice_messageQuery:
	db "Querying slot ",0
FlashDevice_messageQuery2:
	db " for FlashROM information:",0
FlashDevice_messageNotFlash:
	db "Warning: Not a FlashROM!",0
FlashDevice_messageManufacturerID:
	db "Manufacturer ID: ",0
FlashDevice_messageDeviceID:
	db "Device ID: ",0
FlashDevice_messageContinuityOk:
	db "Continuity check: OK",0
FlashDevice_messageContinuityBad:
	db "Continuity check: BAD. Check pins for bridges.",0
FlashDevice_messageContinuityBadStatus:
	db "Continuity check: BAD status.",0
