;------------------------------------------------------------------------------------------\
; Title: Red Block, Blue Block
; Author: Jarrod Parkes
; System: Nintendo Entertainment System
; Date: December 25, 2012
; Current Version: v1.1
; Assembler: NESASMv3.01
;------------------------------------------------------------------------------------------/

FADE_MODE_NONE		EQU	0
FADE_MODE_IN		EQU 1
FADE_MODE_OUT		EQU 2

FADE_TABLE_NONE		EQU 0	; offset for fully opaque
FADE_TABLE_TRAN0	EQU 64	; offset for making row 0 "transparent"
FADE_TABLE_TRAN1	EQU 128	; offset for making rows 0-1 "transparent"
FADE_TABLE_TRAN2	EQU 192	; offset for making rows 0-2 "transparent"

FADE_STEP_COUNT		EQU 1

UpdateVRAM:
	; turn off rendering
	LDA #0   
	STA PPU_MASK			; disable sprites/background
	
	; sprite RAM update
	LDA #0  
	STA $2003  ; Set OAM to start position.
	LDA #HIGH(SPRITE_RAM)
	STA $4014  ; set the high byte of $0200, start DMA transfer
	
	; turn on rendering
	LDA #%00011110   		
	STA PPU_MASK			; enable sprites/background, no clipping on left side
	
	RTS

;ADDED SUBROUTINE:
ClearScroll:
	LDA <PPU_CTRL_RAM
	STA $2000
	LDA #$00
	STA $2005
	STA $2005
	RTS

UpdateOAM:
	LDA #0 
	STA $2003  ; set the low byte of $0200
	LDA #HIGH(SPRITE_RAM)
	STA $4014  ; set the high byte of $0200, start DMA transfer
	RTS
	
SetFadeIn:
	LDA #FADE_MODE_IN
	STA <FADE_MODE
	LDA #192
	STA <FADE_OFFSET
	RTS

SetFadeOut:
	LDA #FADE_MODE_OUT
	STA <FADE_MODE
	LDA #0
	STA <FADE_OFFSET
	RTS
	
SetFadeNone:
	LDA #FADE_MODE_NONE
	STA <FADE_MODE
	RTS
	
EmptyPalette:				
	LDA PPU_STATUS			; NECESSARY... this tells the PPU to expect the high byte next
	LDA #$3F				; high byte of addr. in PPU addr. space
	STA PPU_ADDR           	; write the high byte of $3F00 address
	LDX #$00				; low byte of addr. in PPU addr. space
	STX PPU_ADDR           	; write the low byte of $3F00 address, completes address ($3F00)
	LDA #$0F
	
.1							; fill PPU pallete and zero-page pallete with all black
	STA PPU_DATA
	STA PALETTE,X
	INX
	CPX #$20				; have we set all 32 colors?
	BNE .1
	
	LDA #FADE_MODE_NONE
	STA <FADE_MODE
	LDA #FADE_TABLE_TRAN2
	STA <FADE_OFFSET
	RTS

LoadPalette:
	LDA PPU_STATUS			; NECESSARY... this tells the PPU to expect the high byte next
	LDA #$3F
	STA PPU_ADDR
	LDA #$00				; low byte of addr. in PPU addr. space
	STA PPU_ADDR
	STX <TEMP				; store LOW byte of address to palette location in TEMP
	STY <TEMP+1				; store HIGH byte of address to palette location in TEMP+1
	TAX
	LDY #0					; store count variable Y at 0
.1
	LDA [TEMP],Y
	STA PPU_DATA
	STA PALETTE,X
	INY
	INX
	CPY #$20
	BNE .1
	RTS

UpdatePalette:						; time critical, must run during one vblank (2250 cycles)
									; runs in about 100-120 cycles?
	LDA PPU_STATUS					; NECESSARY... this tells the PPU to expect the high byte next								
	LDA #$3F						; 2 cycles
	STA PPU_ADDR					; 4 cycles
	LDY #$00						; 2 cycles
	STY PPU_ADDR					; 4 cycles
