;
; ASCII16-X mapper
;
; Modifies: a
ASCII16XMapper_Reset:
	ld a,0
	ld (6000H),a
	ld (7000H),a
	ret

; hl = physical address / 1000H
; hl <- logical address
; Modifies: af
ASCII16XMapper_SelectAddress:
	push de
	call ASCII16XMapper_GetAddress
	ld (de),a
	pop de
	ret

; hl = physical address / 1000H
; hl <- logical address
; de <- bank switch address + bank number MSB
; a <- bank number LSB
; Modifies: f
ASCII16XMapper_GetAddress:
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
	res 7,d
	set 6,d
	ret

ASCII16XMapper_GetAddress_Assert_M: MACRO ?physicalAddress, ?logicalAddress, ?bankAddress, ?bankData
	ld hl,?physicalAddress >> 12
	call ASCII16XMapper_GetAddress
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

ASCII16XMapper_GetAddress_Test:
	ASCII16XMapper_GetAddress_Assert_M 0000000H, 08000H, 07000H, 000H
	ASCII16XMapper_GetAddress_Assert_M 0001000H, 05000H, 06000H, 000H
	ASCII16XMapper_GetAddress_Assert_M 0002000H, 0A000H, 07000H, 000H
	ASCII16XMapper_GetAddress_Assert_M 0003000H, 07000H, 06000H, 000H

	ASCII16XMapper_GetAddress_Assert_M 0004000H, 08000H, 07000H, 001H
	ASCII16XMapper_GetAddress_Assert_M 0005000H, 05000H, 06000H, 001H
	ASCII16XMapper_GetAddress_Assert_M 0006000H, 0A000H, 07000H, 001H
	ASCII16XMapper_GetAddress_Assert_M 0007000H, 07000H, 06000H, 001H

	ASCII16XMapper_GetAddress_Assert_M 03FC000H, 08000H, 07000H, 0FFH
	ASCII16XMapper_GetAddress_Assert_M 03FD000H, 05000H, 06000H, 0FFH
	ASCII16XMapper_GetAddress_Assert_M 03FE000H, 0A000H, 07000H, 0FFH
	ASCII16XMapper_GetAddress_Assert_M 03FF000H, 07000H, 06000H, 0FFH

	ASCII16XMapper_GetAddress_Assert_M 0400000H, 08000H, 07100H, 000H
	ASCII16XMapper_GetAddress_Assert_M 0401000H, 05000H, 06100H, 000H
	ASCII16XMapper_GetAddress_Assert_M 0402000H, 0A000H, 07100H, 000H
	ASCII16XMapper_GetAddress_Assert_M 0403000H, 07000H, 06100H, 000H

	ASCII16XMapper_GetAddress_Assert_M 3FFC000H, 08000H, 07F00H, 0FFH
	ASCII16XMapper_GetAddress_Assert_M 3FFD000H, 05000H, 06F00H, 0FFH
	ASCII16XMapper_GetAddress_Assert_M 3FFE000H, 0A000H, 07F00H, 0FFH
	ASCII16XMapper_GetAddress_Assert_M 3FFF000H, 07000H, 06F00H, 0FFH

	; ASCII16XMapper_GetAddress_Assert_M 4000000H, 08000H, 07000H, 000H
	; ASCII16XMapper_GetAddress_Assert_M 4001000H, 05000H, 06000H, 000H
	; ASCII16XMapper_GetAddress_Assert_M 4002000H, 0A000H, 07000H, 000H
	; ASCII16XMapper_GetAddress_Assert_M 4003000H, 07000H, 06000H, 000H
	ret
