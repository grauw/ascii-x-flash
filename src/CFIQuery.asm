;
; Common Flash Interface query
;
CFIQuery: MACRO
	data:
		ds 10H
	signature:
		ds 3
	primaryVendorID:
		dw 0
	primaryVendorQuery:
		dw 0
	alternateVendorID:
		dw 0
	alternateVendorQuery:
		dw 0
	vccMin:
		db 0
	vccMax:
		db 0
	vppMin:
		db 0
	vppMax:
		db 0
	typicalTimeout:
		db 0
	typicalTimeoutBufferWrite:
		db 0
	typicalTimeoutSectorErase:
		db 0
	typicalTimeoutChipErase:
		db 0
	maxTimeout:
		db 0
	maxTimeoutBufferWrite:
		db 0
	maxTimeoutSectorErase:
		db 0
	maxTimeoutChipErase:
		db 0
	deviceSize:
		db 0
	deviceInterface:
		dw 0
	maxBufferWrite:
		dw 0
	regionCount:
		db 0
	region1SectorCount:
		dw 0
	region1SectorSize:
		dw 0
	region2SectorCount:
		dw 0
	region2SectorSize:
		dw 0
	region3SectorCount:
		dw 0
	region3SectorSize:
		dw 0
	region4SectorCount:
		dw 0
	region4SectorSize:
		dw 0
		ds 43H
	_size: equ $
	ENDM

; a = 0: x8, 1: x8/x16
; hl = data
; ix = this
CFIQuery_Construct: PROC
	call CFIQuery_GetData_DE
	ld bc,80H
	and a
	jr nz,X8X16Loop
	ldir
	ret
X8X16Loop:
	ldi
	inc hl
	jp pe,X8X16Loop
	ret
	ENDP

; ix = this
; de <- data
CFIQuery_GetData_DE:
	ld e,ixl
	ld d,ixh
	ret

; ix = this
; f <- z: QRY signature found
; Modifies: a
CFIQuery_HasSignature:
	ld a,(ix + CFIQuery.signature + 0)
	cp "Q"
	ret nz
	ld a,(ix + CFIQuery.signature + 1)
	cp "R"
	ret nz
	ld a,(ix + CFIQuery.signature + 2)
	cp "Y"
	ret

; ix = this
; hl <- capacity / 1000H (0: n/a, 4000H: >= 64 MB)
CFIQuery_GetCapacity: PROC
	call CFIQuery_HasSignature
	ld hl,0
	ret nz
	ld a,(ix + CFIQuery.deviceSize)
	sub 12
	ret c
	inc hl
	ret z
	cp 14
	jr c,Loop
	ld a,14
Loop:
	add hl,hl
	dec a
	jr nz,Loop
	ret
	ENDP

; ix = this
CFIQuery_PrintArray: PROC
	ld a,"C"
	call System_PrintChar
	ld a,"F"
	call System_PrintChar
	ld a,"I"
	call System_PrintChar
	ld b,16
LoopHeading:
	push bc
	ld a," "
	call System_PrintChar
	ld a,16
	sub b
	call System_PrintHex
	ld a," "
	call System_PrintChar
	pop bc
	djnz LoopHeading
	call System_PrintCrLf
	call CFIQuery_GetData_DE
	ex de,hl
	ld b,8
Loop:
	push bc
	ld a,8
	sub b
	call System_PrintHex
	ld a,":"
	call System_PrintChar
	ld a," "
	call System_PrintChar
	ld b,16
LoopLine:
	push bc
	push hl
	ld a,(hl)
	call System_PrintHexA
	ld a," "
	call System_PrintChar
	pop hl
	pop bc
	inc hl
	djnz LoopLine
	call System_PrintCrLf
	pop bc
	djnz Loop
	ret
	ENDP

