;
; FlashROM
;
FlashROM_COMMAND_ADDRESS: equ 0AAAH

FlashROM: MACRO
	x8x16:
		db 0
	manufacturerID:
		db 0
	deviceID:
		db 0,0,0
	continuity:
		db 0
	cfiQuery:
		CFIQuery
	ENDM

; ix = this
FlashROM_Construct:
	call FlashROM_ConstructCFIQuery
	call FlashROM_ConstructManufacturerDeviceID
	call FlashROM_CheckContinuity
	ret

; ix = this
FlashROM_ConstructCFIQuery: PROC
	ld a,0
	ld (6000H),a
	ld a,98H
	ld (4000H + 0AAH),a
	ld a,(4010H)
	sub "Q"
	sub 1
	sbc a,a
	cpl
	and 1
	ld (ix + FlashROM.x8x16),a
	ld hl,4000H
	push ix
	call FlashROM_GetCFIQuery
	call CFIQuery_Construct
	pop ix
	call FlashROM_Reset
	ret
	ENDP

; ix = this
FlashROM_ConstructManufacturerDeviceID: PROC
	ld a,90H
	call FlashROM_EnterCommand
	ld a,(4000H + 00H)
	ld (ix + FlashROM.manufacturerID),a
	ld a,(4000H + 02H)
	ld (ix + FlashROM.deviceID + 0),a
	ld a,(4000H + 1CH)
	ld (ix + FlashROM.deviceID + 1),a
	ld a,(4000H + 1EH)
	ld (ix + FlashROM.deviceID + 2),a
	call FlashROM_Reset
	ret
	ENDP

; ix = this
; ix <- CFIQuery
; Modifies: de
FlashROM_GetCFIQuery:
	ld de,FlashROM.cfiQuery
	add ix,de
	ret

; ix = this
; f <- nz: not flash
FlashROM_IsFlash:
	push ix
	call FlashROM_GetCFIQuery
	call CFIQuery_HasSignature
	pop ix
	ret

; ix = this
; f <- nz: not programmable
FlashROM_IsProgrammable:
	call FlashROM_IsFlash
	ret nz
	ld a,(ix + FlashROM.continuity)
	cp 1
	ret

; ix = this
FlashROM_Print:
	call FlashROM_IsFlash
	ld hl,FlashROM_messageNotFlash
	call nz,System_Print
	call FlashROM_PrintManufacturerID
	call FlashROM_PrintDeviceID
	call System_PrintCrLf
	push ix
	call FlashROM_GetCFIQuery
	call CFIQuery_PrintDeviceSize
	call CFIQuery_PrintMaxBufferWrite
	pop ix
	call System_PrintCrLf
	call FlashROM_PrintContinuity
	ret

; ix = this
FlashROM_PrintVerbose:
	call FlashROM_IsFlash
	ld hl,FlashROM_messageNotFlash
	call nz,System_Print
	call FlashROM_PrintManufacturerID
	call FlashROM_PrintDeviceID
	call System_PrintCrLf
	push ix
	call FlashROM_GetCFIQuery
	call CFIQuery_Print
	call System_PrintCrLf
	call CFIQuery_PrintArray
	pop ix
	call System_PrintCrLf
	call FlashROM_PrintContinuity
	ret

; ix = this
FlashROM_PrintManufacturerID:
	ld hl,FlashROM_messageManufacturerID
	call System_Print
	ld a,(ix + FlashROM.manufacturerID)
	call System_PrintHexA
	call System_PrintCrLf
	ret

; ix = this
FlashROM_PrintDeviceID:
	ld hl,FlashROM_messageDeviceID
	call System_Print
	ld a,(ix + FlashROM.deviceID + 0)
	call System_PrintHexA
	ld a," "
	call System_PrintChar
	ld a,(ix + FlashROM.deviceID + 1)
	call System_PrintHexA
	ld a," "
	call System_PrintChar
	ld a,(ix + FlashROM.deviceID + 2)
	call System_PrintHexA
	call System_PrintCrLf
	ret

; Continuity check is only supported by Infineon S29GL064S.
; Manufacturer ID: 01
; Device ID: 7E1000 (04), 7E1001 (03), 7E0C01 (01, 02, V1, V2), 7E1301 (06, 07, V6, V7)
; ix = this
; f <- z: supported
FlashROM_SupportsContinuity: PROC
	ld a,(ix + FlashROM.manufacturerID)
	cp 01H
	ret nz
	ld a,(ix + FlashROM.deviceID + 0)
	cp 7EH
	ret nz
	ld a,(ix + FlashROM.deviceID + 1)
	cp 0CH
	jr z,Check01
	cp 13H
	jr z,Check01
	cp 10H
	ret nz
	ld a,(ix + FlashROM.deviceID + 2)
	cp 00H
	ret z
Check01:
	ld a,(ix + FlashROM.deviceID + 2)
	cp 01H
	ret
	ENDP

