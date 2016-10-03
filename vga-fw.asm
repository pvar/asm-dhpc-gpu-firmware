; *****************************************************************************
;
;   Code for microcontroller on graphics circuit
;
; *****************************************************************************
;
;   Panos Varelas (12/02/2015)
;
;   deltaHacker magazine [http://deltahacker.gr]
;
; *****************************************************************************





; -----------------------------------------------------------------------------
;   macros
; -----------------------------------------------------------------------------

.include "0.macros.asm"

; -----------------------------------------------------------------------------
;   constants
; -----------------------------------------------------------------------------

.include "m644def.inc"

.equ bfsel			= 0		; PINB0
.equ vsync			= 1		; PINB1
.equ hsync			= 2		; PINB2
.equ disout			= 3		; PINB3
.equ ramread		= 4		; PINB4
.equ ramenable		= 5		; PINB5
.equ byteread		= 6		; PINB6
.equ newbyte		= 7		; PINB7

; commands from CPU
.equ vid_reset      = 200
.equ vid_clear      = 201
.equ vid_pixel      = 202
.equ vid_line       = 203
.equ vid_box        = 204
.equ vid_locate	    = 205
.equ vid_color 	    = 206
.equ vid_paper 	    = 207
.equ vid_scroll_off = 208
.equ vid_scroll_on  = 209
.equ vid_cursor_off = 210
.equ vid_cursor_on  = 211

; control characters
.equ chr_return 	= 13
.equ chr_backspace	= 8
.equ chr_home		= 1
.equ chr_end		= 2
.equ chr_left		= 16
.equ chr_right		= 17
.equ chr_up			= 19
.equ chr_down		= 20

; program status flags
.equ eof_flag		= 0b10000000
.equ cursor_flag	= 0b01000000
.equ scroll_flag	= 0b00100000

; -----------------------------------------------------------------------------
;   registers & variables
; -----------------------------------------------------------------------------

; X: not used
; Y: not used

; Z: inside ISR:  pointer for table with scnaline data
; Z: outside ISR: pointer for tables with font and logo-image

; r3..r12: used for speed, instead of normal stack

.def cursorX = r13			; buffer address low byte for given text location
.def cursorY = r14			; buffer address high byte for given text location
.def zero = r15				; always equal to zero
.def isr_temp1 = r16		; temporary values (inside ISR)
.def isr_temp2 = r17		; temporary values (inside ISR)
.def isr_temp3 = r2			; temporary values (inside ISR)
.def tmp1 = r18				; temporary values (outside ISR)
.def tmp2 = r19				; temporary values (outside ISR)
.def tmp3 = r20				; temporary values (outside ISR)
.def tmp4 = r21				; temporary values (outside ISR)
.def data = r22				; data from CPU
.def color = r23			; foreground (text) colour
.def paper = r24			; background color

.def status = r25			; various program flags
;							  b7: end of frame
;							  b6: cursor on/off
;							  b5: scroll on/off
;							  b4..b0: not used

.equ scratchH = 0x01		; temporary storage for data from frame buffer
.equ scratchL = 0x00		; maximum size: 3584bytes -- reserve 512 bytes for the stack

.equ fcnt = GPIOR0			; frame counter for cursor update
.equ sl_offset = GPIOR1		; scnaline offset (for smooth scrolling)
.equ var2 = GPIOR2			; General Purpose IO register

; -----------------------------------------------------------------------------
;   code segment initialization
; -----------------------------------------------------------------------------

.cseg
.org 0
	rjmp mcu_init				; Reset Handler
.org OC1Aaddr
	rjmp scanline				; Timer1 CompareA interrupt Handler

; -----------------------------------------------------------------------------
;   microcontroller peripherals' initialization
; -----------------------------------------------------------------------------

mcu_init:
	ldi tmp1, $10				; set Stack Pointer high-byte
	out SPH, tmp1				;
	ldi tmp1, $FF				; set Stack Pointer low-byte
	out SPL, tmp1				;

	; port pins
	ser tmp1					;
	out DDRA, tmp1				; set all pins as outputs (address-bus high byte)
	out DDRC, tmp1				; set all pins as outputs (address-bus low byte)
	out DDRB, tmp1				; set all pins as outputs (control signals)
	cbi DDRB, newbyte			; ...but this pin should be input (CPU signal)
	cbi PORTB, newbyte			; no pull-up resistor
	cbi PORTB, bfsel			; select frame buffer 1
	sbi PORTB, ramenable		; enable SRAM
	sbi PORTB, disout			; disable video output
	sbi PORTB, byteread			; make CPU wait: a command is being processed

	; analog to digital converter
	lds tmp1, ADCSRA			; turn off ADC
	cbr tmp1, 128				; set ADEN bit to 0
	sts ADCSRA, tmp1			;
	lds tmp1, ACSR				; turn off and disconnect analog comp from internal v-ref
	sbr tmp1, 128				; set ACD bit to 1
	cbr tmp1, 64				; set ACBG bit to 1
	sts ACSR, tmp1				;

	; watchdog
	lds tmp1, WDTCSR			; stop WDT
	andi tmp1, 0b10110111		; clear WDIE and WDE
	sts WDTCSR, tmp1			;

	; further power reduction
	ldi tmp1, 0b1000111			; shutdown ADC, TWI, SPI and USART0
	sts PRR0, tmp1				; set PRADC, PRTWI, PRSPI and PRUSART0 to 1

	; timer / counter 1
	clr tmp1					;
	sts TCCR1A, tmp1			; enable CTC mode
	ldi tmp1, 0b00001001		; no prescaling
	sts TCCR1B, tmp1			;

	ldi tmp1, 0b00000010		; load 635 in OCR1A
	sts OCR1AH, tmp1			;
	ldi tmp1, 0b01111011		; (interrupt for scanlines)
	sts OCR1AL, tmp1			;

	ldi tmp1, 2					;
	sts TIMSK1, tmp1			; enable interrupt on match A 

; -----------------------------------------------------------------------------
;   program initialization
; -----------------------------------------------------------------------------

	clr zero					; always equals to zero
	out fcnt, zero				; clear frame counter

	ldi tmp1, 1					; initialize scanline offset
	out sl_offset, tmp1			;

	ldi ZH, high(linedata*2)	; initialize linedata pointer and save
	ldi ZL, low(linedata*2)		;
	movw r4, ZL					;

	sbr status, cursor_flag 	; turn cursor on
	sbr status, scroll_flag 	; turn scroll on

	clr cursorX					; set initial cursor position
	clr cursorY					;

	ldi color, 76				; set default colours
	ldi paper, 0				;

	call clearall				; clear all video memory
	sei							; enable interrupts

; -----------------------------------------------------------------------------
;   main program loop
; -----------------------------------------------------------------------------

main_loop:
	call get_byte				; get new command

	cpi data, 128				; check for standard ASCII characters
	brsh execute_command		;
	call putchar				;
	rjmp main_loop

execute_command:
	subi data, 200				; subtract 200 to get offset
	brlo main_loop

	ldi ZH, high(jumplist*2)	; get jumplist starting address
	ldi ZL, low(jumplist*2)		;

	lsl data					; multiply offset (table contains words nots bytes)

	add ZL, data				; add offset to jumplist pointer
	adc ZH, zero				;

	lpm tmp1, Z+				; get address-to-call from jumplist
	lpm ZH, Z					;
	mov ZL, tmp1				;

	icall
	rjmp main_loop

; ----------------------------------------------------------------





; -----------------------------------------------------------------------------
;   ISR for creating scanlines
; -----------------------------------------------------------------------------

scanline:

; VARIABLE DELAY --> 4 ~ 5 cycles ---------------------------------------------

	lds isr_temp1, TCNT1L		; (2)
	sbrc isr_temp1, 0			; (1~2)
	rjmp vdelay_end				; (2)
vdelay_end:

; HORIZONTAL SYNC PULSE --> 37 cycles -----------------------------------------

	cbi PORTB, hsync			; (2)	start horizontal sync pulse

	in r10, SREG				; (1)	save SREG	
	in isr_temp1, PORTB			; (1)	save control signals
	sbr isr_temp1, (1<<hsync)	; (1)	restore initial state of hsync-pin
	mov r3, isr_temp1			; (1)
	movw r6, ZL					; (1)	save Z pointer
	movw ZL, r4					; (1)	restore linedata pointer


	; CHECK FOR END OF FRAME
	lpm isr_temp2, Z+			; (3)	get 1st byte from scanline table
	cpi isr_temp2, 255			; (1)	check for end of frame
	breq frame_end				; (1~2)
	cbr status, eof_flag		; (1)	clear end-of-frame flag
	nop							; (1)
	nop							; (1)
	nop							; (1)
	rjmp vertical_sync			; (2)


	; END OF FRAME
frame_end:						; ---
	sbr status, eof_flag		; (1)	set end-of-frame flag
	; CHECK IF CURSOR NEEDS UPDATE
ct_check:						; ---
	in isr_temp1, fcnt			; (1)
	sbrc isr_temp1, 6			; (1~2)	check if cursor needs update
	rjmp ct_ck_end				; (2)	if needs update, don't increase counter
	ldi isr_temp2, 15			; (1)
	andi isr_temp1, 0b00011111	; (1)	keep timer part
	cp isr_temp1, isr_temp2		; (1)
	brne ct_not_yet				; (1~2)
	; ...IT DOES
	in isr_temp1, fcnt			; (1)
	andi isr_temp1, 0b11000000	; (1)	keep status bits -- clear timer part
	sbr isr_temp1, 0b01000000	; (1)	signal cursor update
	out fcnt, isr_temp1			; (1)	save frame counter
	rjmp rst_scnptr				; (2)
	; ...IT DOES NOT
ct_not_yet:
	in isr_temp1, fcnt			; (1)
	inc isr_temp1				; (1)
	out fcnt, isr_temp1			; (1)
	rjmp rst_scnptr				; (2)
ct_ck_end:
	nop_x4						; (4)
	nop_x4						; (4)
	nop							; (1)
	; RESET POINTER IN SCANLINE TABLE
rst_scnptr:						; ---
	ldi ZH, high(linedata*2)	; (1)
	ldi ZL, low(linedata*2)		; (1)
	lpm isr_temp2, Z+			; (3)	keep for VIDEO BLANKING check


	; START / STOP VERTICAL SYNC PULSE
vertical_sync:					; ---
	sbrc isr_temp2, 7			; (1~2)
	cbi PORTB, vsync			; (2)
	sbrs isr_temp2, 7			; (1~2)
	sbi PORTB, vsync			; (2)


	lpm isr_temp1, Z+			; (3)	get 2nd byte from scanline table
	movw r4, ZL					; (1)	save linedata pointer
	movw ZL, r6					; (1)	restore Z pointer

	in isr_temp3, sl_offset		; (1)	get scanline offset
	add isr_temp1, isr_temp3	; (1)	add scanline offset

	nop_x2						; (2)
	nop							; (1)

	sbi PORTB, hsync			; (2)	stop horizontal sync pulse


	; CHECK FOR VERTICAL VIDEO BLANKING
	sbrc isr_temp2, 6			; (1~2)	if set -> exit ISR
	reti						; (4)

; BACK PORCH --> 30 cycles ----------------------------------------------------
active_line:
	in r11, PORTA				; (1)	save address-bus high byte
	in r12, PORTC				; (1)	save address-bus low byte
	in r8, PORTD				; (1)	save data-bus data
	in r9, DDRD					; (1)	save data-bus direction
	sbi PORTB, ramenable		; (2) 	enable SRAM
	sbi PORTB, ramread			; (2)	set SRAM READ mode
	release_dbus				; (2)	release data-bus
	out PORTA, isr_temp1		; (1)	init address-bus high byte
	out PORTC, zero				; (1)	init address-bus low byte

	nop_x4						; (4)
	nop_x4						; (4)
	nop_x4						; (4)
	nop							; (1)

	ser isr_temp2				; (1)
	cbi PORTB, disout			; (2)	enable video output
	
; ACTIVE VIDEO --> 512 cycles -------------------------------------------------

	get_line_data				; (512)

; FRONT PORCH --> 11 cycles ---------------------------------------------------

	out PORTA, r11				; (1)	restore address-bus high byte
	out PORTC, r12				; (1)	restore address-bus low byte
	out PORTD, r8				; (1)	restore data-bus data
	out DDRD, r9				; (1)	restore data-bus direction
	out PORTB, r3				; (1)	restore control signals
	out SREG, r10				; (1)	restore SREG
reti							; (5)





.include "1.prep.asm"
.include "2.cursor.asm"
.include "2.buffer.asm"
.include "3.lines.asm"
.include "3.font.asm"
.include "3.logo.asm"
.include "3.jlist.asm"
