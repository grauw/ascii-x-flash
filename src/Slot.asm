;
; Slot type containing slot ID.
;
Slot_NONE: equ 0FFH

Slot: MACRO ?id = Slot_NONE
	id:
		db ?id
	ENDM

; ix = this
Slot_Print:
	ld a,(ix + Slot.id)
	and 3
	add a,"0"
	call System_PrintChar
	bit 7,(ix + Slot.id)
	ret z
	ld a,"-"
	call System_PrintChar
	ld a,(ix + Slot.id)
	rrca
	rrca
	and 3
	add a,"0"
	call System_PrintChar
	ret

; ix = this
; f <- z: correct, nz: mismatch
Slot_CheckExpanded:
	ld a,(ix + Slot.id)
	and 03H
	ld c,a
	ld b,0
	ld hl,EXPTBL
	add hl,bc
	ld a,(hl)
	xor (ix + Slot.id)
	and 80H
	ret
