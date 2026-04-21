;
; Autoselect parameters
;
AutoSelect: MACRO
	manufacturer:
		db 0
	device1:
		db 0
	protected:
		db 0
	indicator:
		db 0
		ds 8
	software:
		dw 0
	device2:
		db 0
	device3:
		db 0
	_size: equ $
	ENDM

; hl = data
; ix = this
AutoSelect_Construct:
	ld e,ixl
	ld d,ixh
	ld bc,AutoSelect._size
	jp FlashCommand_ReadParameterBlock

; ix = this
AutoSelect_Print:
	call AutoSelect_PrintManufacturerID
	call AutoSelect_PrintDeviceID
	ret

; ix = this
AutoSelect_PrintManufacturerID:
	ld hl,AutoSelect_messageManufacturerID
	call System_Print
	ld a,(ix + AutoSelect.manufacturer)
	call System_PrintHexA
	call System_PrintCrLf
	ret

; ix = this
AutoSelect_PrintDeviceID:
	ld hl,AutoSelect_messageDeviceID
	call System_Print
	ld a,(ix + AutoSelect.device1)
	call System_PrintHexA
	cp 7EH
	jp nz,System_PrintCrLf
	ld a," "
	call System_PrintChar
	ld a,(ix + AutoSelect.device2)
	call System_PrintHexA
	ld a," "
	call System_PrintChar
	ld a,(ix + AutoSelect.device3)
	call System_PrintHexA
	call System_PrintCrLf
	ret

;
AutoSelect_messageManufacturerID:
	db "- Manufacturer ID: ",0
AutoSelect_messageDeviceID:
	db "- Device ID: ",0
