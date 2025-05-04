;
; A slotted device.
;
SlotDevice: MACRO
	slot:
		Slot
	ENDM

; a = slot ID
; ix = this
SlotDevice_Construct:
	ld (ix + SlotDevice.slot.id),a
	ret

; ix = this
; Modifies: none
SlotDevice_Select:
	push af
	push bc
	push de
	push hl
	ld h,40H
	ld a,(ix + SlotDevice.slot.id)
	call Memory_SetSlot
	ld h,80H
	ld a,(ix + SlotDevice.slot.id)
	call Memory_SetSlot
	pop hl
	pop de
	pop bc
	pop af
	ret
