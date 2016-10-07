; *****************************************************************************
; functions for reading and writing on frame buffer
; *****************************************************************************



; -----------------------------------------------------------------------------
;   clear active buffer
; -----------------------------------------------------------------------------
clrfb:
	ldi tmp1, 1				; initialize scanline offset
	out sl_offset, tmp1		;

	cbi PORTB, ramread		; set SRAM WRITE mode
	occupy_dbus				; take control of data bus

	out PORTD, paper
	out PORTA, tmp1
	ldi tmp2, 240
clr1:
	clr tmp1
clr2:
	out PORTC, tmp1
	dec tmp1
	brne clr2

	in tmp1, PORTA
	inc tmp1
	out PORTA, tmp1
	dec tmp2
	brne clr1

	release_dbus			; release data bus
	sbi PORTB, ramread		; set SRAM READ mode
ret

; -----------------------------------------------------------------------------
;   clear all video memory
; -----------------------------------------------------------------------------
clearall:
	ldi tmp1, 1				; initialize scanline offset (not with zero!)
	out sl_offset, tmp1		;

	cbi PORTB, ramread		; set SRAM WRITE mode
	occupy_dbus				; take control of data bus

	ldi tmp3, 2
clragain:
	sbi PINB, bfsel			; toggle selected frame buffer
	out PORTA, zero

	clr tmp2
clrall1:
	clr tmp1
clrall2:
	out PORTC, tmp1
	dec tmp1
	brne clrall2
	in tmp1, PORTA
	inc tmp1
	out PORTA, tmp1
	dec tmp2
	brne clrall1
	dec tmp3				; repeat for the other frame buffer
	brne clragain			;

	release_dbus			; release data bus
	sbi PORTB, ramread		; set SRAM READ mode
ret

; -----------------------------------------------------------------------------
;   print control character (data)
; -----------------------------------------------------------------------------
print_ctrl:
	cpi data, chr_return	; CR
	breq jmp_chr_enter
	cpi data, chr_backspace	; BACKSPACE
	breq jmp_chr_backspace
	cpi data, chr_up		; ARROW UP
	breq jmp_chr_up
	cpi data, chr_down		; ARROW DOWN
	breq jmp_chr_down
	cpi data, chr_left		; ARROW LEFT
	breq jmp_chr_left
	cpi data, chr_right		; ARROW RIGHT
	breq jmp_chr_right
	cpi data, chr_home		; HOME
	breq jmp_chr_home
	cpi data, chr_end		; END
	breq jmp_chr_end
ret

jmp_chr_enter:		rjmp char_enter
jmp_chr_backspace:	rjmp char_backspace
jmp_chr_up: 		rjmp char_up
jmp_chr_down: 		rjmp char_down
jmp_chr_left: 		rjmp char_left
jmp_chr_right:		rjmp char_right
jmp_chr_home:		rjmp char_home
jmp_chr_end:		rjmp char_end

; -------------------------------------------------------------
char_enter:
	clr cursorX				; move cursor to first column
	mov tmp3, cursorY		; check if already on last line
	cpi tmp3, 23			;
	breq char_enter_roll	;
	inc cursorY				; move to next line (do not scroll)
ret
char_enter_roll:
	call roll
ret
; -------------------------------------------------------------
char_backspace:
	call left
	ldi tmp1, 32
	call print_char
ret
; -------------------------------------------------------------
char_up:
	call up
ret
; -------------------------------------------------------------
char_down:
	call down
ret
; -------------------------------------------------------------
char_left:
	call left
ret
; -------------------------------------------------------------
char_right:
	call right
ret
; -------------------------------------------------------------
char_home:
	call get_byte			; get "lines to move up"
char_home_loop:
	dec data				;
	breq char_home_end		;
	call up					; move up a line
	rjmp char_home_loop
char_home_end:
	clr_cur					;
	clr cursorX				;
ret
; -------------------------------------------------------------
char_end:
	call get_byte			; get "lines to move down"
char_end_loop:
	dec data				;
	breq char_and_end		;
	call down				; move up a line
	rjmp char_end_loop
