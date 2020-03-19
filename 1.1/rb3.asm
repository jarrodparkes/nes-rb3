;------------------------------------------------------------------------------------------\
; Title: Red Block, Blue Block
; Author: Jarrod Parkes
; System: Nintendo Entertainment System
; Date: December 25, 2012
; Current Version: v1.1
; Assembler: NESASMv3.01
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; REVISION LIST
; v1.0 		- Draws background/sprites, controller input for movement
; v1.0.1 	- Added title/game screens and transition 
; v1.1		- Gameplay, scoring, screen transitions, and design document
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; SAMPLE RAM MAP
;
; 0-Page
; $0000-$000F	 16 bytes	 Local variables, temps, function arguments
; $0010-$00FF	 240 bytes	 Global variables accessed most often, including certain pointer tables
;
; 1-Page (mostly stack, but since full stack is not normally used, also VRAM buffer) 
; $0100-$019F	 160 bytes	 VRAM Buffer
; $01A0-$01FF	 96 bytes	 Stack
;
; 2-Page (sprite-OAM)
; $0200-$02FF	 256 bytes	 Data to be copied to OAM during next vertical blank
;
; 3-Page
; $0300-$03FF	 256 bytes	 Variables used by sound player, and possibly other variables
;
; 4-Page
; $0400-$07FF	 1024 bytes	 Arrays (that change values during exec), extra globals
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [NES HEADER DIRECTIVES]
	.inesprg 1	; using 1x 16KB PRG bank
	.ineschr 4	; using 2x 8KB CHR bank (maximum is 4x)
	.inesmap 3	; mapper 3 = CNROM, CHR bank swapping
	.inesmir 1	; background mirroring  
; [END HEADER]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [#CONSTANTS]
PARKES_STATE 	EQU 0			; at Parkes screen
TITLE_STATE		EQU 1			; at title screen
GAME_STATE		EQU	2			; game screen
OVER_STATE		EQU 3			; end of game screen

GAME_SECOND		EQU 50			; 50 runs through the game loop is considered a "second"
; [END CONSTANTS]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [VARIABLES]

; system variables
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

; zero page variables
FRAME_NUM		EQU $FF		; frame number

TIMER_ONE		EQU $FE		; ones column for the timer
TIMER_TEN		EQU $FD		; tens column for the timer

FADE_OFFSET		EQU	$FC		; where to begin loads in the fade LUT
FADE_MODE		EQU	$FB		; FADE_MODE_NONE, FADE_MODE_IN, FADE_MODE_OUT
PALETTE			EQU	$40		; reference to the current palette in memory (32 bytes)

BLOCK_X			EQU	$FA		; block's position in X
BLOCK_Y			EQU	$F9		; block's position in Y

SCORE_ONE		EQU	$F8		; ones column for the score
SCORE_TEN		EQU	$F7		; tens column for the score
SCORE_HUN		EQU $F6		; hundreds column for the score

RAND_SEED		EQU $F5		; temporary random number (0-255)

TEMP			EQU	$F0		; general purpose storage variables (5 bytes)

INPUT_1			EQU	$EF		; player one input

META_NUM		EQU $EE		; current meta sprite to update (starting at 0)

TIMER_TICK		EQU $ED		; stores how many runs through the game loop is considered a "second"

CUR_STATE		EQU $EC		; the current game state

PICKUP_X		EQU $EB		; pick-up's position in X
PICKUP_Y		EQU $EA		; pick-up's position in Y

; special variables
SPRITE_RAM		EQU $200	; entire page for sprite data
; [END VARIABLES]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [MAIN]
	.code					; starting our code section (PRG-ROM)
	.bank 0					; define bank 0
	.org $C000 				; start location of bank 0 ($C000 in CPU memory space)
RESET:						; initalize system
	SEI						; disable IRQs
	CLD         			; disable decimal mode
	LDX #$40				; X = %01000000
	STX PPU_FRAMECNT 		; disable APU frame IRQ 
	LDX #$FF				; X = top of stack
	TXS         			; set up stack
	INX         			; X = %00000000
	STX PPU_CTRL   			; disable NMI (enter critical section)
	STX PPU_MASK   			; disable rendering
	STX DMC_FREQ   			; disable DMC IRQs
	STX PPU_SCROLL			; set X scroll to zero
	STX PPU_SCROLL			; set Y scroll to zero

	JSR WaitVBlank			; wait for vblank

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
ClrMem:						; about 30K cycles until next VBLANK/NMI, so let's clear out the RAM
	LDA #$00				; load "0000 0000" into the accumulator
	STA $0000, X			; zero out value at this address
	STA $0100, X			; zero out value at this address
	LDA #$FF
	STA $0200, X			; zero out value at this address
	LDA #$00
	STA $0300, X			; zero out value at this address
	STA $0400, X			; zero out value at this address
	STA $0500, X			; zero out value at this address
	STA $0600, X			; zero out value at this address
	STA $0700, X			; zero out value at this address
	INX						; X++
	BNE ClrMem				; branch if the last INX sets X register to zero

	JSR WaitVBlank

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	
	JSR UpdateOAM			; move all sprites off-screen
	
ClrVRAM:					; clears VRAM for the first two nametables
	LDA #$20
	STA PPU_ADDR
	LDA #$00
	STA PPU_ADDR
	LDX #8
.1
	TAY						; Y = 0
.2
	STA PPU_DATA			; store $00 into at PPU address
	INY						
	BNE .2					; if(Y == 0) { end } else { goto .2 }
	DEX
	BNE .1					; if(X == 0) { end } else { goto .1 }

	JSR EmptyPalette		; clear palletes
	
	LDA #00					
	JSR BankSwitch			; switch to Parkes CHR-ROM bank
	
	JSR WaitVBlank			; wait for vblank
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		
VideoSettings:				; set system video settings
	LDA #%10001000   		; enable NMI, sprites from $1000, background from $0000
	STA PPU_CTRL			; set PPU status register one (PPU_CTRL)
	
LoadParkesBack:	
	LDA #0					
	STA PPU_MASK			; turn off rendering of sprites and background

	; it takes longer than one VBlank period to copy the background/palette, but that is okay
	; b/c rendering is turned off. once we finish copying, wait until the next VBlank
	; and then turn the screen back on ;)
	LDX #LOW(ParkesBG)
	LDY #HIGH(ParkesBG)
	JSR LoadBackground
	LDX #LOW(ParkesPal)
	LDY #HIGH(ParkesPal)
	JSR LoadPalette
	JSR ResetPPUAdr			; resets the PPU address
	JSR SetFadeIn
	
	JSR WaitTillNMI			; we've finished drawing graphics, vblank has hit, turn screen on

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	
	JSR UpdatePalette
	JSR ResetPPUAdr	
	JSR WaitTillNMI
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	LDA #%00001110   		; enable background, no clipping on left side
	STA PPU_MASK			; set PPU status register two (PPU_MASK)
	
