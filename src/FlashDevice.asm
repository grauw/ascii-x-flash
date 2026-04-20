;
; FlashROM device
;
FlashDevice_BLOCK_SIZE: equ 1000H
FlashDevice_CAPABILITY_FLASH: equ 0

FlashDevice: MACRO
	super:
		SlotDevice
	capabilities:
		db 0
	continuity:
		db 0
	capacity:
		dw 0
	bufferPageMask:
		db 0
	autoSelect:
		AutoSelect
	cfiQuery:
		CFIQuery
	_size:
	ENDM

; a = slot ID
; ix = this
FlashDevice_Construct:
	call SlotDevice_Construct
	call SlotDevice_Select
	call ASCII16XMapper_Reset
	call FlashDevice_ConstructCFIQuery
	call FlashDevice_ConstructAutoSelect
	ld a,(ix + FlashDevice.autoSelect.manufacturer)
	and a
	ret pe  ; not a valid manufacturer ID
	push ix
	call FlashDevice_GetCFIQuery
	call CFIQuery_HasSignature
	pop ix
	ret nz  ; no CFI
	call FlashDevice_ConstructCapabilities
	call FlashDevice_ConstructContinuity
	call FlashDevice_ConstructCapacity
	call FlashDevice_ConstructBufferPageMask
	ret

; ix = this
FlashDevice_ConstructCFIQuery:
	call FlashCommand_CFIQuery
	ld hl,4000H
	push ix
	call FlashDevice_GetCFIQuery
	call CFIQuery_Construct
	pop ix
	jp FlashCommand_Reset

; ix = this
FlashDevice_ConstructAutoSelect:
	call FlashCommand_AutoSelect
	ld hl,4000H
	push ix
	call FlashDevice_GetAutoSelect
	call AutoSelect_Construct
	pop ix
	jp FlashCommand_Reset

; ix = this
FlashDevice_ConstructCapabilities:
	set FlashDevice_CAPABILITY_FLASH,(ix + FlashDevice.capabilities)
	ret

; ix = this
FlashDevice_ConstructContinuity:
	call FlashDevice_SupportsContinuity
	ld a,1
	call z,FlashCommand_CheckContinuity
	ld (ix + FlashDevice.continuity),a
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
FlashDevice_ConstructBufferPageMask:
	push ix
	call FlashDevice_GetCFIQuery
	call CFIQuery_GetBufferPageMask
	pop ix
	ld (ix + FlashDevice.bufferPageMask),0
	cp 32 - 1
	ret c
	ld (ix + FlashDevice.bufferPageMask),a
	ret

; ix = this
; ix <- auto select
; Modifies: de
FlashDevice_GetAutoSelect:
	ld de,FlashDevice.autoSelect
	add ix,de
	ret

; ix = this
; ix <- CFIQuery
; Modifies: de
FlashDevice_GetCFIQuery:
	ld de,FlashDevice.cfiQuery
	add ix,de
	ret

; de = physical address / 1000H
; ix = this
; f <- c: exceeds capacity
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
	call FlashDevice_PrintSlotInfo
	call FlashDevice_SupportsContinuity
	call z,FlashDevice_PrintContinuity
	push ix
	call FlashDevice_GetAutoSelect
	call AutoSelect_Print
	pop ix
	pop af
	push ix
	call PrintCFIQuery
	pop ix
	bit FlashDevice_CAPABILITY_FLASH,(ix + FlashDevice.capabilities)
	ld hl,FlashDevice_messageNotFlash
	call z,System_PrintLn
	jp System_PrintCrLf
PrintCFIQuery:
	ld b,a
	call FlashDevice_GetCFIQuery
	call CFIQuery_HasSignature
	ret nz
	ld a,b
	and a
	jp nz,CFIQuery_Print
	jp CFIQuery_PrintDeviceSize
	ENDP

; ix = this
FlashDevice_PrintSlotInfo:
	ld hl,FlashDevice_messageSlotInfo
	call System_Print
	call Slot_Print
	ld hl,FlashDevice_messageSlotInfo2
	call System_PrintLn
	ret

; Continuity check is only supported by Infineon S29GL064S and S29GL-T devices.
; Manufacturer ID: 01
; Device ID: 7E1000 (04), 7E1001 (03), 7E0C01 (01, 02, V1, V2), 7E1301 (06, 07, V6, V7), 7E2301 (GL512T)
; ix = this
; f <- z: supported
FlashDevice_SupportsContinuity: PROC
	ld a,(ix + FlashDevice.autoSelect.manufacturer)
	cp 01H
	ret nz
	ld a,(ix + FlashDevice.autoSelect.device1)
	cp 7EH
	ret nz
	ld a,(ix + FlashDevice.autoSelect.device2)
	cp 0CH
	jr z,Check01
	cp 13H
	jr z,Check01
	cp 23H
	jr z,Check01
	cp 10H
	ret nz
	ld a,(ix + FlashDevice.autoSelect.device3)
	cp 00H
	ret z
Check01:
	ld a,(ix + FlashDevice.autoSelect.device3)
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
; f <- nz: error
FlashDevice_ChipErase:
	call SlotDevice_Select
	di
	call FlashCommand_ChipErase
	ei
	ret

; de = destination / 1000H
; ix = this
; f <- nz: error
FlashDevice_SectorErase:
	call SlotDevice_Select
	ex de,hl
	call ASCII16XMapper_SelectAddress
	di
	call FlashCommand_SectorErase
	ei
	jp ASCII16XMapper_Reset

; hl = source
; de = destination / 1000H
; bc = byte count (<= 1000H)
; ix = this
; f <- nz: error
FlashDevice_ProgramBlock: PROC
	ld a,b
	or c
	ret z
	call SlotDevice_Select
	ex de,hl
	call ASCII16XMapper_SelectAddress
	di
	call Program
	ei
	jp ASCII16XMapper_Reset
Program:
	ld a,c
	and (ix + FlashDevice.bufferPageMask)
	jp nz,FlashCommand_ProgramByteBlock
	ld a,(ix + FlashDevice.bufferPageMask)
	and a
	jp z,FlashCommand_ProgramByteBlock
	jp FlashCommand_ProgramBufferBlock
	ENDP

; hl = source
; de = destination / 1000H
; bc = byte count (<= 1000H)
; ix = this
; f <- nz: not equal
FlashDevice_VerifyBlock:
	ld a,b
	or c
	ret z
	call SlotDevice_Select
	ex de,hl
	call ASCII16XMapper_SelectAddress
	ex de,hl
	call FlashCommand_VerifyBlock
	jp ASCII16XMapper_Reset

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
FlashDevice_messageSlotInfo:
	db "Slot ",0
FlashDevice_messageSlotInfo2:
	db " FlashROM information:",0
FlashDevice_messageNotFlash:
	db "- Warning: Not a FlashROM!",0
FlashDevice_messageContinuityOk:
	db "- Continuity: OK",0
FlashDevice_messageContinuityBad:
	db "- Continuity: BAD. Check pins for bridges.",0
FlashDevice_messageContinuityBadStatus:
	db "- Continuity: BAD status.",0
