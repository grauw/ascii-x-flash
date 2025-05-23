;
; CFI AMD vendor-specific extended query
;
AMDQuery_VENDOR_ID: equ 0002H

AMDQuery: MACRO
	signature:
		ds 3
	version:
		dw 0
	; version 1.0
	addressSensitiveUnlock:  ; version 1.1: + process technology
		db 0
	eraseSuspend:
		db 0
	sectorProtect:
		db 0
	sectorTemporaryUnprotect:
		db 0
	sectorProtectScheme:
		db 0
	simultaneousOperation:
		db 0
	burstMode:
		db 0
	pageMode:
		db 0

	; version 1.1
	accMin:
		db 0
	accMax:
		db 0
	bootSectorType:
		db 0
	
	; version 1.2
	programSuspend:
		db 0

	; version 1.4
	unlockBypass:
		db 0
	secureSiliconSize:
		db 0
	softwareFeatures:
		db 0
	pageSize:
		db 0
	maxTimeoutEraseSuspend:
		db 0
	maxTimeoutProgramSuspend:
		db 0

	; version 1.3
	bankOrganization:
		db 0
	bankRegionInfo:
		ds 4

	; version 1.4
		ds 28
	maxTimeoutResetPin:
		db 0
	maxTimeoutPowerOnReset:
		db 0
	ENDM

; ix = this
AMDQuery_PrintQuery: PROC
	call AMDQuery_PrintVendorSpecificVersion

	ld a,(ix + AMDQuery.version + 0)
	cp "1"
	ret nz
	ld a,(ix + AMDQuery.version + 1)
	cp "0"
	ret c
	call AMDQuery_PrintAddressSensitiveUnlock
	call AMDQuery_PrintEraseSuspend
	call AMDQuery_PrintSectorProtect
	call AMDQuery_PrintSectorTemporaryUnprotect
	call AMDQuery_PrintSectorProtectScheme
	call AMDQuery_PrintSimultaneousOperation
	call AMDQuery_PrintBurstMode
	call AMDQuery_PrintPageMode

	ld a,(ix + AMDQuery.version + 1)
	cp "1"
	ret c
	call AMDQuery_PrintProcessTechnology
	call AMDQuery_PrintACCMin
	call AMDQuery_PrintACCMax
	call AMDQuery_PrintBootSectorType

	ld a,(ix + AMDQuery.version + 1)
	cp "2"
	ret c
	call AMDQuery_PrintProgramSuspend

	ld a,(ix + AMDQuery.version + 1)
	cp "3"
	ret c

	ld a,(ix + AMDQuery.version + 1)
	cp "4"
	ret c
	ret
	ENDP

; ix = this
AMDQuery_PrintVendorSpecificVersion:
	ld hl,AMDQuery_messageVendorSpecificVersion
	call System_Print
	ld d,(ix + AMDQuery.version + 0)
	ld e,(ix + AMDQuery.version + 1)
	jp AMDQuery_PrintVersionNumber

; ix = this
AMDQuery_PrintAddressSensitiveUnlock:
	ld hl,AMDQuery_messageAddressSensitiveUnlock
	call System_Print
	ld a,(ix + AMDQuery.addressSensitiveUnlock)
	and 03H
	jp AMDQuery_PrintRequired

; ix = this
AMDQuery_PrintProcessTechnology:
	ld hl,AMDQuery_messageProcessTechnology
	call System_Print
	ld a,(ix + AMDQuery.addressSensitiveUnlock)
	rrca
	rrca
	and 0FH
	call System_PrintHex
	jp System_PrintCrLf

; ix = this
AMDQuery_PrintEraseSuspend:
	ld hl,AMDQuery_messageEraseSuspend
	call System_Print
	ld a,(ix + AMDQuery.eraseSuspend)
	cp 0
	ld hl,CFIQuery_messageNotSupported
	jp z,System_PrintLn
	cp 1
	ld hl,AMDQuery_messageReadOnly
	jp z,System_PrintLn
	cp 2
	ld hl,AMDQuery_messageReadWrite
	jp z,System_PrintLn
	ld hl,AMDQuery_messageUnknown
	jp System_PrintLn

; ix = this
AMDQuery_PrintSectorProtect:
	ld hl,AMDQuery_messageSectorProtect
	call System_Print
	ld a,(ix + AMDQuery.sectorProtect)
	jp AMDQuery_PrintSectors

; ix = this
AMDQuery_PrintSectorTemporaryUnprotect:
	ld hl,AMDQuery_messageSectorTemporaryUnprotect
	call System_Print
	ld a,(ix + AMDQuery.sectorTemporaryUnprotect)
	jp AMDQuery_PrintSupported

