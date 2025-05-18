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
; iy = this
; Modifies: af
ArrayIterator_Construct: PROC
	push iy
Loop:
	ld (iy + ArrayIterator.ForEach + 0),0DDH  ; ld ix,nn
	ld (iy + ArrayIterator.ForEach + 1),021H
	ld (iy + ArrayIterator.ForEach + 2),l
	ld (iy + ArrayIterator.ForEach + 3),h
	ld (iy + ArrayIterator.ForEach + 4),0CDH  ; call nn
	ld (iy + ArrayIterator.ForEach + 5),e
	ld (iy + ArrayIterator.ForEach + 6),d
	REPT 7  ; ForEach REPT block size
	inc iy
	ENDM
	add hl,bc
	dec a
	jr nz,Loop
	ld (iy + ArrayIterator.ForEach + 0),0C9H  ; ret
	pop iy
	ret
	ENDP

; iy = this
; ix <- last element
ArrayIterator_ForEach: PROC
	jp iy
Break:
	ex (sp),iy
	pop iy
	ret
	ENDP