char_and_end:
	call get_byte			; get "column to go"
	clr_cur					;
	mov cursorX, data		;
ret

; -----------------------------------------------------------------------------
;   print printable character (tmp1)
; -----------------------------------------------------------------------------
print_char:
	ldi ZH, high(fontdata*2)
	ldi ZL, low(fontdata*2)

	subi tmp1, 32			; subtract 32 from ASCII code -- font table begins from character code 32
	ldi tmp2, 10			; each character is described by 10 bytes
	mul tmp1, tmp2			; multiply by 10, to get offset in font-table
	add ZL, r0				; add offset to pointer
	adc ZH, r1				;

	ldi tmp1, 10			; set high-byte of address in frame buffer
	mul tmp1, cursorY		;
	in tmp1, sl_offset		;
	add r0, tmp1			;
	out PORTA, r0			;

	ldi tmp2, 8				; set high-byte of address in frame buffer
	mul tmp2, cursorX		;
	out PORTC, r0			;
	mov tmp3, r0			;

	occupy_dbus				; take control of data bus

	ldi tmp4, 10
get_font_byte:
	lpm r0, Z+
	out PORTC, tmp3

	ldi tmp2, 8
parse_bits:
	mov tmp1, paper
	sbrc r0, 7
	mov tmp1, color
	out PORTD, tmp1
	lsl r0
	cbi PORTB, ramread		; set SRAM WRITE mode
	nop_x4
	sbi PORTB, ramread		; set SRAM READ mode
	dec tmp2
	breq print_next_line

	in r1, PORTC
	inc r1
	out PORTC, r1
	rjmp parse_bits

print_next_line:
	dec tmp4
	breq print_end

	in r1, PORTA
	inc r1
	out PORTA, r1
	rjmp get_font_byte

print_end:
	release_dbus			; release data bus
ret

; -----------------------------------------------------------------------------
;   roll frame buffer one text-line up
; -----------------------------------------------------------------------------
roll:
	in tmp1, sl_offset		;
	subi tmp1, -10			; increase scanline offset
	out sl_offset, tmp1		;

; clear last text-line
	ldi tmp4, 10			; number of pixel-lines to clear
	ser tmp3
	out DDRD, tmp3
	out PORTD, paper
	cbi PORTB, ramread
	in tmp1, sl_offset
	subi tmp1, -230
rl_clr_line:
	out PORTA, tmp1
	clr tmp2
rl_clr_pixel:
	out PORTC, tmp2
	nop
	nop
	inc tmp2
	brne rl_clr_pixel
	inc tmp1
	dec tmp4
	brne rl_clr_line
	sbi PORTB, ramread
ret

; -----------------------------------------------------------------------------
;   put a pixel at x, y (tmp2, tmp3) of given color (tmp4)
; -----------------------------------------------------------------------------
pixel:
	in tmp1, sl_offset		; add scanline offset to y coordinate
	add tmp3, tmp1			;
	out PORTA, tmp3			; set address high byte (pixel y-coordinate)
	out PORTC, tmp2			; set address low byte (pixel x-coordinate)
	out PORTD, tmp4			; set pixel color

	ser tmp4
	out DDRD, tmp4

	cbi PORTB, ramread		; set SRAM WRITE mode
	nop_x4
	sbi PORTB, ramread		; set SRAM READ mode

	release_dbus			; release data bus
ret

; -----------------------------------------------------------------------------
;   copy splash from program memory to frame buffer
; -----------------------------------------------------------------------------
splash:
	ldi ZH, high(logo*2)
	ldi ZL, low(logo*2)

	ldi tmp1, 100
sp_put_line:
	out PORTA, tmp1
	ldi tmp2, 96
sp_put_pixel:
	out PORTC, tmp2

	ser XL
	out DDRD, XL
	lpm r0, Z+
	out PORTD, r0
	cbi PORTB, ramread		; set SRAM WRITE mode
	nop
	sbi PORTB, ramread		; set SRAM READ mode
	out DDRD, zero

	inc tmp2
	cpi tmp2, 148
	brne sp_put_pixel

	inc tmp1
	cpi tmp1, 114
	brne sp_put_line
ret
