;
;
;
COM_BUFFER: equ 0C000H
COM_BUFFER_SIZE: equ FlashDevice_BLOCK_SIZE
COM_STACK_SIZE: equ 200H

	org 100H

TPA_PAGE0:
	ds 3F00H

	SECTION TPA_PAGE0

	DOS2Runtime Main

	INCLUDE "BIOS.asm"
	INCLUDE "DOS.asm"
	INCLUDE "DOS2Runtime.asm"
	INCLUDE "System.asm"
	INCLUDE "Memory.asm"
	INCLUDE "Slot.asm"
	INCLUDE "Application.asm"
	INCLUDE "CLI.asm"
	INCLUDE "ASCII16XMapper.asm"
	INCLUDE "SlotDevice.asm"
	INCLUDE "FlashDevice.asm"
	INCLUDE "FlashCommand.asm"
	INCLUDE "ArrayIterator.asm"
	INCLUDE "CFIQuery.asm"
	INCLUDE "AMDQuery.asm"

RAM_RESIDENT:
	ds 100H
TPA_PAGE1:  ; fake
	ds 100H

Main: PROC
	ld hl,-(COM_BUFFER + COM_BUFFER_SIZE + COM_STACK_SIZE)
	add hl,sp
	ld hl,COM_insufficientTPAError
	call nc,System_ThrowExceptionWithMessage
	ld h,40H
	call Memory_GetSlot
	push af
	ld h,80H
	call Memory_GetSlot
	push af
	ld hl,RunApplication
	call System_TryCall
	pop af
	ld h,80H
	call Memory_SetSlot
	pop af
	ld h,40H
	call Memory_SetSlot
	ret
RunApplication:
	ld ix,COM_application
	ld hl,COM_BUFFER
	call Application_Construct
	push ix
	ld hl,Application_Run
	call System_TryCall
	pop ix
	call Application_Destruct
	ret
	ENDP

;
COM_insufficientTPAError:
	db "Insufficient TPA space.",13,10,0

COM_application:
	Application

	ENDS
