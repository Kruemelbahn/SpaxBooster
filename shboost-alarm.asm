;
; SHBoost
; DCC controller for SHMDBoost
; created 12/06/98
; V 0.1 initial verison
; V 0.2 1/23/99 relaxed sense error sensitivity due to Bodman report of Mathias
; V 0.3 9/01/03 changed processor to 16F628 because 16F84A hangs up although watchdog is used
; V 0.4 1/24/05 added variable prescaler for timer 0 to increase off time
;               added variable pwr_off ratio
;				patch prescaler : addr0: 305x, x from 1 to 7, default 1 (prescaler 4)
;				patch ratio     : addr1: 300x, x from 7 to 1, default 7 (ratio 2^7)
;				patch sense_cntr: addr2: 30xx, xx from 01 to FF,
;							default 3 for non sound, 10 for sound decoder
;
; $Id: shboost.asm,v 1.4 2007/02/09 19:13:12 pischky Exp $
;
;**************************************************************
; *  Copyright (c) 2018 Michael Zimmermann <http://www.kruemelsoft.privat.t-online.de>
; *  All rights reserved.
; *
; *  LICENSE
; *  -------
; *  This program is free software: you can redistribute it and/or modify
; *  it under the terms of the GNU General Public License as published by
; *  the Free Software Foundation, either version 3 of the License, or
; *  (at your option) any later version.
; *  
; *  This program is distributed in the hope that it will be useful,
; *  but WITHOUT ANY WARRANTY; without even the implied warranty of
; *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; *  GNU General Public License for more details.
; *  
; *  You should have received a copy of the GNU General Public License
; *  along with this program. If not, see <http://www.gnu.org/licenses/>.
; *
;**************************************************************
; zim: 11.05.09: Overloadalarm added, not for PIC12C508, config changed
; zim: 19.03.13: added buzzer off in loopsns, PIC12C508 and PIC16F84 removed

	list p=16F628, w=0, r=DEC

	include <p16F628.inc>
	ERRORLEVEL      -302    	; SUPPRESS BANK SELECTION MESSAGES

;+++config changed:
	__CONFIG _CP_OFF & _PWRTE_ON & _WDT_ON & _XT_OSC & _BODEN_ON & _LVP_OFF & _MCLRE_OFF
	__IDLOCS  0004          ; ID- information in EPROM

SER1	EQU	H'0000'
SER2	EQU	H'0001'


#define SER_DAT1	PORTB,SER1	; RB0,data input
#define SER_DAT2	PORTB,SER2	; RB1,data input
#define ENABLE		PORTB,0x0002	; RB2,L6203 enable output
#define SENSE		PORTB,0x0003	; RB3,current sense input
#define	LED_RED		PORTB,0x0004	; RB4,LED, red
#define LED_GREEN	PORTB,0x0005	; RB5,LED, green
;+++buzzer added:
#define BUZZER_OFF	PORTB,0x0006	; RB6,Buzzer, off
#define BUZZER		PORTB,0x0007	; RB7,Buzzer on Overload
;---

#define timer0_scale_256 0x57		; option_reg values for tmr0 prescaler values
#define timer0_scale_128 0x56		; portb pull-up, clock on internal clock
#define timer0_scale_64 0x55
#define timer0_scale_32 0x54
#define timer0_scale_16 0x53
#define timer0_scale_8 0x52
#define timer0_scale_4 0x51

	cblock	0x0020 			; fuer 16F628
	flags
	store_gpio
	ser_changed
	SER1_INACTIVE
	SER2_INACTIVE
	temp
	temp2
	nmb_short_try			; how often are we allowed to try to apply
					; power to track ? (counts down from pwr_off_ratio to 1)
	retry_delay			; number of timer0 ovl to wait to apply power to track
	sense_wait			; number of timer0 ovl to wait to remove power due to
					; sense error
	timer0_pre_scale    		; reload value for option reg to set different prescaler
					; values for timer0 
	pwr_off_ratio			; ratio (2^pwr_off_ratio) for max. pwr off time
	sense_cntr			; how often has sense to be active before removing power

	endc



#define	rs_err		flags,0
#define	sense_err	flags,1
;+++buzzer added:
#define buzz_off	flags,2

#define def_pwr_off_ratio 4 		; default value for pwr_off_ratio
#define def_sense_cntr    0x30		; default value for sense_cntr


READPORT MACRO
	movf	PORTB,w
	endm

bank_0	MACRO
	bcf	STATUS,RP0
	ENDM

bank_1	MACRO
	bsf	STATUS,RP0
	ENDM

led_ok	MACRO
	bcf	LED_RED
	bsf	LED_GREEN
	ENDM

led_rserr MACRO
	bsf	LED_RED
	bsf	LED_GREEN
	ENDM

led_sense MACRO
	bsf	LED_RED
	bcf	LED_GREEN
	ENDM

;**************************************************************
	org 	0x0000

	movlw	timer0_scale_32
	movwf	timer0_pre_scale; store timer0 prescaler
	movlw	def_pwr_off_ratio; set default power off ratio
	movwf	pwr_off_ratio
	movlw	def_sense_cntr	; set default power off ratio
	movwf	sense_cntr

	movlw	0x07
	movwf	CMCON		; set PortA to digital I/O, only required for 16F628

;+++initializing changed:
	movlw	0x4b;		; initialize TRIS
	bank_1
	movwf	TRISB
	bank_0

	led_rserr		; initialize ports, show rs error
	bcf	ENABLE		; be silent at first

	clrf	ser_changed	; clear ser_changed register
	READPORT		; test whether pulses on both rs lines
	andlw	0x03
	movwf	store_gpio


