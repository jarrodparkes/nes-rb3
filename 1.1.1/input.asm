;------------------------------------------------------------------------------------------\
; Title: Red Block, Blue Block
; Author: Jarrod Parkes
; System: Nintendo Entertainment System
; Date: December 25, 2012
; Current Version: v1.1
; Assembler: NESASMv3.01
;------------------------------------------------------------------------------------------/

A_MASK			EQU %10000000	; A pressed
B_MASK			EQU %01000000	; B pressed
SELECT_MASK		EQU %00100000	; select pressed
START_MASK		EQU %00010000	; start pressed
UP_MASK			EQU %00001000	; up pressed
DOWN_MASK		EQU %00000100	; down pressed
LEFT_MASK		EQU %00000010	; left pressed
RIGHT_MASK		EQU %00000001	; right pressed

TOP_WALL		EQU	32			; top bound for game field
BOTTOM_WALL		EQU	183			; bottom bound for game field
LEFT_WALL		EQU	40			; left bound for game field
RIGHT_WALL		EQU	217			; right bound for game field

ReadInput1:
	LDA #$01
	STA $4016
;ADDED
	STA <INPUT_1 ;Set it to 0000.0001
;
	LDA #$00
	STA $4016
;	LDX #$08 REMOVED
.1
	LDA $4016
	LSR A           ; bit0 -> Carry
	ROL <INPUT_1    ; bit0 <- Carry
;	DEX REMOVED
	BCC .1 ;Changed from BNE
	RTS
	
HandleInput1A:			; handle player movement
	LDA <INPUT_1	
	AND #UP_MASK
	BEQ .UpDone
	JSR CanMoveUp		; upon return if(Y==0) { canMove ] if(Y!=0) { dontMove }
	CPY #0
	BNE .UpDone
	LDA <BLOCK_Y
	SEC
	SBC #$01
	STA <BLOCK_Y
.UpDone
	LDA <INPUT_1
	AND #DOWN_MASK
	BEQ .DownDone
	JSR CanMoveDown		; upon return if(Y==0) { canMove ] if(Y!=0) { dontMove }
	CPY #0
	BNE .DownDone
	LDA <BLOCK_Y
	CLC
	ADC #$01
	STA <BLOCK_Y
.DownDone
	LDA <INPUT_1
	AND #LEFT_MASK
	BEQ .LeftDone
	JSR CanMoveLeft		; upon return if(Y==0) { canMove ] if(Y!=0) { dontMove }
	CPY #0
	BNE .LeftDone
	LDA <BLOCK_X
	SEC
	SBC #$01
	STA <BLOCK_X
.LeftDone
	LDA <INPUT_1
	AND #RIGHT_MASK
	BEQ .RightDone
	JSR CanMoveRight	; upon return if(Y==0) { canMove ] if(Y!=0) { dontMove }
	CPY #0
	BNE .RightDone
	LDA <BLOCK_X
	CLC
	ADC #$01
	STA <BLOCK_X
.RightDone
	JSR UpdateBlock
	RTS

CanMoveUp:			; SPRITE_RAM+0 can be used to check against up collision
	LDY #0
    LDX SPRITE_RAM 	; y-coord of top edge of block
    DEX 			; peek next pixel above
    TXA

    CMP #TOP_WALL
	BCC .1			; branch if target position is less than top wall
    RTS
.1
	LDY #1
    RTS

CanMoveDown:			; SPRITE_RAM+12 can be used to check against down collision
	LDY #0
    LDX SPRITE_RAM+12 	; y-coord of bottom edge of block
    INX 				; peek next pixel below
    TXA

    CMP #BOTTOM_WALL	; branch if target position is less than bottom wall
	BCC .1
	LDY #1
    RTS
.1
    RTS

CanMoveLeft:			; SPRITE_RAM+3 can be used to check against left collision
	LDY #0
    LDX SPRITE_RAM+3 	; x-coord of left edge of block
    DEX 				; peek next pixel to the left
    TXA

    CMP #LEFT_WALL		; branch if target position is less than left wall
	BCC .1
    RTS
.1
	LDY #1
    RTS	
	
CanMoveRight:			; SPRITE_RAM+15 can be used to check against right collision
	LDY #0
    LDX SPRITE_RAM+15 	; x-coord of right edge of block
    INX 				; peek next pixel to the right
    TXA

    CMP #RIGHT_WALL		; branch if target position is less than right wall
	BCC .1
	LDY #1
    RTS
.1
    RTS
	
HandleInput1B:				; handle input test for fade effects
	LDA <INPUT_1
	AND #START_MASK
	BEQ .StartDone
	JSR SetFadeOut
	RTS
.StartDone
	RTS
	
HandleInput1C:				; handle input test for resetting when game is over
	LDA <INPUT_1
	AND #START_MASK
	BEQ .StartDone
	PLA ;Pull the 2 values off the stack from the JSR to keep the stack aligned right, don't want overflows!
	PLA
	LDA #FADE_MODE_OUT
	STA <FADE_MODE ;Set to fade out.
	JMP ExitParkes ;Jump
.StartDone
	RTS