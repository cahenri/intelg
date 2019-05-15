; compiled using ride7
$include(REG51.inc)

code at 0 ; Reset address
    ljmp    INIT
code

code at 000Bh ; Interrupt address
    reti
code

code at 0100h ; Init address
INIT:
    mov     TMOD, #01h       ; Timer0 as 16-bit counter
    mov     IE, #82h         ; Enable T0 interrupts
    mov     SP, #70h
    mov     PSW, #00h
    lcall   RELOAD_T0
    ljmp    LOOP
code

code at 0200h ; Main address
LOOP:
    ljmp    LOOP

RELOAD_T0:
    mov     TCON, #00h       ; T0_OFF
    mov     TH0, #0AAh
    mov     TL0, #55h
    mov     TCON, #10h       ; T0_ON    
    ret
end

; Cheat sheet
;
; TCON
; Bit adressable
; bit5: Timer0 Overflow flag.
; Set by hardware when the Timer0 overflows.
; Cleared by hardware as processor vectors to the service routine
; bit4: Timer0 ON(1)/OFF(0)
;
; TMOD
; Not bit adressable
; Default: 0x01 (Timer0 as 16-bit counter)
;
; IE
; bit7: Enable(1)/Disable(0) all interrupts
; bit1: Enable(1)/Disable(0) Timer0 interrupts
;
; TH0
; TL0
;
; About 8051 Port:
; https://stackoverflow.com/questions/27479100/how-to-configure-8051-pins-as-input-output