EnterParkes:
	JSR WaitFadeDone
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
AtParkes:
	JSR ReadInput1
	JSR HandleInput1B
	LDA <FADE_MODE
	CMP #FADE_MODE_OUT
	BEQ ExitParkes
	JMP AtParkes

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
ExitParkes:
	JSR WaitTillNMI
	JSR WaitFadeDone
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	LDA #0
	STA PPU_MASK   			; turn off rendering of sprites and background	
	LDA #01
	JSR BankSwitch			; switch to RB3 CHR-ROM bank
	
	; it takes longer than one VBlank period to copy the background/palette, but that is okay
	; b/c rendering is turned off. once we finish copying, wait until the next VBlank
	; and then turn the screen back on ;)
LoadTitleBack:
	LDX #LOW(TitleBG)
	LDY #HIGH(TitleBG)
	JSR LoadBackground
	LDX #LOW(RB3Pal)
	LDY #HIGH(RB3Pal)
	JSR LoadPalette
	JSR ResetPPUAdr
	JSR SetFadeIn
	
	JSR WaitTillNMI			; we've finished drawing graphics, vblank has hit, turn screen on
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	JSR UpdatePalette
	JSR ResetPPUAdr	
	JSR WaitTillNMI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	
	LDA #%00001110   		; enable background, no clipping on left side
	STA PPU_MASK			; set PPU status register two (PPU_MASK)
	
EnterTitle:
	JSR WaitFadeDone
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
AtTitle:
	JSR ReadInput1
	JSR HandleInput1B
	LDA <FADE_MODE
	CMP #FADE_MODE_OUT
	BEQ ExitTitle
	JMP AtTitle

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
ExitTitle:
	JSR WaitTillNMI
	JSR WaitFadeDone
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	LDA #0
	STA PPU_MASK   			; turn off rendering of sprites and background	
	