; ix = this
CFIQuery_Print:
	ld hl,CFIQuery_message
	call System_PrintLn
	call CFIQuery_HasSignature
	ld hl,CFIQuery_messageNoSignature
	jp nz,System_PrintLn
	call CFIQuery_PrintQuery
	ld l,(ix + CFIQuery.primaryVendorID + 0)
	ld h,(ix + CFIQuery.primaryVendorID + 1)
	ld bc,AMDQuery_VENDOR_ID
	and a
	sbc hl,bc
	ret nz
	ld e,(ix + CFIQuery.primaryVendorQuery + 0)
	ld d,(ix + CFIQuery.primaryVendorQuery + 1)
	push ix
	add ix,de
	call AMDQuery_PrintQuery
	pop ix
	ret

; ix = this
CFIQuery_PrintQuery:
	call CFIQuery_PrintVccMin
	call CFIQuery_PrintVccMax
	call CFIQuery_PrintVppMin
	call CFIQuery_PrintVppMax
	call CFIQuery_PrintTypicalTimeout
	call CFIQuery_PrintTypicalTimeoutBufferWrite
	call CFIQuery_PrintTypicalTimeoutSectorErase
	call CFIQuery_PrintTypicalTimeoutChipErase
	call CFIQuery_PrintMaxTimeout
	call CFIQuery_PrintMaxTimeoutBufferWrite
	call CFIQuery_PrintMaxTimeoutSectorErase
	call CFIQuery_PrintMaxTimeoutChipErase
	call CFIQuery_PrintDeviceSize
	call CFIQuery_PrintDeviceInterface
	call CFIQuery_PrintMaxBufferWrite
	call CFIQuery_PrintRegionCount
	call CFIQuery_PrintRegions
	ret

; ix = this
CFIQuery_PrintVccMin:
	ld hl,CFIQuery_messageVccMin
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.vccMin)
	jp CFIQuery_PrintVoltage

; ix = this
CFIQuery_PrintVccMax:
	ld hl,CFIQuery_messageVccMax
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.vccMax)
	jp CFIQuery_PrintVoltage

; ix = this
CFIQuery_PrintVppMin:
	ld hl,CFIQuery_messageVppMin
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.vppMin)
	jp CFIQuery_PrintVoltage

; ix = this
CFIQuery_PrintVppMax:
	ld hl,CFIQuery_messageVppMax
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.vppMax)
	jp CFIQuery_PrintVoltage

; ix = this
CFIQuery_PrintTypicalTimeout:
	ld hl,CFIQuery_messageTypicalTimeout
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.typicalTimeout)
	jp CFIQuery_PrintMicroSeconds

; ix = this
CFIQuery_PrintTypicalTimeoutBufferWrite:
	ld hl,CFIQuery_messageTypicalTimeoutBufferWrite
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.typicalTimeoutBufferWrite)
	jp CFIQuery_PrintMicroSeconds

; ix = this
CFIQuery_PrintTypicalTimeoutSectorErase:
	ld hl,CFIQuery_messageTypicalTimeoutSectorErase
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.typicalTimeoutSectorErase)
	jp CFIQuery_PrintMilliSeconds

; ix = this
CFIQuery_PrintTypicalTimeoutChipErase:
	ld hl,CFIQuery_messageTypicalTimeoutChipErase
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.typicalTimeoutChipErase)
	jp CFIQuery_PrintMilliSeconds

; ix = this
CFIQuery_PrintMaxTimeout:
	ld hl,CFIQuery_messageMaxTimeout
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.typicalTimeout)
	add a,(ix + CFIQuery.data + CFIQuery.maxTimeout)
	jp CFIQuery_PrintMicroSeconds

; ix = this
CFIQuery_PrintMaxTimeoutBufferWrite:
	ld hl,CFIQuery_messageMaxTimeoutBufferWrite
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.typicalTimeoutBufferWrite)
	add a,(ix + CFIQuery.data + CFIQuery.maxTimeoutBufferWrite)
	jp CFIQuery_PrintMicroSeconds

; ix = this
CFIQuery_PrintMaxTimeoutSectorErase:
	ld hl,CFIQuery_messageMaxTimeoutSectorErase
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.typicalTimeoutSectorErase)
	add a,(ix + CFIQuery.data + CFIQuery.maxTimeoutSectorErase)
	jp CFIQuery_PrintMilliSeconds

