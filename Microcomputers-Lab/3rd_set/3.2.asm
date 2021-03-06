/*
 * Author: Tagarakis Konstantinos
 */
	.include "m16def.inc"

	.DSEG
	_tmp_: .byte 2 
	_number_: .byte 4


.CSEG
	.org 0x000
	rjmp main

main:
	ldi r24, low(RAMEND)
	out SPL, r24
	ldi r24, high(RAMEND)
	out SPH, r24			; stack pointer initialization
		
	; init keypad
	ldi r24 ,(1 << PC7) | (1 << PC6) | (1 << PC5) | (1 << PC4)  
	out DDRC ,r24 
	 
	ser r24
	out DDRB ,r24

	ser r24
	out DDRD, r24
	clr r24

	rcall lcd_init ; display initialization
;--------------------------------------------------------------------------------------------------
;read two hex numbers from keypad
;convert them in decimal
;display them in 4x4 LCD
;--------------------------------------------------------------------------------------------------
;example: input: A1 hex output: 161 dec

;read A hex
;swap 0A --> A0
;read 1
;A1 = A0 + 01
;convert A1 to +161
;display +161
;--------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------- 
loop:

		rcall wait_for_a_key ;  r27 <-- first digit
		
		mov r31 , r27
		push r31

		swap r27 ; before: (4MSB 4LSB) after (4LSB 4MSB)  (before 0A after swap A0)
		push r27 ; save r27  

		call wait_for_a_key ; r27 <-- second digit
		pop r26 ; restore first digit in r26
		
		rcall lcd_init ; init and clear display 
		; CHECK
		pop r31
		push r24
		push r27
		
		cpi r31 ,10
		brge Greater1	
		
		ldi r24, 0x30
		add r24, r31
		rcall lcd_data ; display first hex digit (input) 
		jmp D2

Greater1:
		ldi r24 , 'A'
		add r24 , r31
		ldi r31 , 10
		sub r24 , r31
		rcall lcd_data
	
D2:		cpi r27 ,10
		brge Greater2
		 	
		ldi r24, 0x30		
		add r24, r27
		rcall lcd_data ; display second hex digit (input)
		jmp EQUAL

Greater2:
		ldi r24 , 'A'
		add r24 , r27
		ldi r27 , 10
		sub r24 , r27
		rcall lcd_data

EQUAL:
		ldi r24 ,'='
		rcall lcd_data ; display '='
		pop r27
		pop r24
		; CHECK
		

		add r26,r27 ; 4MSB0000 + 00004LSB = input in hex  (A0 + 01 = A1) 
		mov r20 ,r26 ; (r20 = A0 + 01)

		rcall BCD_convert ; input a hex number in r20 
				  ; converts the number in decimal
				  ; saves the result in memory 
				  ; memory address : _number_
				  ; |  sign (+) | hundreds (1)  | Tens (6)    | Units (1)   | 4 bytes
				  ; _number_  _number_+1  _number_+2 _number_+3
		
		ldi r26 , low(_number_) ; X:R26,r27 points to _number_
		ldi r27 , high(_number_)

		
		
		ld r24 , X+ ; r24 <-[X] , X <- X+1
		rcall lcd_data; displays sign
		

		; lcd_data takes a char and displays it
		; BCD_convert returns integer
		; we need char 
		; if you add 0x30 in a decimal digit becomes a char example : 
		; ascii table
		;	  '1' : 0x31
		;	  '2' : 0x32
		;         '3' : 0x33
                ;          .
		;	   .
		;    	   .
		;	  '9' : 0x39
		
		ldi r20, 0x30 

		ld r24 , X+ ; r24 <-[X] , X <- X+1
		add r24 , r20 ; ex 1 + 0x30 = 0x31 ascii code for char '1' 
		rcall lcd_data;

		ld r24 , X+
		add r24 , r20
		rcall lcd_data;

		ld r24 , X
		add r24 , r20
		rcall lcd_data;

		jmp loop

;--------------------------------------------------------------------------------------------------
;--------------------------------------------------------------------------------------------------		


BCD_convert: ;input r20, output _number_
		push r24
		push r26
		push r27
		
		ldi r28 , low(_number_)
		ldi r29 , high(_number_)


		tst r20 ; check if the number is negative
		brmi minus ;brmi: BRanch if MInus
plus:
		ldi r24, '+' ; r24 <-- '+' :load ascii code of '+' in r24
		st Y+ ,r24 ; save r24 in memory address _number_
		jmp continue