LoadGameBack:
	LDX #LOW(GameBG)
	LDY #HIGH(GameBG)
	JSR LoadBackground
	JSR ResetPPUAdr
	JSR SetFadeIn
	
	JSR WaitTillNMI			; we've finished drawing graphics, vblank has hit, turn screen on
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	JSR UpdatePalette
	JSR ResetPPUAdr
	JSR WaitTillNMI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	
	LDA #%00011110   		; enable background, no clipping on left side
	STA PPU_MASK			; set PPU status register two (PPU_MASK)
	
EnterGame:
	JSR WaitFadeDone
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

InitGame:					; initalize game values
	LDA #0
	
	STA <TIMER_ONE
	STA <SCORE_ONE
	STA <SCORE_TEN
	STA <SCORE_HUN
	
	STA <META_NUM
	JSR InitMetaSprite		; intialize meta sprite 0 (collision box)
	LDA #1
	STA <RAND_SEED
	STA <META_NUM
	JSR InitMetaSprite		; init meta sprite 1 (block)
	LDA #2
	STA <META_NUM
	STA <CUR_STATE
	JSR InitMetaSprite		; init meta sprite 2 (pick-up)
	LDA #3
	STA <TIMER_TEN
	STA <META_NUM
	JSR InitMetaSprite		; init meta sprite 3 (timer)
	LDA #4
	STA <META_NUM
	JSR InitMetaSprite		; init meta sprite 4 (score)
	
	LDA #GAME_SECOND
	STA <TIMER_TICK
	
	; fix this later, probably don't need MetaBlock .db directives...
	LDA #$88
	STA <BLOCK_X
	STA <BLOCK_Y
	
	LDA #$53
	STA <PICKUP_X
	STA <PICKUP_Y

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

RB3:
	; has the clock ran out?
	LDA <CUR_STATE
	CMP #OVER_STATE
	BEQ GameOver

	; get input, run game logic
	JSR ReadInput1
	JSR HandleInput1A
	JSR GameLogic
	
	; tick game clock?	
	JSR TickTimer
	
	; prepare vram data
	JSR UpdateTimer
	JSR UpdateScore
	
	; wait until vblank, update vram data
	JSR WaitTillNMI
	JSR UpdateVRAM
	JMP RB3     		; jump back to RB3, infinite loop
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

GameOver:
	JSR ReadInput1
	JSR HandleInput1C
	JMP GameOver

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	
; [END MAIN]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [PROCEDURES]
WaitVBlank:				; wait for VBlank to occur, when NMI is turned off
	BIT PPU_STATUS		; logically AND the accumulator value with value at $2002	
	BPL WaitVBlank		; branch if(status register == "1--- ----")
	RTS
	
WaitTillNMI:			; wait for VBlank to occur, when NMI is turned on
	LDA <FRAME_NUM		; load current frame number (<FRAME_NUM indicates low byte, zero page)
.1
	CMP <FRAME_NUM		; compare loaded frame number to current
						; these values will be different if NMI has occured
	BEQ .1				; if equal, check frame number again
	RTS

ResetPPUAdr:
	LDA #0
	STA PPU_ADDR
	LDA #0
	STA PPU_SCROLL
	STA PPU_SCROLL
	RTS
	
WaitFadeDone:
	JSR UpdatePalette
	JSR ResetPPUAdr
	JSR WaitTillNMI
	LDA <FADE_MODE
	CMP #FADE_MODE_NONE
	BNE WaitFadeDone
	RTS

BankSwitch:
	TAX                	; copy A into X
	STA BankValues,X 	; new bank to use
	RTS

GetRandom:
	LDA <RAND_SEED
	ASL a
	BCC .1
	EOR #$CF
.1
	STA <RAND_SEED
	RTS
	
FixRandom:
	LDY #0
.1
	CMP #0
	BEQ .2
	LSR a
	INY
	JMP .1
.2
	LDA #40
.3
	CPY #0
	BEQ .4
	CLC
	ADC #$10		; add 16
	DEY
	BNE .3 
.4
	RTS
	
TickTimer:
	DEC <TIMER_TICK
	BNE .done
	
	LDX #GAME_SECOND
	STX <TIMER_TICK
	
	DEC <TIMER_ONE		; tick one's place
	BMI .tickTen		; if(TIMER_ONE == 0) { --TIMER_TEN }
	BNE .done			
	LDA <TIMER_TEN		
	BEQ .timesUp
	BNE .done