.getOffset
	LDA <FADE_OFFSET				; 3 cycles
	CLC								; 2 cycles
	ADC #LOW(PalFadeTable)			; 2/3 cycles?
	STA <TEMP						; 3 cycles
	LDA #0							; 2 cycles
	ADC #HIGH(PalFadeTable)			; 2/3 cycles?
	STA <TEMP+1						; 4 cycles
	LDX #0							; 2 cycles
.setPPUPalette
	LDA PALETTE,X					; 4 cycles
	TAY								; 2 cycles
	LDA [TEMP],Y					; 5 cycles
	STA PPU_DATA					; 4 cycles
	INX								; 2 cycles
	CPX #$20						; 2 cycles
	BNE .setPPUPalette				; 2/3 cycles
	LDA <FRAME_NUM					; 3 cycles
	AND #FADE_STEP_COUNT			; 2 cycles, take fade-step per FADE_STEP_COUNT frames
	BEQ .fade						; 2/3 cycles
	RTS								; 6 cycles
.fade
	LDA <FADE_MODE					; 3 cycles
	CMP #FADE_MODE_IN				; 2 cycles
	BEQ .fadeIn						; 2/3 cycles
	CMP #FADE_MODE_OUT				; 2 cycles
	BEQ .fadeOut					; 2/3 cycles
	RTS								; 6 cycles

.fadeOut
	LDA <FADE_OFFSET				; 3 cycles
	CLC								; 2 cycles
	ADC #64							; 2 cycles
	CMP #0							; 2 cycles
	BEQ .finish						; 2/3 cycles
	JMP .done						; 3/5 cycles
.fadeIn
	LDA <FADE_OFFSET				; 3 cycles
	CLC								; 2 cycles
	ADC #-64						; 2 cycles
	CMP #192						; 2 cycles
	BEQ .finish						; 2/3 cycles
	JMP .done						; 3/5 cycles
.finish
	TAX								; 2 cycles
	JSR SetFadeNone 				; 6 cycles
	RTS
.done
	STA <FADE_OFFSET				; 3 cycles
	RTS								; 6 cycles

UpdateBlock:
	LDX #$10
	LDY #$00
	LDA <BLOCK_X					
	STA SPRITE_RAM+3,X				; update block X position
	STA SPRITE_RAM+11,X	
	STA SPRITE_RAM+3,Y				; update collision box X position
	STA SPRITE_RAM+11,Y
	CLC
	ADC #$08
	STA SPRITE_RAM+7,X				; update block X position
	STA SPRITE_RAM+15,X
	CLC
	ADC #$07
	STA SPRITE_RAM+7,Y				; update collision box X position
	STA SPRITE_RAM+15,Y
	
	LDA <BLOCK_Y					
	STA SPRITE_RAM,X				; update block Y position
	STA SPRITE_RAM+4,X	
	STA SPRITE_RAM,Y				; update collision box Y position
	STA SPRITE_RAM+4,Y	
	CLC
	ADC #$08
	STA SPRITE_RAM+8,X				; update block Y position
	STA SPRITE_RAM+12,X
	CLC
	ADC #$07
	STA SPRITE_RAM+8,Y				; update collision box Y position
	STA SPRITE_RAM+12,Y
	RTS


;CHANGED THESE TWO TO MAKE SCORE SHOW RIGHT WITH NEW SPRITE TILE LOCATION.
UpdateTimer:
	LDX #$30
	LDA <TIMER_ONE
	CLC
	ADC #$60
	STA SPRITE_RAM+9,X
	LDA <TIMER_TEN
	ADC #$60
	STA SPRITE_RAM+5,X
	RTS
	
UpdateScore:
	LDX #$40
	LDA <SCORE_ONE
	CLC
	ADC #$60
	STA SPRITE_RAM+9,X
	LDA <SCORE_TEN
	ADC #$60
	STA SPRITE_RAM+5,X
	LDA <SCORE_HUN
	ADC #$60
	STA SPRITE_RAM+1,X
	RTS
	
