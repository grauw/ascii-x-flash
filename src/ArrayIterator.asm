;
; Array iterator.
;
; Maps calls to all elements.
;
ArrayIterator: MACRO ?capacity
	ForEach:
		REPT ?capacity
		ld ix,0
		call System_ThrowException
		ENDM
		ret
	ENDM

; a = count
; bc = size
; de = function
; hl = address
; ix = this
; Modifies: af
ArrayIterator_Construct: PROC
	push ix
Loop:
	ld (ix + ArrayIterator.ForEach + 0),0DDH  ; ld ix,nn
	ld (ix + ArrayIterator.ForEach + 1),021H
	ld (ix + ArrayIterator.ForEach + 2),l
	ld (ix + ArrayIterator.ForEach + 3),h
	ld (ix + ArrayIterator.ForEach + 4),0CDH  ; call nn
	ld (ix + ArrayIterator.ForEach + 5),e
	ld (ix + ArrayIterator.ForEach + 6),d
	REPT 7  ; ForEach REPT block size
	inc ix
	ENDM
	add hl,bc
	dec a
	jr nz,Loop
	ld (ix + ArrayIterator.ForEach + 0),0C9H  ; ret
	pop ix
	ret
	ENDP

; ix = this
; ix <- last element
ArrayIterator_ForEach: PROC
	jp ix
Break:
	ex (sp),ix
	pop ix
	ret
	ENDP