.tickTen
	DEC <TIMER_TEN
	LDA #9
	STA <TIMER_ONE	
.done
	RTS
.timesUp
	LDA #OVER_STATE
	STA <CUR_STATE
	RTS

AddScore:
	LDA #1
	JSR AddToScore
	RTS
	
AddToScore:					; adds the value in the Accumulator to the score
    CLC
    ADC <SCORE_ONE			;add value in A to the ones digit
Loop:
    CMP #10                 ;if result is 10 or more, loop to subtract 10 and
                            ;increment the tens until ones digit is less than 10
    BCC Store
    SEC
    SBC #10
    INC <SCORE_TEN
    BNE Loop
Store:
    STA <SCORE_ONE     		;store the result, then check to make sure the
                            ;tens digit didn't overflow.  Max score = 999
    LDA <SCORE_TEN
Loop2:	
    CMP #10
    BCC Store2
    SEC
	SBC #10
	INC <SCORE_HUN
	BNE Loop2
Store2:
	STA <SCORE_TEN
	LDA <SCORE_HUN
Loop3:
	CMP #10
	BCC End
	LDA #9
	STA <SCORE_ONE
	STA <SCORE_TEN
	STA <SCORE_HUN
End:
	RTS
	
GameLogic:						; checks for pick-ups, re-positions pick-ups, increases score
	LDX #0						; initialize X
	JSR CheckTLCorner			; check top-left corner
	JSR CheckTRCorner			; check top-right corner
	JSR CheckBLCorner			; check bottom-left corner
	JSR CheckBRCorner			; check bottom-right corner
	CPX #1						
	BNE .done					; did we hit the pick-up?
	JSR UpdatePickUp			; move pick-up
	JSR AddScore				; increase score
.done
	RTS

CheckTLCorner:	
	LDA <BLOCK_Y
	CMP <PICKUP_Y
	BCC	.vertRangeDone	; if block-TL is above pick-up top-line, branch to vertRangeDone
	LDA <PICKUP_Y
	CLC
	ADC #15
	CMP <BLOCK_Y
	BCC .vertRangeDone	; if pick-up bottom-line is above block-TL, branch to vertRangeDone
	JMP .horzRangeStart
.vertRangeDone
	RTS
.horzRangeStart
	LDA <BLOCK_X
	CMP <PICKUP_X
	BCC	.done			; if block-TL is to the left of pick-up left-line, branch to done
	LDA <PICKUP_X
	CLC
	ADC #15
	CMP <BLOCK_X
	BCC .done			; if pick-up right-line is to the left of block-TL, branch to done
	LDX #1				; X = 1, hit success
.done
	RTS

CheckTRCorner:	
	LDA <BLOCK_Y
	CMP <PICKUP_Y
	BCC	.vertRangeDone	; if block-TR is above pick-up top-line, branch to vertRangeDone
	LDA <PICKUP_Y
	CLC
	ADC #15
	CMP <BLOCK_Y
	BCC .vertRangeDone	; if pick-up bottom-line is above block-TR, branch to vertRangeDone
	JMP .horzRangeStart
.vertRangeDone
	RTS
.horzRangeStart
	LDA <BLOCK_X
	CLC
	ADC #15
	CMP <PICKUP_X
	BCC	.done			; if block-TR is to the left of pick-up left-line, branch to done
	STA <TEMP
	LDA <PICKUP_X
	CLC
	ADC #15
	CMP <TEMP
	BCC .done			; if pick-up right-line is to the left of block-TL, branch to done
	LDX #1				; X = 1, hit success
.done
	RTS

CheckBLCorner:	
	LDA <BLOCK_Y
	CLC
	ADC #15
	CMP <PICKUP_Y
	BCC	.vertRangeDone	; if block-BL is above pick-up top-line, branch to vertRangeDone
	STA <TEMP
	LDA <PICKUP_Y
	CLC
	ADC #15
	CMP <TEMP
	BCC .vertRangeDone	; if pick-up bottom-line is above block-BL, branch to vertRangeDone
	JMP .horzRangeStart
.vertRangeDone
	RTS
.horzRangeStart
	LDA <BLOCK_X
	CMP <PICKUP_X
	BCC	.done		; if block is to the left of pick-up left-line, branch to done
	LDA <PICKUP_X
	CLC
	ADC #15
	CMP <BLOCK_X
	BCC .done		; if pick-up bottom-line is above block_X, branch to done
	LDX #1			; X = 1, hit success