minus:
		ldi r24, '-' ; r24 <-- '-' :load ascii code of '-' in r24
		st Y+ ,r24   ; save r24 in memory address _number_
		
		;2's complement
		clv ; clears overflow flag
		neg r20 ;2's complement
		brvs exception ; branch if overflow 
			  
		
		; convert in decimal
		; flow diagram page 18
continue:
		ldi r24 , 100
		add r20 ,r24
		ldi r24 , -1
		
		;find hundreds 
hundreds:
		subi r20 , 100
		inc r24
		cpi r20 , 100
		brge hundreds
		
		st Y+ ,r24
		
		ldi r24 , 10
		add r20 ,r24
		ldi r24 , -1
decad:
		subi r20, 10
		inc r24
		cpi r20 , 10
		brge decad	
		
		st Y+ ,r24
		
units:
	 	st Y , r20


		pop r27
		pop r26
		pop r24
		ret
		
		;expection occurs only for input 80 hex
		;80 hex --> -128 dec 
exception:	
		ldi r24, 1
		st Y+ ,r24

		ldi r24, 2
		st Y+ ,r24

		ldi r24, 8
		st Y ,r24
		
		pop r27
		pop r26
		pop r24
		ret
	


;--------------------------------------------------------------------------------------------------
;--------------------------------------- keypad routines-------------------------------------------
;--------------------------------------------------------------------------------------------------

wait_for_a_key: ;returns R27 <- to_hex(key)
		push r24
		push r25
		 
Digit:
		ldi r24 , low(20)
		ldi r25 , high(20)
		call scan_keypad_rising_edge
		cp r24, r25
		breq Digit
		call keypad_to_hex
		mov r27, r24
		
		pop r25
		pop r24
		ret

keypad_to_hex:
		; ?????? �1� st?? ??se?? t?? ?ata????t? r26 d??????? 
		movw r26 ,r24 ; ta pa?a??t? s?�???a ?a? a???�???
		ldi r24 , 0x0E
		sbrc r26 ,0
		ret
		ldi r24 , 0x00
		sbrc r26 ,1
		ret
		ldi r24 , 0x0F
		sbrc r26 ,2
		ret     
 		ldi r24 , 0x0D
	    sbrc r26 ,3; a? de? e??a? �1�pa?a??�pte? t?? ret, a????? (a? e??a? �1�) 
		ret; ep?st??fe? �e t?? ?ata????t? r24 t?? ASCIIt?�? t?? D.
		ldi r24 ,0x07
		sbrc r26 ,4
		ret
		ldi r24 ,0x08
		sbrc r26 ,5
		ret	
		ldi r24 ,0x09
		sbrc r26 ,6
		ret
		ldi r24 ,0x0C
		sbrc r26 ,7
		ret
		ldi r24 ,0x04; ?????? �1� st?? ??se?? t?? ?ata????t? r27 d???????
		sbrc r27 ,0; 
		ret
		ldi r24 , 0x05
		sbrc r27 ,1
		ret
		ldi r24 , 0x06
		sbrc r27 ,2
		ret
		ldi r24 ,0x0B
		sbrc r27 ,3
		ret
		ldi r24 ,0x01
		sbrc r27 ,4
		ret
		ldi r24 ,0x02
		sbrc r27 ,5
		ret
		ldi r24,0x03
		sbrc r27 ,6
		ret
		ldi r24 ,0x0A
		sbrc r27 ,7
		ret
		clr r24
		ret
scan_keypad_rising_edge:
		mov r22 ,r24            ; ap????e?se t? ????? sp??????s�?? st?? r22   
		rcall scan_keypad ; ??e??e t? p???t??????? ??a p?es�????? d?a??pte? 
		push r24               ; ?a? ap????e?se t? ap?t??es�a
		push r25
		mov r24 ,r22            ; ?a??st???se r22 ms(t?p???? t?�?? 10-20 msec p?? ?a?????eta? ap? t?? 
		ldi r25 ,0          ; ?atas?e?ast? t?? p???t???????? �?????d????e?a sp??????s�??)
		rcall wait_msec
		rcall scan_keypad; ??e??e t? p???t??????? ?a?? ?a? ap?????e
		pop r23                 ; ?sa p???t?a e�fa?????? sp??????s�?
		pop r22                 
		and r24 ,r22            
		and r25 ,r23
		ldi r26 ,low(_tmp_)     ; f??t?se t?? ?at?stas? t?? d?a??pt?? st??
		ldi r27 ,high(_tmp_)    ; p??????�e?? ???s? t?? ???t??a? st??? r27:r26
		ld r23 ,X+                
		ld r22 ,X
		st X,r24               ; ap????e?se st? RAM t? ??a ?at?stas?
		st -X,r25              ; t?? d?a??pt??
        com r23                   
		com r22                 ; ??e?t??? d?a??pte? p?? ????? ��????� pat??e?
		and r24 ,r22           
		and r25 ,r23
		ret

