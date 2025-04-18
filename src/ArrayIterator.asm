;
; Array iterator.
;
; Maps calls to all elements.
;
ArrayIterator: MACRO ?capacity
	ForEach:
		REPT ?capacity
		ld ix,0
		call System_JumpIY
		ENDM
		ret
	ENDM

; a = count
; bc = size
; hl = address
; ix = this
ArrayIterator_Construct: PROC
	push ix
	ld de,7  ; ForEach REPT block size
Loop:
	ld (ix + ArrayIterator.ForEach + 0),0DDH  ; ld ix,nn
	ld (ix + ArrayIterator.ForEach + 1),021H
	ld (ix + ArrayIterator.ForEach + 2),l
	ld (ix + ArrayIterator.ForEach + 3),h
	add hl,bc
	add ix,de
	dec a
	jr nz,Loop
	ld (ix + ArrayIterator.ForEach + 0),0C9H  ; ret
	pop ix
	ret
	ENDP

; ix = this
; iy = function
; ix <- last element
ArrayIterator_ForEach: PROC
	jp ix
Break:
	ex (sp),ix
	pop ix
	ret
	ENDP