no_rs	READPORT		; test whether rs lines change
	andlw	0x03
	movwf	temp		; store port
	xorwf	store_gpio,w
	btfsc	STATUS,Z
	goto	no_rs

  	iorwf	ser_changed,f	; test whether both rs lines change
	movlw	0x03
	subwf	ser_changed,w
	btfss	STATUS,Z
	goto	no_rs
	movf	temp,w
	movwf	store_gpio	; store gpio status

	led_ok			; switch RSERR LED off
	bcf	sense_err	; clear sense_err flag


	movlw	D'10'
	movwf	SER1_INACTIVE	; initialize idle counters
	movwf	SER2_INACTIVE	;
	clrf	retry_delay
	movf	pwr_off_ratio,w
	movwf	nmb_short_try
	movf	sense_cntr,w
	movwf	sense_wait

	movlw	(D'255' - D'13'); initialize timer to 62 usec
	movwf	TMR0

	movlw	timer0_scale_4	; portb pull-up, clock on internal clock
	bank_1
	movwf	OPTION_REG
	bank_0

loopidle
	bsf	ENABLE		; apply power to track
	bcf	sense_err	; clear sense_err flag
	led_ok
loop	clrwdt

;+++buzzer added:
	btfsc	BUZZER_OFF
	goto	wait_t
	bsf	buzz_off
	bcf	BUZZER
;---

wait_t	movf	TMR0,w
	btfss	STATUS,Z
	goto	wait_t
	movlw	(D'255' - D'13'); initialize timer to 62 usec
	movwf	TMR0
	
;*********************** test railsync lines *************************************
	READPORT		; test whether serx_dat changes
	andlw	0x03
	movwf	temp
	xorwf	store_gpio,w
	movwf	ser_changed
	movf	temp,w
	movwf	store_gpio

	bcf	rs_err		; clear rs_err flag
	movlw	D'10'		; test whether ser1_dat changes
	btfsc	ser_changed,SER1
	movwf	SER1_INACTIVE	; yes, reset idle count
	movf	SER1_INACTIVE,F
	btfsc	STATUS,Z	; is idle count zero ?
	goto	rs1_err		; yes
	decf	SER1_INACTIVE,F	; no, decrement idle counter
	goto	t2
rs1_err	bsf	rs_err

t2	movlw	D'10'		; test whether ser2_dat changes
	btfsc	ser_changed,SER2
	movwf	SER2_INACTIVE	; yes, reset idle count
	movf	SER2_INACTIVE,F
	btfsc	STATUS,Z	; is idle count zero ?
	goto	rs2_err		; yes
	decf	SER2_INACTIVE,f	; no, decrement idle counter
	goto	rs_exit
rs2_err	bsf	rs_err		; yes, set rs_err flag

rs_exit	btfss	rs_err
	goto	tsense
	bcf	ENABLE
	led_rserr
	goto	loop


;*********************** test sense line *************************************
; test whether output short

tsense
	btfsc	SENSE		; check SENSE line
	goto	sense_ok	; everything OK

	btfsc	sense_err	; already sense_err detected ?
	goto	pwr_off		; yes, don't wait

	decfsz	sense_wait,f	; decrement sense_wait cntr
	goto	arm_sns_err	; not zero, then wait

pwr_off	bcf	ENABLE		; remove power at once
	movf	timer0_pre_scale,w ; change timer0 prescaler
	bank_1
	movwf	OPTION_REG
	bank_0

	movlw	(D'255' - D'250'); set timer to 1.2 ms
	movwf	TMR0
	
	led_sense
	bsf	sense_err

;+++buzzer added:
	btfss	buzz_off
	bsf	BUZZER
;---

	movlw	1
	movwf	sense_wait

	movf	nmb_short_try,w	; calculate delay time
	movwf	temp		; retry_delay = 0x800 >> nmb_short_try
	clrf	temp2
	bsf	STATUS,C
rol	rrf	temp2,f
	decfsz	temp,f
	goto	rol
	movf	temp2,w
	movwf	retry_delay	; set retry delay

	movlw	0x01		; stretch retry delay
	decfsz	nmb_short_try,f	; by decrementing nmb_short_try
	goto	loopsns
	movwf	nmb_short_try	; don't go below 1

loopsns clrwdt

;+++buzzer added:
	btfsc	BUZZER_OFF
	goto	wait_t2
	bsf	buzz_off
	bcf	BUZZER
;---

wait_t2	movf	TMR0,w
	btfss	STATUS,Z
	goto	loopsns

	movf	timer0_pre_scale,w ; change timer0 prescaler
	bank_1
	movwf	OPTION_REG
	bank_0
	movlw	(D'255' - D'250'); initialize timer to 1.2 msec
	movwf	TMR0

	decfsz	retry_delay,f	; wait until it's time
	goto	loopsns
				; now it's time
retry movlw	timer0_scale_4 ; change timer0 prescaler to default
	bank_1
	movwf	OPTION_REG
	bank_0

	movlw	(D'255' - D'13'); initialize timer to 62 usec
	movwf	TMR0
	goto	loopidle

arm_sns_err

	movf	pwr_off_ratio,w	; reset nmb_short_try
	movwf	nmb_short_try
	goto	loopidle

sense_ok
	movf	sense_cntr,w
	movwf	sense_wait
	bcf	sense_err	; clear sense_err flag

;+++buzzer added:
	bcf	BUZZER
	bcf	buzz_off
;---

	movf	pwr_off_ratio,w		; reset nmb_short_try
	movwf	nmb_short_try
	goto	loopidle

	end