scan_keypad:
		ldi r24 , 0x01   ; ??e??e t?? p??t? ??a��? t?? p???t????????
		rcall scan_row
		swap r24         ; ap????e?se t? ap?t??es�a
		mov r27 , r24    ; sta 4 msb t?? r27
		ldi r24 ,0x02   ; ??e??e t? de?te?? ??a��? t?? p???t????????
		rcall scan_row
		add r27 , r24    ; ap????e?se t? ap?t??es�a sta 4 lsb t?? r27
		ldi r24 , 0x03     ; ??e??e t?? t??t? ??a��? t?? p???t????????
		rcall scan_row
		swap r24          ; ap????e?se t? ap?t??es�a
		mov r26 , r24   ; sta 4 msb t?? r26
		ldi r24  ,0x04     ; ??e??e t?? t?ta?t? ??a��? t?? p???t????????
		rcall scan_row
		add r26 , r24     ; ap????e?se t? ap?t??es�a sta 4 lsb t?? r26
		movw r24 , r26 ; �et?fe?e t? ap?t??es�a st??? ?ata????t?? r25:r24
		ret

scan_row:
		ldi r25, 0x08 ; a?????p???s? �e �0000 1000�
back_:	lsl r25	; a??ste?? ???s??s? t?? �1� t?se? ??se??
		dec r24 ; ?s?? e??a? ? a???�?? t?? ??a��??
		brne back_
		out PORTC , r25 ; ? a?t?st???? ??a��? t??eta? st? ?????? �1�
		nop
		nop; ?a??st???s? ??a ?a p?????e? ?a ???e? ? a??a?? ?at?stas??
		in r24 , PINC ; ep?st??f??? ?? ??se?? (st??e?) t?? d?a??pt?? p?? e??a? p?es�????
		andi r24 ,0x0f ; ap?�??????ta? ta 4 LSB ?p?? ta �1� de?????? p?? e??a? pat?�???? 
		ret ; ?? d?a??pte?.

;--------------------------------------------------------------------------------------------------
;-------------------------------------------lcd display--------------------------------------------
;--------------------------------------------------------------------------------------------------

lcd_init:
		ldi r24 ,40         ; ?ta? ? e?e??t?? t?? lcd t??f?d?te?ta? �e     
		ldi r25 ,0          ; ?e?�a e?te?e? t?? d??? t?? a?????p???s?.
		rcall wait_msec; ??a�??? 40 msec �???? a?t? ?a ?????????e?.

        ldi r24 ,0x30              ; e?t??? �et??as?? se 8 bitmode	
		out PORTD,r24        ; epe?d? de? �p????�e ?a e?�aste ???a???
		sbi PORTD,PD3        ; ??a t? d?a�??f?s? e?s?d?? t?? e?e??t?
		cbi PORTD,PD3        ; t?? ??????, ? e?t??? ap?st???eta? d?? f????
		ldi r24 ,39
		ldi r25 ,0                     ; e?? ? e?e??t?? t?? ?????? ???s?eta? se 8-bitmode
		rcall wait_usec; de? ?a s?�?e? t?p?ta, a??? a? ? e?e??t?? ??e? d?a�??f?s?
					   ; e?s?d?? 4 bit ?a �eta?e? se d?a�??f?s? 8 bit

		ldi r24 ,0x30              	
		out PORTD,r24        
		sbi PORTD,PD3        
		cbi PORTD,PD3        
		ldi r24 ,39
		ldi r25 ,0                     
		rcall wait_usec

		ldi r24 ,0x20              	
		out PORTD,r24        
		sbi PORTD,PD3        
		cbi PORTD,PD3        
		ldi r24 ,39
		ldi r25 ,0                     
		rcall wait_usec

		ldi r24 ,0x28            ; ep????? ?a?a?t???? �e?????? 5x8 ?????d??
		rcall lcd_command; ?a? e�f???s? d?? ??a��?? st?? ?????
		
		ldi r24 ,0x0c; e?e???p???s? t?? ??????, ap?????? t?? ???s??a
		rcall lcd_command
		
		ldi r24 ,0x01               ; ?a?a??s�?? t?? ??????
		rcall lcd_command
		
		ldi r24 ,low(1530)
		ldi r25 ,high(1530)
		rcall wait_usec
		
		ldi r24 ,0x06              ; e?e???p???s? a?t?�at?? a???s?? ?at? 1 t?? d?e????s?? 
		rcall lcd_command; p?? e??a? ap????e?�??? st?? �et??t? d?e????se?? ?a?   
						 ; ape?e???p???s? t?? ???s??s?? ????????? t?? ??????
		ret
					   
