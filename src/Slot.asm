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

; ix = this
; f <- z: main ram, nz: ok
Slot_CheckMainRAM:
	ld a,(RAMAD0)
	cp (ix + Slot.id)
	ret z
	ld a,(RAMAD1)
	cp (ix + Slot.id)
	ret z
	ld a,(RAMAD2)
	cp (ix + Slot.id)
	ret z
	ld a,(RAMAD3)
	cp (ix + Slot.id)
	ret

; ix = this
; f <- z: disk system, nz: ok
Slot_CheckDiskSystem:
	ld a,(MASTER)
	cp (ix + Slot.id)
	ret z
	ld a,(DRVTAB + 0)
	cp 1
	ret c
	ld a,(DRVTAB + 1)
	cp (ix + Slot.id)
	ret z
	ld a,(DRVTAB + 2)
	cp 1
	ret c
	ld a,(DRVTAB + 3)
	cp (ix + Slot.id)
	ret z
	ld a,(DRVTAB + 4)
	cp 1
	ret c
	ld a,(DRVTAB + 5)
	cp (ix + Slot.id)
	ret z
	ld a,(DRVTAB + 6)
	cp 1
	ret c
	ld a,(DRVTAB + 7)
	cp (ix + Slot.id)
	ret