.done
	RTS
	
CheckBRCorner:	
	LDA <BLOCK_Y
	CLC
	ADC #15
	CMP <PICKUP_Y
	BCC	.vertRangeDone	; if block-BR is above pick-up top-line, branch to vertRangeDone
	STA <TEMP
	LDA <PICKUP_Y
	CLC
	ADC #15
	CMP <TEMP
	BCC .vertRangeDone	; if pick-up bottom-line is above block-BR, branch to vertRangeDone
	JMP .horzRangeStart
.vertRangeDone
	RTS
.horzRangeStart
	LDA <BLOCK_X
	CLC
	ADC #15
	CMP <PICKUP_X
	BCC	.done		; if block is to the left of pick-up left-line, branch to done
	STA <TEMP+1
	LDA <PICKUP_X
	CLC
	ADC #15
	CMP <TEMP+1
	BCC .done			; if pick-up bottom-line is above block_X, branch to done
	LDX #1				; X = 1, hit success
.done
	RTS

; [END PROCEDURES]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [VBLANK/NMI ENCOUNTERED]
NMI:					; non-maskable interrupt label
	INC <FRAME_NUM		; increment frame number
	RTI					; return from interrupt
; [END NMI CALLBACK]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [EXTRAS]
BankValues:
	.db $00,$01,$02,$03 		; bank numbers	
; [END EXTRAS]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [SECOND 8KB PGR-ROM]
	.bank 1						; define bank 1
	.org $E000					; start location of bank 1 ($E000 in CPU memory space)

		;vert	;tile	;attr	;horz
MetaBlockCollision:
	.db $88,	$2e,	$03,	$88		; top-left corner
	.db $88,	$2e,	$03,	$97		; top-right corner
	.db $97,	$2e,	$03,	$88		; bottom-left corner
	.db $97,	$2e,	$03,	$97		; bottom-right corner

MetaBlock:
	.db $88,	$0a,	$01,	$88		; top-left
	.db $88,	$0b,	$01,	$90		; top-right
	.db $90,	$0c,	$01,	$88		; bottom-left
	.db $90,	$0d,	$01,	$90		; bottom-right

MetaPickUp0:
	.db $53,	$0a,	$00,	$53		; top-left
	.db $53,	$0b,	$00,	$5b		; top-right
	.db $5b,	$0c,	$00,	$53		; bottom-left
	.db $5b,	$0d,	$00,	$5b		; bottom-right

MetaTimer:
	.db $cf,	$00,	$00,	$50		; hundreds digit
	.db $cf,	$00,	$00,	$58		; tens digit
	.db $cf,	$00,	$00,	$60		; ones digit
	.db $ff,	$ff,	$00,	$ff		; not used

MetaScore:
	.db $cf,	$00,	$00,	$c0		; hundreds digit
	.db $cf,	$00,	$00,	$c8		; tens digit
	.db $cf,	$00,	$00,	$d0		; ones digit
	.db $ff,	$ff,	$00,	$ff		; not used
	
MetaSpriteOffset:                  	         
	.db $00,$10,$20,$30,$40      		; starting offset for each meta sprite
	
	.include "graphics.asm"
	.include "input.asm"

; [END SECOND PGR-ROM]
;------------------------------------------------------------------------------------------/
	
;------------------------------------------------------------------------------------------\
; [SYSTEM INTERRUPTS]	
	.org $FFFA 			
	.dw NMI     		; if NMI occurs, goto
	.dw RESET 			; if system is reset, goto
	.dw 0     			; external interrupt IRQ is not used, assign null
; [END INTERRUPTS]
;------------------------------------------------------------------------------------------/

;------------------------------------------------------------------------------------------\
; [CHR-ROM]
	.bank 2					; define bank 2 (chr bank)
	.org $0000				; start location of bank 2 ($0000 in PPU address space)
	.incbin "parkes.chr"   	; includes 8KB graphics file
	
	.bank 3					; define bank 3 (chr bank)
	.org $0000				; start location of bank 3 ($0000 in PPU address space)
	.incbin "rb3.chr"   	; includes 8KB graphics file
	
	; .bank 4					; define bank 4 (chr bank)
	; .bank 5					; define bank 5 (chr bank)
; [END CHR-ROM]
;------------------------------------------------------------------------------------------/