lcd_command:
		cbi PORTD,PD2        ; ep????? t?? ?ata????t? e?t???? (PD2=1)
		rcall write_2_nibbles; ap?st??? t?? e?t???? ?a? a?a�??? 39�sec
		ldi r24 ,39                ; ??a t?? ????????s? t?? e?t??es?? t?? ap? t?? e?e??t? t?? lcd.
		ldi r25 ,0                  ; S??.: ?p?????? d?? e?t????, ??  clear display ?a? return home, 
		rcall wait_usec; p?? apa?t??? s?�a?t??? �e?a??te?? ??????? d??st?�a.
		ret


lcd_data:
		sbi PORTD,PD2     ; ep????? t?? ?ata????t?ded?�???? (PD2=1)
		rcall write_2_nibbles ; ap?st??? t?? byte
		ldi r24 ,43               ; a?a�??? 43 �sec�???? ?a ?????????e? ? ????
		ldi r25 ,0                   ; t?? ded?�???? ap? t?? e?e??t? t?? lcd
		rcall wait_usec
		ret

write_2_nibbles:
		push r24      ; st???e? ta 4 MSB
		in r25 ,PIND; d?a?????ta? ta 4 LSB ?a? ta ?a?ast?????�e
		andi r25 ,0x0f; ??a ?a �?? ?a??s??�e t?? ?p??a p??????�e?? ?at?stas?
		andi r24 ,0xf0     ; ap?�??????ta? ta 4 MSB?a? 
		add r24 ,r25   ; s??d?????ta? �e ta p???p?????ta 4 LSB 
		out PORTD,r24; ?a? d????ta? st?? ???d?
		sbi PORTD,PD3  ; d?�?????e?ta? pa?�?? Enable st?? a???d??t? PD3  
		cbi PORTD,PD3; PD3=1 ?a? �et? PD3=0
		pop r24  ; st???e? ta 4 LSB. ??a?t?ta? t? byte.
		swap r24; e?a???ss??ta? ta 4 MSB�e ta 4 LSB
		andi r24 ,0xf0; p?? �e t?? se??? t??? ap?st?????ta?
		add r24 ,r25
		out PORTD ,r24
		sbi PORTD ,PD3; ????pa?�??Enable 
		cbi PORTD,PD3
		ret
;--------------------------------------------------------------------------------------------------
;----------------------------------------delay routines--------------------------------------------
;--------------------------------------------------------------------------------------------------
wait_msec:
		push r24; 2 ??????(0.250 �sec)
		push r25; 2 ??????
		ldi r24 , low(998)      ; f??t?se t?? ?ata?.  r25:r24 �e 998 (1 ?????? -0.125 �sec)
		ldi r25 , high(998)     ; 1 ??????(0.125 �sec)
		rcall wait_usec ; 3 ?????? (0.375 �sec), p???a?e? s??????? ?a??st???s? 998.375 �sec
		pop r25               ;2 ?????? (0.250 �sec)
		pop r24               ; 2 ??????
		sbiw r24 , 1          ; 2 ??????
		brne wait_msec; 1 ? 2 ?????? (0.125 ? 0.250 �sec)
		ret; 4 ??????(0.500 �sec)

wait_usec:   
		sbiw r24 ,1      ; 2 ??????(0.250 �sec)
		nop; 1 ??????(0.125 �sec)
		nop; 1 ??????(0.125 �sec)
		nop; 1 ??????(0.125 �sec)
		nop; 1 ??????(0.125 �sec)
		brne wait_usec; 1 ? 2 ??????(0.125 ?0.250 �sec)
		ret             ; 4 ??????(0.500 �sec)