; ix = this
AMDQuery_PrintSectorProtectScheme:
	ld hl,AMDQuery_messageSectorProtectScheme
	call System_Print
	ld a,(ix + AMDQuery.sectorProtectScheme)
	call System_PrintHexA
	jp System_PrintCrLf

; ix = this
AMDQuery_PrintSimultaneousOperation:
	ld hl,AMDQuery_messageSimultaneousOperation
	call System_Print
	ld a,(ix + AMDQuery.simultaneousOperation)
	jp AMDQuery_PrintSectors

; ix = this
AMDQuery_PrintBurstMode:
	ld hl,AMDQuery_messageBurstMode
	call System_Print
	ld a,(ix + AMDQuery.burstMode)
	jp AMDQuery_PrintSupported

; ix = this
AMDQuery_PrintPageMode:
	ld hl,AMDQuery_messagePageMode
	call System_Print
	ld a,(ix + AMDQuery.pageMode)
	and a
	ld hl,CFIQuery_messageNotSupported
	jp z,System_PrintLn
	inc a
	jp CFIQuery_PrintSize

; ix = this
AMDQuery_PrintACCMin:
	ld hl,AMDQuery_messageACCMin
	call System_Print
	ld a,(ix + AMDQuery.accMin)
	jp CFIQuery_PrintVoltage

; ix = this
AMDQuery_PrintACCMax:
	ld hl,AMDQuery_messageACCMax
	call System_Print
	ld a,(ix + AMDQuery.accMax)
	jp CFIQuery_PrintVoltage

; ix = this
AMDQuery_PrintBootSectorType:
	ld hl,AMDQuery_messageBootSectorType
	call System_Print
	ld a,(ix + AMDQuery.bootSectorType)
	call System_PrintHexA
	jp System_PrintCrLf

; ix = this
AMDQuery_PrintProgramSuspend:
	ld hl,AMDQuery_messageProgramSuspend
	call System_Print
	ld a,(ix + AMDQuery.programSuspend)
	jp AMDQuery_PrintSupported

; de = major.minor
AMDQuery_PrintVersionNumber:
	ld a,d
	call System_PrintChar
	ld a,"."
	call System_PrintChar
	ld a,e
	call System_PrintChar
	jp System_PrintCrLf

; a = 0: required
AMDQuery_PrintRequired:
	cp 0
	ld hl,AMDQuery_messageRequired
	jp z,System_PrintLn
	cp 1
	ld hl,AMDQuery_messageNotRequired
	jp z,System_PrintLn
	ld hl,AMDQuery_messageUnknown
	jp System_PrintLn

; a = 1: supported
AMDQuery_PrintSupported:
	cp 0
	ld hl,CFIQuery_messageNotSupported
	jp z,System_PrintLn
	cp 1
	ld hl,CFIQuery_messageSupported
	jp z,System_PrintLn
	ld hl,AMDQuery_messageUnknown
	jp System_PrintLn

; a = count
AMDQuery_PrintSectors:
	and a
	ld hl,CFIQuery_messageNotSupported
	jp z,System_PrintLn
	call System_PrintDecA
	ld hl,AMDQuery_messageSectors
	jp System_PrintLn

;
AMDQuery_messageVendorSpecificVersion:
	db "- Vendor specific version: ",0
AMDQuery_messageAddressSensitiveUnlock:
	db "- Address sensitive unlock: ",0
AMDQuery_messageProcessTechnology:
	db "- Process technology: ",0
AMDQuery_messageEraseSuspend:
	db "- Erase suspend: ",0
AMDQuery_messageSectorProtect:
	db "- Sector protect: ",0
AMDQuery_messageSectorTemporaryUnprotect:
	db "- Sector temporary unprotect: ",0
AMDQuery_messageSectorProtectScheme:
	db "- Sector protect scheme: ",0
AMDQuery_messageSimultaneousOperation:
	db "- Simultaneous operation: ",0
AMDQuery_messageBurstMode:
	db "- Burst mode: ",0
AMDQuery_messagePageMode:
	db "- Page mode: ",0
AMDQuery_messageACCMin:
	db "- ACC supply min: ",0
AMDQuery_messageACCMax:
	db "- ACC supply max: ",0
AMDQuery_messageBootSectorType:
	db "- Boot sector type: ",0
AMDQuery_messageProgramSuspend:
	db "- Program suspend: ",0
AMDQuery_messageRequired:
	db "Required",0
AMDQuery_messageNotRequired:
	db "Not required",0
AMDQuery_messageReadOnly:
	db "Read-only",0
AMDQuery_messageReadWrite:
	db "Read/write",0
AMDQuery_messageUnknown:
	db "Unknown",0
AMDQuery_messageSectors:
	db " sectors",0