; ix = this
CFIQuery_PrintMaxTimeoutChipErase:
	ld hl,CFIQuery_messageMaxTimeoutChipErase
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.typicalTimeoutChipErase)
	add a,(ix + CFIQuery.data + CFIQuery.maxTimeoutChipErase)
	jp CFIQuery_PrintMilliSeconds

; ix = this
CFIQuery_PrintDeviceSize:
	ld hl,CFIQuery_messageDeviceSize
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.deviceSize)
	jp CFIQuery_PrintSize

; ix = this
CFIQuery_PrintDeviceInterface:
	ld hl,CFIQuery_messageDeviceInterface
	call System_Print
	ld e,(ix + CFIQuery.data + CFIQuery.deviceInterface + 0)
	ld d,(ix + CFIQuery.data + CFIQuery.deviceInterface + 1)
	and a
	ld hl,0000H
	sbc hl,de
	ld hl,CFIQuery_messageDeviceInterfaceX8
	jp z,System_PrintLn
	and a
	ld hl,0001H
	sbc hl,de
	ld hl,CFIQuery_messageDeviceInterfaceX16
	jp z,System_PrintLn
	and a
	ld hl,0002H
	sbc hl,de
	ld hl,CFIQuery_messageDeviceInterfaceX8X16
	jp z,System_PrintLn
	ex de,hl
	call System_PrintHexHL
	jp System_PrintCrLf

; ix = this
CFIQuery_PrintMaxBufferWrite:
	ld hl,CFIQuery_messageMaxBufferWrite
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.maxBufferWrite)
	; ld d,(ix + CFIQuery.data + 2BH)
	jp CFIQuery_PrintSize

; ix = this
CFIQuery_PrintRegionCount:
	ld hl,CFIQuery_messageRegionCount
	call System_Print
	ld a,(ix + CFIQuery.data + CFIQuery.regionCount)
	call System_PrintDecA
	jp System_PrintCrLf

; ix = this
CFIQuery_PrintRegions: PROC
	ld a,0
Loop:
	cp (ix + CFIQuery.data + CFIQuery.regionCount)
	ret z
	cp 4
	ret z
	push ix
	ld e,a
	ld d,0
	add ix,de
	add ix,de
	add ix,de
	add ix,de
	ld hl,CFIQuery_messageRegion
	call System_Print
	call System_PrintDecA
	ld hl,CFIQuery_messageRegionSectorCount
	call System_Print
	ld l,(ix + CFIQuery.data + CFIQuery.region1SectorCount + 0)
	ld h,(ix + CFIQuery.data + CFIQuery.region1SectorCount + 1)
	inc hl
	call System_PrintDecHL
	call System_PrintCrLf
	ld hl,CFIQuery_messageRegion
	call System_Print
	call System_PrintDecA
	ld hl,CFIQuery_messageRegionSectorSize
	call System_Print
	ld l,0
	ld h,(ix + CFIQuery.data + CFIQuery.region1SectorSize + 0)
	ld e,(ix + CFIQuery.data + CFIQuery.region1SectorSize + 1)
	ld d,0
	call System_PrintDecDEHL
	ld hl,CFIQuery_messageBytes
	call System_PrintLn
	pop ix
	inc a
	jr Loop
	ENDP

; a = voltage
CFIQuery_PrintVoltage:
	and a
	ld hl,CFIQuery_messageNotSupported
	jp z,System_PrintLn
	push af
	rrca
	rrca
	rrca
	rrca
	and 0FH
	call System_PrintDecA
	ld a,"."
	call System_PrintChar
	pop af
	and 0FH
	call System_PrintHex
	ld a," "
	call System_PrintChar
	ld a,"V"
	call System_PrintChar
	jp System_PrintCrLf

; a = milliseconds
CFIQuery_PrintMilliSeconds:
	and a
	ld hl,CFIQuery_messageNotSupported
	jp z,System_PrintLn
	call CFIQuery_PrintTwoToThePowerA
	ld hl,CFIQuery_messageMilliSeconds
	jp System_PrintLn

; a = microseconds
CFIQuery_PrintMicroSeconds:
	and a
	ld hl,CFIQuery_messageNotSupported
	jp z,System_PrintLn
	call CFIQuery_PrintTwoToThePowerA
	ld hl,CFIQuery_messageMicroSeconds
	jp System_PrintLn

