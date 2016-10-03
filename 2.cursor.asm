; *****************************************************************************
;   functions for moving and updating cursor
; *****************************************************************************



; -----------------------------------------------------------------------------
;   toggle cursor visibility
; -----------------------------------------------------------------------------
ct_toggle:
	ldi tmp2, 0b10000000	;
	in tmp1, fcnt			;
	eor tmp1, tmp2			; toggle cursor-state bit
	andi tmp1, 0b10111111	; mark as updated (toggled)
	out fcnt, tmp1			;

	sbi PORTB, ramread		; read from SRAM
	release_dbus			;

	ldi tmp1, 10			; set address high byte (pixel line)
	mul tmp1, cursorY		;
	ldi tmp2, 8				;
	add r0, tmp2			;
	in tmp1, sl_offset		;
	add r0, tmp1			;
	out PORTA, r0			;

	mul tmp2, cursorX		; set address low byte (pixel column)
	inc r0					;
	out PORTC, r0			;

	ser tmp2
	ldi tmp3, 6
ct_toggle_bits:
	in tmp1, PIND			; get pixel value
	eor tmp1, tmp2			; toggle pixel value
	occupy_dbus				; write updated pixel value
	out PORTD, tmp1			;
	cbi PORTB, ramread		; write to SRAM
	nop						;
	nop						;
	sbi PORTB, ramread		; read from SRAM
	release_dbus			;
	in tmp1, PORTC			; proceed to next pixel
	inc tmp1				;
	out PORTC, tmp1			;
	dec tmp3				; check if toggled 8 bits
	brne ct_toggle_bits		;
ret

; -----------------------------------------------------------------------------
;   move cursor one character to the right
; -----------------------------------------------------------------------------
right:
	inc cursorX			; increase cursorX
	ldi tmp2, 32		;
	cp cursorX, tmp2	; check if past column-29
	brlo right_end		;
	clr cursorX			;

	inc cursorY			; increase cursorY
	ldi tmp2, 24		;
	cp cursorY, tmp2	; check if past line-23
	brne right_end		;

	dec cursorY			; cursorY can never exceed 23

	sbrs status, 5		; check scroll_flag bit
	rjmp right_end		;
	call roll			; roll screen
right_end:
ret

; -----------------------------------------------------------------------------
;   move cursor one character to the left
; -----------------------------------------------------------------------------
left:
	dec cursorX			; decrease cursorX
	brpl left_end		; check if before column-0
	ldi tmp2, 31		;
	mov cursorX, tmp2	;

	dec cursorY			; decrease cursorY
	brpl left_end		; check if before line-0
	clr cursorY			;
left_end:
ret

; -----------------------------------------------------------------------------
;   move cursor one line up
; -----------------------------------------------------------------------------
up:
	dec cursorY			; decrease cursorY
	brpl up_end			; check if before line-0
	clr cursorY			;
up_end:
ret

; -----------------------------------------------------------------------------
;   move cursor one line down
; -----------------------------------------------------------------------------
down:
	mov tmp3, cursorY	; copy cursorY to tmp3
	cpi tmp3, 23		; check if already on last line
	breq down_end		;
	inc cursorY			;
down_end:
ret