; ix = this
FlashROM_CheckContinuity: PROC
	ld (ix + FlashROM.continuity),1
	call FlashROM_SupportsContinuity
	ret nz
	ld (ix + FlashROM.continuity),2
	ld hl,6000H + (5554ABH >> 14)
	ld (hl),l
	ld hl,7000H + (2AAB54H >> 14)
	ld (hl),l
	call FlashROM_ClearStatus
	call FlashROM_ReadStatus
	bit 0,a
	jr nz,Bad
	ld (ix + FlashROM.continuity),0
	ld a,0FFH
	ld (4000H + (5554ABH & 3FFFH)),a
	ld a,00H
	ld (8000H + (2AAB54H & 3FFFH)),a
	call FlashROM_ReadStatus
	bit 0,a
	jr z,Bad
	ld (ix + FlashROM.continuity),1
Bad:
	ld a,0
	ld (6000H),a
	ld a,0
	ld (7000H),a
	ret
	ENDP

; ix = this
FlashROM_PrintContinuity:
	call FlashROM_SupportsContinuity
	ret nz
	ld a,(ix + FlashROM.continuity)
	cp 1
	ld hl,FlashROM_messageContinuityOk
	jp z,System_Print
	cp 0
	ld hl,FlashROM_messageContinuityBad
	jp z,System_Print
	ld hl,FlashROM_messageContinuityBadStatus
	jp System_Print

; Modifies: a
FlashROM_Reset:
	ld a,0F0H
	ld (4000H),a
	ret

; Modifies: a
FlashROM_ClearStatus:
	ld a,71H
	ld (4000H + FlashROM_COMMAND_ADDRESS),a
	ret

; a <- status
FlashROM_ReadStatus:
	ld a,70H
	di
	ld (4000H + FlashROM_COMMAND_ADDRESS),a
	ei
	ld a,(4000H)
	ret

; Modifies: a
FlashROM_EnterCommandMode:
	ld a,FlashROM_COMMAND_ADDRESS
	ld (4000H + FlashROM_COMMAND_ADDRESS),a
	ld a,FlashROM_COMMAND_ADDRESS >> 1
	ld (4000H + (FlashROM_COMMAND_ADDRESS >> 1)),a
	ret

; a = command number
FlashROM_EnterCommand:
	push af
	call FlashROM_EnterCommandMode
	pop af
	ld (4000H + FlashROM_COMMAND_ADDRESS),a
	ret

FlashROM_ChipErase: PROC
	ld a,80H
	call FlashROM_EnterCommand
	ld a,10H
	call FlashROM_EnterCommand
	ld a,0FFH
	ld hl,4000H
Loop:
	cp (hl)
	ret z
	jr Loop
	ENDP

; a = value
; hl = address
; Modifies: f
FlashROM_Program: PROC
	push af
	ld a,0A0H
	call FlashROM_EnterCommand
	pop af
	ld (hl),a
Loop:
	cp (hl)
	ret z
	jr Loop
	ENDP

; hl = source
; de = destination / 1000H
; bc = byte count (<= 1000H)
FlashROM_ProgramBlock: PROC
	ld a,b
	or c
	ret z
	ex de,hl
	push de
	call FlashROM_GetMapperAddress
	ld (de),a
	pop de
	ld a,c
	dec bc
	inc b
	ld c,b
	ld b,a
Loop:
	ld a,(de)
	call FlashROM_Program
	inc de
	inc hl
	djnz Loop
	dec c
	jr nz,Loop
	ld a,0
	ld (6000H),a
	ld a,0
	ld (7000H),a
	ret
	ENDP

; hl = source
; de = destination
; bc = byte count
FlashROM_ProgramBuffered: PROC
	ex de,hl
Loop:
	ld a,b
	or c
	ret z
	call FlashROM_EnterCommandMode
	ld (hl),25H
	inc b
	dec b
	dec bc
	jp nz,FullPage
	ld (hl),c
	inc c
	dec c
	jr z,LastByte
	ex de,hl
	ldir
	ex de,hl
LastByte:
	ld a,(de)
	ld (hl),a
	ld (hl),29H
PollLoop:
	cp (hl)
	jr nz,PollLoop
	inc hl
	inc de
	jp Loop
FullPage:
	ld (hl),255
	ex de,hl
	REPT 255
	ldi
	ENDM
	ex de,hl
	jp LastByte
	ENDP

; hl = source
; de = destination / 1000H
; bc = byte count (<= 1000H)
FlashROM_ProgramBufferedBlock: PROC
	ex de,hl
	push de
	call FlashROM_GetMapperAddress
	ld (de),a
	pop de
	ex de,hl
	call FlashROM_ProgramBuffered
	ld a,0
	ld (6000H),a
	ld a,0
	ld (7000H),a
	ret
	ENDP