; a = 2^size
CFIQuery_PrintSize: PROC
	and a
	ld hl,CFIQuery_messageNotSupported
	jp z,System_PrintLn
	sub 10
	jr c,Bytes
	sub 10
	jr c,KiloBytes
	sub 10
	jr c,MegaBytes
	sub 10
	jr c,GigaBytes
	add a,40
	call CFIQuery_PrintTwoToThePowerA
	ld hl,CFIQuery_messageBytes
	jp System_PrintLn
Bytes:
	call PrintTwoToThePowerAPlus10
	ld hl,CFIQuery_messageBytes
	jp System_PrintLn
KiloBytes:
	call PrintTwoToThePowerAPlus10
	ld hl,CFIQuery_messageKiloBytes
	jp System_PrintLn
MegaBytes:
	call PrintTwoToThePowerAPlus10
	ld hl,CFIQuery_messageMegaBytes
	jp System_PrintLn
GigaBytes:
	call PrintTwoToThePowerAPlus10
	ld hl,CFIQuery_messageGigaBytes
	jp System_PrintLn
PrintTwoToThePowerAPlus10: PROC
	add a,10
	ld hl,1
	jp z,System_PrintDecHL
Loop:
	add hl,hl
	dec a
	jr nz,Loop
	jp System_PrintDecHL
	ENDP
	ENDP

; a = value
CFIQuery_PrintTwoToThePowerA:
	push af
	ld a,"2"
	call System_PrintChar
	ld a,"^"
	call System_PrintChar
	pop af
	jp System_PrintDecA

;
CFIQuery_message:
	db "Common Flash Interface query:",0
CFIQuery_messageNoSignature:
	db "Signature not found.",0
CFIQuery_messageVccMin:
	db "- Vcc min: ",0
CFIQuery_messageVccMax:
	db "- Vcc max: ",0
CFIQuery_messageVppMin:
	db "- Vpp min: ",0
CFIQuery_messageVppMax:
	db "- Vpp max: ",0
CFIQuery_messageTypicalTimeout:
	db "- Typical timeout: ",0
CFIQuery_messageTypicalTimeoutBufferWrite:
	db "- Typical timeout (buffer write): ",0
CFIQuery_messageTypicalTimeoutSectorErase:
	db "- Typical timeout (sector erase): ",0
CFIQuery_messageTypicalTimeoutChipErase:
	db "- Typical timeout (chip erase): ",0
CFIQuery_messageMaxTimeout:
	db "- Max timeout: ",0
CFIQuery_messageMaxTimeoutBufferWrite:
	db "- Max timeout (buffer write): ",0
CFIQuery_messageMaxTimeoutSectorErase:
	db "- Max timeout (sector erase): ",0
CFIQuery_messageMaxTimeoutChipErase:
	db "- Max timeout (chip erase): ",0
CFIQuery_messageDeviceSize:
	db "- Device size: ",0
CFIQuery_messageDeviceInterface:
	db "- Flash device interface: ",0
CFIQuery_messageDeviceInterfaceX8:
	db "x8",0
CFIQuery_messageDeviceInterfaceX16:
	db "x16",0
CFIQuery_messageDeviceInterfaceX8X16:
	db "x8/x16",0
CFIQuery_messageMaxBufferWrite:
	db "- Max buffer write: ",0
CFIQuery_messageRegionCount:
	db "- Region count: ",0
CFIQuery_messageRegion:
	db "- Region ",0
CFIQuery_messageRegionSectorCount:
	db " sector count: ",0
CFIQuery_messageRegionSectorSize:
	db " sector size: ",0
CFIQuery_messageSupported:
	db "Supported",0
CFIQuery_messageNotSupported:
	db "Not supported",0
CFIQuery_messageMilliSeconds:
	db " ms",0
CFIQuery_messageMicroSeconds:
	db " us",0
CFIQuery_messageBytes:
	db " bytes",0
CFIQuery_messageKiloBytes:
	db " kB",0
CFIQuery_messageMegaBytes:
	db " MB",0
CFIQuery_messageGigaBytes:
	db " GB",0
