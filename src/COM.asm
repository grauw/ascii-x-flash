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
	INCLUDE "Application.asm"
	INCLUDE "CLI.asm"
	INCLUDE "FlashROM.asm"
	INCLUDE "CFIQuery.asm"
	INCLUDE "AMDQuery.asm"

RAM_RESIDENT:
	ds 100H
TPA_PAGE1:  ; fake
	ds 100H

Main:
	ld ix,COM_application
	call Application_Construct
	push ix
	ld hl,Application_Run
	call System_TryCall
	pop ix
	call Application_Destruct
	ret

;
COM_application:
	Application

	ENDS