; hl = source
; de = destination / 1000H
; bc = byte count (<= 1000H)
; f <- nz: not equal
FlashROM_VerifyBlock: PROC
	ex de,hl
	push de
	call FlashROM_GetMapperAddress
	ld (de),a
	pop de
	ex de,hl
	call Verify
	ld a,0
	ld (6000H),a
	ld a,0
	ld (7000H),a
	ret
; hl = source
; de = destination
; bc = byte count
; f <- nz: not equal
Verify:
	ld a,(de)
	inc de
	cpi
	ret nz
	jp pe,Verify
	ret
	ENDP

; hl = physical address / 1000H
; hl <- logical address
; de <- bank switch address + bank number MSB
; a <- bank number LSB
; Modifies: f
FlashROM_GetMapperAddress:
	ld a,l
	rrca
	sbc a,a
	and 1101B
	xor 1011B
	add hl,hl
	call c,System_ThrowException
	add hl,hl
	call c,System_ThrowException
	add hl,hl
	adc a,a
	add hl,hl
	adc a,a
	add hl,hl
	adc a,a
	add hl,hl
	adc a,a
	ld e,h
	ld d,a
	and 0C0H
	rrc l
	rrc l
	or l
	ld h,a
	ld l,0
	ld a,e
	ld e,0
	ret

FlashROM_GetMapperAddress_Assert_M: MACRO ?physicalAddress, ?logicalAddress, ?bankAddress, ?bankData
	ld hl,?physicalAddress >> 12
	call FlashROM_GetMapperAddress
	and a
	ld bc,?logicalAddress
	sbc hl,bc
	call nz,System_ThrowException
	ld hl,?bankAddress
	sbc hl,de
	call nz,System_ThrowException
	cp ?bankData
	call nz,System_ThrowException
	ENDM

FlashROM_GetMapperAddress_Test:
	FlashROM_GetMapperAddress_Assert_M 0000000H, 08000H, 0B000H, 000H
	FlashROM_GetMapperAddress_Assert_M 0001000H, 05000H, 06000H, 000H
	FlashROM_GetMapperAddress_Assert_M 0002000H, 0A000H, 0B000H, 000H
	FlashROM_GetMapperAddress_Assert_M 0003000H, 07000H, 06000H, 000H

	FlashROM_GetMapperAddress_Assert_M 0004000H, 08000H, 0B000H, 001H
	FlashROM_GetMapperAddress_Assert_M 0005000H, 05000H, 06000H, 001H
	FlashROM_GetMapperAddress_Assert_M 0006000H, 0A000H, 0B000H, 001H
	FlashROM_GetMapperAddress_Assert_M 0007000H, 07000H, 06000H, 001H

	FlashROM_GetMapperAddress_Assert_M 03FC000H, 08000H, 0B000H, 0FFH
	FlashROM_GetMapperAddress_Assert_M 03FD000H, 05000H, 06000H, 0FFH
	FlashROM_GetMapperAddress_Assert_M 03FE000H, 0A000H, 0B000H, 0FFH
	FlashROM_GetMapperAddress_Assert_M 03FF000H, 07000H, 06000H, 0FFH

	FlashROM_GetMapperAddress_Assert_M 0400000H, 08000H, 0B100H, 000H
	FlashROM_GetMapperAddress_Assert_M 0401000H, 05000H, 06100H, 000H
	FlashROM_GetMapperAddress_Assert_M 0402000H, 0A000H, 0B100H, 000H
	FlashROM_GetMapperAddress_Assert_M 0403000H, 07000H, 06100H, 000H

	FlashROM_GetMapperAddress_Assert_M 3FFC000H, 08000H, 0BF00H, 0FFH
	FlashROM_GetMapperAddress_Assert_M 3FFD000H, 05000H, 06F00H, 0FFH
	FlashROM_GetMapperAddress_Assert_M 3FFE000H, 0A000H, 0BF00H, 0FFH
	FlashROM_GetMapperAddress_Assert_M 3FFF000H, 07000H, 06F00H, 0FFH

	; FlashROM_GetMapperAddress_Assert_M 4000000H, 08000H, 0B000H, 000H
	; FlashROM_GetMapperAddress_Assert_M 4001000H, 05000H, 06000H, 000H
	; FlashROM_GetMapperAddress_Assert_M 4002000H, 0A000H, 0B000H, 000H
	; FlashROM_GetMapperAddress_Assert_M 4003000H, 07000H, 06000H, 000H
	ret

;
FlashROM_messageNotFlash:
	db "Warning: Not a FlashROM!",13,10,10,0
FlashROM_messageManufacturerID:
	db "Manufacturer ID: ",0
FlashROM_messageDeviceID:
	db "Device ID: ",0
FlashROM_messageContinuityOk:
	db "Continuity check: OK",13,10,0
FlashROM_messageContinuityBad:
	db "Continuity check: BAD. Check pins for bridges.",13,10,0
FlashROM_messageContinuityBadStatus:
	db "Continuity check: BAD status.",13,10,0
