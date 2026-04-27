;
;
;
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
	ld hl,COM_buffer
	call Application_Construct
	push ix
	ld hl,Application_Run
	call System_TryCall
	pop ix
	call Application_Destruct
	ret
	ENDP

;
COM_application:
	Application
COM_buffer:
	ds FlashDevice_BLOCK_SIZE

	ENDS
