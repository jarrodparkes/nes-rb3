;------------------------------------------------------------------------------------------\
; Title: Red Block, Blue Block
; System: Nintendo Entertainment System
; Date: November 19, 2012
; Current Version: v1.0.1
; Assembler: NESASMv3.01
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; REVISION LIST
; v1.0 		- Draws background/sprites, controller input for movement
; v1.0.1 	- Added title/game screens and transition 
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; BUGS
; 1. Screen transition does not work on all emulators. This is because VRAM update
; are happening outside of VBlank and/or the PPU_SCROLL values are getting
; trashed after the screen copying takes place. 
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [NES HEADER DIRECTIVES]
	.inesprg 1	; using 1x 16KB PRG bank
	.ineschr 1	; using 1x 8KB CHR bank
	.inesmap 0	; mapper 0 = NROM, no bank swapping
	.inesmir 1	; background mirroring  
; [END HEADER]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [#DEFINES]
PPU_CTRL		EQU $2000
PPU_MASK		EQU $2001
PPU_STATUS		EQU $2002
PPU_OAM_ADDR	EQU $2003
PPU_OAM_DATA	EQU $2004
PPU_SCROLL		EQU $2005
PPU_ADDR		EQU $2006
PPU_DATA		EQU $2007
PPU_OAM_DMA		EQU $4014
PPU_FRAMECNT	EQU $4017
DMC_FREQ		EQU $4010
CTRL_PORT1		EQU $4016

TITLE_SCREEN 	EQU 0
GAME_SCREEN		EQU 1
; [END DEFINES]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [DECLARE GLOBAL VARIABLES AT ZERO PAGE]
; 	[CURRENT USAGE]
; 		global variables: 	4/256 bytes
; 	[END USAGE]
	.zp				; store these variables in the zero page for fast access
nam_low:	.ds 1	; nam_low - the low byte for where a nametable is stored
nam_high:	.ds 1	; nam_high - the high byte for where a nametable is stored
game_mode:	.ds	1	; game_mode - what game mode are we in? game or title?
back_load:	.ds	1	; back_load - is the background loaded or not?
fade_step:	.ds	1	; fade_step - the number of frames to complete a fade animation
; [END GLOBALS]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [INITIALIZE SYSTEM]
	.code					; starting our code section (PRG-ROM)
	.bank 0					; define bank 0
	.org $8000 				; start location of bank 0 ($8000 in CPU memory space)
RESET:						; initalize system
	SEI						; disable IRQs
	CLD         			; disable decimal mode
	LDX #$40				; load "0100 0000" into X register
	STX $4017   			; disable APU frame IRQ
	LDX #$FF				; load "1111 1111" into X register
	TXS         			; set up stack
	INX         			; now X = 0
	STX $2000   			; disable NMI
	STX $2001   			; disable rendering
	STX $4010   			; disable DMC IRQs

VBlankWait1:				; wait until the first VBLANK/NMI is hit, this ensures PPU is ready
	BIT $2002				; logically AND the accumulator value with value at $2002	
	BPL VBlankWait1			; branch if(status register == "1--- ----")

ClrMem:						; about 30K cycles until next VBLANK/NMI, so let's clear out the RAM
	LDA #$00				; load "0000 0000" into the accumulator
	STA $0000, X			; zero out value at this address
	STA $0100, X			; zero out value at this address
	STA $0200, X			; zero out value at this address
	STA $0300, X			; zero out value at this address
	STA $0400, X			; zero out value at this address
	STA $0500, X			; zero out value at this address
	STA $0600, X			; zero out value at this address
	STA $0700, X			; zero out value at this address
	INX						; X++
	BNE ClrMem				; branch if the last INX sets X register to zero
   
VBlankWait2:      			; wait until the second VBLANK/NMI is hit, this ensures PPU is ready
	BIT $2002				; logically AND the accumulator value with value at $2002
	BPL VBlankWait2			; branch if(status register == "1--- ----")

LoadPalettes:				; load palettes function
	LDA $2002          	 	; read PPU status to reset the high/low latch
	LDA #$3F				; high byte of addr. in PPU addr. space
	STA $2006           	; write the high byte of $3F00 address
	LDA #$00				; low byte of addr. in PPU addr. space
	STA $2006           	; write the low byte of $3F00 address, completes address ($3F00)
	LDX #$00            	; start out at 0
LoadPalettesLoop:			; loop to copy all 32 palette colors
	LDA Palette, X      	; load data from address (palette + the value in X)
	STA $2007           	; write to PPU (at location $3F00)
	INX                 	; X++
	CPX #$20            	; Compare X to hex $20, decimal 32 - copying 32 bytes
	BNE LoadPalettesLoop  	; Branch to LoadPalettesLoop if compare was Not Equal to zero
							; if compare was equal to 32, keep going down	
						
LoadBackG:					; load background function
	LDA #LOW(TitleBackG)	; load the low byte of the background nametable address
	STA nam_low				; store that byte
	LDA #HIGH(TitleBackG)	; load the high byte of the background nametable address
	STA nam_high			; store that byte
	LDA $2002             	; read PPU status to reset the high/low latch
	LDA #$20				; high byte of addr. in PPU addr. space
	STA $2006             	; write the high byte of $2000 address
	LDA #$00				; low byte of addr. in PPU addr. space
	STA $2006             	; write the low byte of $2000 address, completes address ($2000)
	LDX #4              	; start out at 4 (outer loop)
	LDY #0					; start out at 0 (inner loop)
LoadBackGLoop:				; must loop 4x times to copy entire screen's worth of tiles + attribute table
							; [NOTE: during the last loop, the final tiles are loaded along with the background's attribute table]
							; [NOTE: this happens b/c 1024 bytes are stored linearly ($2000-$2400) for each background]
	LDA [nam_low], Y  		; load data from address $[nam_high+nam_low] + the value in Y, indirect indexed address mode
	STA $2007             	; write to PPU memory address (begins at $2000, but increments 1 byte each STA)
	INY                   	; Y++
	BNE LoadBackGLoop  		; branch to LoadBackGLoop if (Y != 0) Y must complete full cycle, i.e. copying 256 bytes
							; if status register zero bit is HIGH, keep going down
	INC nam_high			; increment nam_high to move to the next 256 background tiles
	DEX						; X--
	BNE LoadBackGLoop		; branch to LoadBackGLoop if (X != 0)

InitSprites:				; move all sprites off-screen
	LDA #$FF				; load decimal 255 for the x and y positions of the sprites
	STA $0200, X			; store the x position
	INX						; X++
	INX						; X++
	INX						; X++
	STA $0200, X			; store the y position
	INX						; X++, this moves the offset X to the next sprite's data
	BNE InitSprites			; branch if the last INX sets X register to zero
InitRedBlock:
	LDA Sprites, x        	; load data from address (sprites +  x)
	STA $0200, x          	; store into RAM address ($0200 + x)
	INX                   	; X = X + 1
	CPX #$10              	; Compare X to hex $10, decimal 16
	BNE InitRedBlock   		; Branch to LoadSpritesLoop if compare was Not Equal to zero
							; if compare was equal to 32, keep going down	

SetTitleMode:				; set the initial game mode (title screen)
	LDA TITLE_SCREEN		; load game_mode = TITLE_SCREEN
	STA game_mode			; store TITLE_SCREEN ($00) into game_mode
	STA back_load			; also store $00 into back_load
							
VideoSettings:				; set system video settings
	LDA #%10010000   		; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
	STA $2000				; set PPU status register one (PPU_CTRL)
	LDA #%00011110   		; enable sprites, enable background, no clipping on left side
	STA $2001				; set PPU status register two (PPU_MASK)
; [END INITIALIZATION]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [SYSTEM READY, START GAME]
RB3:				; start the game RB3!
	JMP RB3     	; jump back to RB3, infinite loop
; [END GAME]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [VBLANK/NMI ENCOUNTERED]
NMI:					; non-maskable interrupt label

FigureMode:				; what game_mode are we in?
	LDX game_mode		; load game_mode
	CPX GAME_SCREEN		; does (game_mode == GAME)
	BEQ Draw			; if true, goto GameUpdate
CheckStart:
	LDA #$01			; load decimal 1
	STA $4016			; tell both the controllers to latch buttons 
	LDA #$00			; load decimal 0
	STA $4016       	; tell both the controllers to latch buttons
	LDA $4016       	; player 1 - A
	LDA $4016       	; player 1 - B
	LDA $4016       	; player 1 - Select
	LDA $4016       	; player 1 - Start
	AND #%00000001  	; only look at bit 0
	BEQ CheckStartDone  ; branch to CheckStartDone if button is NOT pressed (0)
	LDA GAME_SCREEN		; start was pressed, load GAME_SCREEN value
	STA game_mode       ; store GAME_SCREEN value 
CheckStartDone:
	RTI					; if false (game_mode == TITLE_SCREEN), continue

GameUpdate:
Draw:
	LDA back_load		; load back_load status
	CMP $00				; has the background been loaded?
	BNE DrawSprites		; if not equal, background has been loaded goto DrawSprites
DrawGameBack:			
	LDA #LOW(GameBackG)		; load the low byte of the background nametable address
	STA nam_low				; store that byte
	LDA #HIGH(GameBackG)	; load the high byte of the background nametable address
	STA nam_high			; store that byte
	LDA $2002             	; read PPU status to reset the high/low latch
	LDA #$20				; high byte of addr. in PPU addr. space
	STA $2006             	; write the high byte of $2000 address
	LDA #$00				; low byte of addr. in PPU addr. space
	STA $2006             	; write the low byte of $2000 address, completes address ($2000)
	LDX #4              	; start out at 4 (outer loop)
	LDY #0					; start out at 0 (inner loop)
DrawGameBackLoop:				; must loop 4x times to copy entire screen's worth of tiles + attribute table
							; [NOTE: during the last loop, the final tiles are loaded along with the background's attribute table]
							; [NOTE: this happens b/c 1024 bytes are stored linearly ($2000-$2400) for each background]
	LDA [nam_low], Y  		; load data from address $[nam_high+nam_low] + the value in Y, indirect indexed address mode
	STA $2007             	; write to PPU memory address (begins at $2000, but increments 1 byte each STA)
	INY                   	; Y++
	BNE DrawGameBackLoop  	; branch to DrawGameBackLoop if (Y != 0) Y must complete full cycle, i.e. copying 256 bytes
							; if status register zero bit is HIGH, keep going down
	INC nam_high			; increment nam_high to move to the next 256 background tiles
	DEX						; X--
	BNE DrawGameBackLoop	; branch to DrawGameBackLoop if (X != 0)
	LDA #$01				; load 1 into the accumulator
	STA back_load			; background has been loaded
	
DrawSprites:
						; draw all sprites
	LDA #$00			; load the low byte of the $0200 address (sprite memory)
	STA $2003  			; set the low byte (00) of the RAM address
	LDA #$02			; load the high byte of the $0200 address (sprite memory)
	STA $4014  			; set the high byte (02) of the RAM address, start the transfer of sprite memory 

InputAndUpdate:			; gather input and update sprite positions
LatchController:		; ready controller for input
	LDA #$01			; load decimal 1
	STA $4016			; tell both the controllers to latch buttons 
	LDA #$00			; load decimal 0
	STA $4016       	; tell both the controllers to latch buttons
ReadA: 					; read player 1 A-button
	LDA $4016       	; player 1 - A
	AND #%00000001  	; only look at bit 0
	BEQ ReadADone   	; branch to ReadADone if button is NOT pressed (0)
	LDA #$01			; load sprite sub-palette 1
	STA $0202       	; store sprite sub-palette 1
	STA $0206       	; store sprite sub-palette 1
	STA $020A       	; store sprite sub-palette 1
	STA $020E       	; store sprite sub-palette 1
ReadADone:        		; handling this button is done
ReadB: 					; read player 1 B-button
	LDA $4016       	; player 1 - B
	AND #%00000001  	; only look at bit 0
	BEQ ReadBDone   	; branch to ReadBDone if button is NOT pressed (0)
	LDA #$00			; load sprite sub-palette 0
	STA $0202       	; store sprite sub-palette 0
	STA $0206       	; store sprite sub-palette 0
	STA $020A       	; store sprite sub-palette 0
	STA $020E       	; store sprite sub-palette 0	
ReadBDone:        		; handling this button is done
ReadSelect:				; read player 1 select button
	LDA $4016			; player 1 - select
ReadSelectDone:			; handling this button is done
ReadStart:				; read player 1 start button
	LDA $4016			; player 1 - start
ReadStartDone:			; handling this button is done
ReadUp: 				; read player 1 - up
	LDA $4016       	; player 1 - up
	AND #%00000001  	; only look at bit 0
	BEQ ReadUpDone 		; branch to ReadUpDone if button is NOT pressed (0)
	LDA $0200       	; load sprite Y position
	SEC             	; make sure carry flag is set
	SBC #$01        	; A = A - 1
	STA $0200       	; save sprite Y position
	LDA $0204       	; load sprite Y position
	SEC             	; make sure carry flag is set
	SBC #$01        	; A = A - 1
	STA $0204	    	; save sprite Y position
	LDA $0208       	; load sprite Y position
	SEC             	; make sure carry flag is set
	SBC #$01        	; A = A - 1
	STA $0208       	; save sprite Y position
	LDA $020C       	; load sprite Y position
	SEC             	; make sure carry flag is set
	SBC #$01        	; A = A - 1
	STA $020C       	; save sprite Y position
ReadUpDone:        		; handling this button is done
ReadDown: 				; read player 1 - down
	LDA $4016       	; player 1 - down
	AND #%00000001  	; only look at bit 0
	BEQ ReadDownDone 	; branch to ReadDownDone if button is NOT pressed (0)
	LDA $0200       	; load sprite Y position
	CLC             	; make sure the carry flag is clear
	ADC #$01        	; A = A + 1
	STA $0200       	; save sprite Y position
	LDA $0204       	; load sprite Y position
	CLC             	; make sure the carry flag is clear
	ADC #$01        	; A = A + 1
	STA $0204	    	; save sprite Y position
	LDA $0208       	; load sprite Y position
	CLC             	; make sure the carry flag is clear
	ADC #$01        	; A = A + 1
	STA $0208       	; save sprite Y position
	LDA $020C       	; load sprite Y position
	CLC             	; make sure the carry flag is clear
	ADC #$01        	; A = A + 1
	STA $020C       	; save sprite Y position
ReadDownDone:        	; handling this button is done
ReadLeft: 				; read player 1 - left
	LDA $4016       	; player 1 - left
	AND #%00000001  	; only look at bit 0
	BEQ ReadLeftDone 	; branch to ReadLeftDone if button is NOT pressed (0)
	LDA $0203       	; load sprite Y position
	SEC             	; make sure carry flag is set
	SBC #$01        	; A = A - 1
	STA $0203       	; save sprite Y position
	LDA $0207       	; load sprite Y position
	SEC             	; make sure carry flag is set
	SBC #$01        	; A = A - 1
	STA $0207	    	; save sprite Y position
	LDA $020B       	; load sprite Y position
	SEC             	; make sure carry flag is set
	SBC #$01        	; A = A - 1
	STA $020B       	; save sprite Y position
	LDA $020F       	; load sprite Y position
	SEC             	; make sure carry flag is set
	SBC #$01        	; A = A - 1
	STA $020F       	; save sprite Y position
ReadLeftDone:        	; handling this button is done
ReadRight: 				; read player 1 - right
	LDA $4016       	; player 1 - right
	AND #%00000001  	; only look at bit 0
	BEQ ReadRightDone 	; branch to ReadRightDone if button is NOT pressed (0)
	LDA $0203       	; load sprite Y position
	CLC             	; make sure the carry flag is clear
	ADC #$01        	; A = A + 1
	STA $0203       	; save sprite Y position
	LDA $0207       	; load sprite Y position
	CLC             	; make sure the carry flag is clear
	ADC #$01        	; A = A + 1
	STA $0207	    	; save sprite Y position
	LDA $020B       	; load sprite Y position
	CLC             	; make sure the carry flag is clear
	ADC #$01        	; A = A + 1
	STA $020B       	; save sprite Y position
	LDA $020F       	; load sprite Y position
	CLC             	; make sure the carry flag is clear
	ADC #$01        	; A = A + 1
	STA $020F       	; save sprite Y position
ReadRightDone:        	; handling this button is done
	
EndNMI:					; end of non-maskable interrupt
	RTI					; return from interrupt
 ; [END NMI CALLBACK]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [GAME ASSETS: PALETTES, BACKGROUNDS, ATTRIBUTE TABLE]
; 	[CURRENT USAGE]
; 		palettes: 			32/8192 bytes
;		name/attr tables:	2048/8192 bytes
;		sprites:			16/8192 bytes
;		interrupts:			?/8192 bytes
; 	[END USAGE]
	.bank 1						; define bank 1
	.org $A000					; start location of bank 1 ($A000 in CPU memory space)
Palette:						; palettes start here
	.incbin "rb3_back.pal"		; background palette
	.incbin "rb3_sprite.pal"	; sprite palette
TitleBackG:						; (nametable + attribute table) starts here, contained in same file
	.incbin "rb3_title.nam"		; include nametable (960 bytes) + attribute table (64 bytes)
GameBackG:						; (nametable + attribute table) starts here, contained in same file
	.incbin "rb3_game.nam"		; include nametable (960 bytes) + attribute table (64 bytes)
Sprites:
;		posX 	tileNum 	attr 	posY
	.db $80, 	$02, 		$00, 	$80   	;sprite 0
	.db $80, 	$02, 		$00, 	$88   	;sprite 1
	.db $88, 	$02, 		$00, 	$80   	;sprite 2
	.db $88, 	$02, 		$00, 	$88   	;sprite 3
; [END ASSETS]
;------------------------------------------------------------------------------------------/
	
;------------------------------------------------------------------------------------------\
; [SYSTEM INTERRUPTS]	
	.org $FFFA 			; first of the three vectors starts here
	.dw NMI     		; when an NMI happens (once per frame if enabled) the 
						; processor will jump to the label NMI:
	.dw RESET 			; when the processor first turns on or is reset, it will jump
						; to the label RESET:
	.dw 0     			; external interrupt IRQ is not used in this tutorial, assign null
; [END INTERRUPTS]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [GAME ASSETS: TILESHEET]
; 	[CURRENT USAGE]
; 		tilesheets:			8192/8192 bytes
; 	[END USAGE]	
	.bank 2				; define bank 2 (chr bank)
	.org $0000			; start location of bank 2 ($0000 in PPU address space)
	.incbin "rb3.chr"   ; includes 8KB graphics file
; [END ASSETS]
;------------------------------------------------------------------------------------------/