UpdatePickUp:
	LDX #$20
	
	JSR GetRandom
	JSR FixRandom
	
	STA <PICKUP_X
	STA SPRITE_RAM+3,X				; update pick-up X position
	STA SPRITE_RAM+11,X
	CLC
	ADC #$08
	STA SPRITE_RAM+7,X				; update pick-up X position
	STA SPRITE_RAM+15,X
	
	JSR GetRandom
	JSR FixRandom

	STA <PICKUP_Y
	STA SPRITE_RAM,X				; update pick-up Y position
	STA SPRITE_RAM+4,X
	CLC
	ADC #$08
	STA SPRITE_RAM+8,X				; update pick-up Y position
	STA SPRITE_RAM+12,X
	RTS
	
InitMetaSprite:
	LDX <META_NUM          		; which meta sprite are we talking about?
	LDA MetaSpriteOffset,X		; gives us the offset into the spriteRAM ($0200)	
	TAX							; X now contains offset

	LDY #0						; load all values for each 8x8 sprite
.1
	LDA MetaBlockCollision,X    ; MetaBlockCollision is used BECAUSE IT IS FIRST SPRITE IN LIST!!!    	
	STA SPRITE_RAM,X
	INX
	INY
	CPY #16
	BNE .1
	
	RTS	
	
LoadBackground:				; load background function
	LDA PPU_STATUS			; NECESSARY... this tells the PPU to expect the high byte next
	LDA #$20				; high byte of addr. in PPU addr. space
	STA PPU_ADDR            ; write the high byte of $2000 address
	LDA #$00				; low byte of addr. in PPU addr. space
	STA PPU_ADDR            ; write the low byte of $2000 address, completes address ($2000)
	STX <TEMP				; store LOW byte of address to background location in TEMP
	STY <TEMP+1				; store HIGH byte of address to background location in TEMP+1
	LDX #4              	; start out at 4 (outer loop)
	LDY #0					; start out at 0 (inner loop)
.1							; must loop 4x times to copy entire screen's worth of tiles + attribute table
							; [NOTE: during the last loop, the final tiles are loaded along with the background's attribute table]
							; [NOTE: this happens b/c 1024 bytes are stored linearly ($2000-$2400) for each background]
	LDA [TEMP],Y  			; load data from address $[nam_high+nam_low] + the value in Y, indirect indexed address mode
	STA PPU_DATA            ; write to PPU memory address (begins at $2000, but increments 1 byte each STA)
	INY                   	; Y++
	BNE .1  				; branch to .1 if (Y != 0) Y must complete full cycle, i.e. copying 256 bytes
							; if status register zero bit is HIGH, keep going down
	INC <TEMP+1				; increment nam_high to move to the next 256 background tiles
	DEX						; X--
	BNE .1					; branch to .1 if (X != 0)
	RTS

PalFadeTable:
	.db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0f,$0e,$0f
	.db $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1f,$1e,$1f
	.db $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2e,$2f
	.db $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3a,$3b,$3c,$3d,$3e,$3f
	.db $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
	.db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0f,$0e,$0f
	.db $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1f,$1e,$1f
	.db $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2e,$2f
	.db $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
	.db $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
	.db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0f,$0e,$0f
	.db $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1f,$1e,$1f
	.db $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
	.db $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
	.db $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
	.db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0f,$0e,$0f
	
ParkesPal:						
	.incbin "parkes.pal"		; parkes background pal
	.incbin "parkes.pal"		; parkes sprite pal
RB3Pal:
	.incbin "rb3.pal"			; rb3 background pal
	.incbin "rb3.pal"			; rb3 sprite pal
ParkesBG:						; (nametable + attribute table) starts here, contained in same file
	.incbin "parkes.nam"		; include nametable (960 bytes) + attribute table (64 bytes)
TitleBG:						; (nametable + attribute table) starts here, contained in same file
	.incbin "title.nam"			; include nametable (960 bytes) + attribute table (64 bytes)
GameBG:							; (nametable + attribute table) starts here, contained in same file
	.incbin "game.nam"			; include nametable (960 bytes) + attribute table (64 bytes)