; *****************************************************************************
;   functions for preparing complex commands sent from CPU
; *****************************************************************************



; -----------------------------------------------------------------------------
;   delay program execution until end-of-frame
; -----------------------------------------------------------------------------
wait_frame:
	sbrs status, 7				; check eof_flag bit
	rjmp wait_frame
ret

; -----------------------------------------------------------------------------
;   wait for a character from CPU
; -----------------------------------------------------------------------------
get_byte:
	push tmp1
	push tmp2
	push tmp3
	push tmp4

	cbi PORTB, byteread			; to CPU: done processing (previous byte)

wait_for_byte:
	call wait_frame				; wait until next frame

	; CHECK CURSOR STATE
	sbrs status, 6				; check cursor_flag bit
	rjmp check_CPU_signal

	; UPDATE CURSOR
	in tmp1, fcnt
	sbrc tmp1, 6				; check if cursor has to be toggled
	call ct_toggle				; toggle cursor

	; GET CPU SIGNAL
check_CPU_signal:
	release_dbus				; make data-bus readable
	in tmp1, PINB				;
	sbrs tmp1, newbyte			; wait for CPU signal
	rjmp wait_for_byte			;

	cbi PORTB, ramenable		; disable SRAM - enable tri-state buffer outputs
	clr data					; clear data register
	nop_x4						; wait for pins and latches to settle
	in data, PIND				; get new byte from data-bus
	sbi PORTB, ramenable		; enable SRAM - disable tri-state buffer outputs

	sbi PORTB, byteread			; to CPU: start processing (new byte)

	pop tmp4
	pop tmp3
	pop tmp2
	pop tmp1
ret


; -----------------------------------------------------------------------------
;   get parameters for "complicated" commands end execute them
; -----------------------------------------------------------------------------

reset:
	out fcnt, zero				; reset cursor state register
	call ct_toggle				; draw cursor (toggle for the first time ;-)
	call clearall				; clear screen
	call splash					; display logo
	ldi color, 76				; set default colors
	mov paper, zero				;
	clr cursorX					; set initial cursor position
	clr cursorY					;
ret

; -----------------------------------------------------------------------------
clear:
	clr_cur						; clear cursor
	clr cursorX					; update cursor position
	clr cursorY					;
	call clrfb					; clear frame buffer
ret

; -----------------------------------------------------------------------------
putchar:
	cpi data, 32
	brlo control_char

	sbrs status, 6				; check cursor_flag bit
	rjmp print_pchar_nocur      ;

; PRINTABLE CHARACTER / CURSOR ACTIVATED
print_pchar_cur:
	clr_cur						; delete cursor (if visible)
	mov tmp1, data				; print sent character
	call print_char				; print received character
	call right					; move cursor to the right
	set_cur						; reinit cursor state
ret
; PRINTABLE CHARACTER / CURSOR DEACTIVATED
print_pchar_nocur:
	mov tmp1, data				; print sent character
	call print_char				; print received character
	call right					; move cursor to the right
ret

control_char:
	sbrs status, 6				; check cursor_flag bit
	rjmp print_cchar_nocur      ;

; CONTROL CHARACTER / CURSOR ACTIVATED
print_cchar_cur:
	clr_cur						; delete cursor (if visible)
	call print_ctrl				; print control character
	set_cur						; reinit cursor state
ret

; CONTROL CHARACTER / CURSOR DEACTIVATED
print_cchar_nocur:
	call print_ctrl				; print control character
ret

; -----------------------------------------------------------------------------
pset:
	call get_byte				; get X coordinate
	mov tmp2, data				;
	call get_byte				; get Y coordinate
	mov tmp3, data				;
	call get_byte				; get color
	mov tmp4, data				;
	call pixel					; draw pixel
ret

; -----------------------------------------------------------------------------
line:
; not implemented!
ret

; -----------------------------------------------------------------------------
box:
; not implemented!
ret

; -----------------------------------------------------------------------------
locate:
	call get_byte				; get line
	mov tmp1, data				;
	call get_byte				; get column
	mov tmp4, data				;

	clr_cur						; clear cursor
	mov cursorY, tmp1			; update cursor position
	mov cursorX, tmp4			;
ret


; -----------------------------------------------------------------------------
set_pen:
	call get_byte				; get colour
	mov color, data				;
ret


; -----------------------------------------------------------------------------
set_paper:
	call get_byte				; get colour
	mov paper, data				;
ret

; -----------------------------------------------------------------------------
cursor_off:
	clr_cur						; delete cursor (if visible)
	cbr status, cursor_flag 	; turn cursor off
ret


; -----------------------------------------------------------------------------
cursor_on:
	sbr status, cursor_flag 	; turn cursor on
	set_cur						; reset cursor state
ret


; -----------------------------------------------------------------------------
scroll_off:
	cbr status, scroll_flag 	; turn scroll off
ret


; -----------------------------------------------------------------------------
scroll_on:
	sbr status, scroll_flag 	; turn scroll on
ret
