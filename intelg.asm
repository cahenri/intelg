; compiled using ride7
$include(REG51.inc)

code at 0 ; Reset address
    ljmp    INIT
code

code at 000Bh ; T0 interrupt address
    ljmp    T0_INT
code

code at 0050h
T0_INT:
    lcall   RELOAD_T0
    reti
code

code at 0100h ; Init address
INIT:
    mov     TMOD,#01h        ; Timer0 as 16-bit counter
    mov     IE,#82h          ; Enable T0 interrupts
    mov     SP,#70h
    mov     PSW,#00h
    lcall   RELOAD_T0
    lcall   INIT_7SEG_CONST
    ljmp    LOOP
code

code at 0200h ; Main address
LOOP:
    ljmp    LOOP

RELOAD_T0:
; Crystal used: 16MHz
; machine-cycle: 12*1/16M = 0.75us
; 133 * 0.75 ~= 0.1ms
; 65536 - 133 - 3 = 65400 (0xFF78)
    mov     TCON,#00h        ; T0_OFF
    mov     TH0,#0FFh
    mov     TL0,#78h
    mov     TCON,#10h        ; T0_ON    
    ret
end

INIT_7SEG_CONST:
; bit0: A
    mov     60h,#0C0h        ; 0
    mov     61h,#0F9h        ; 1
    mov     62h,#0A4h        ; 2
    mov     63h,#0B0h        ; 3
    mov     64h,#99h         ; 4
    mov     65h,#92h         ; 5
    mov     66h,#82h         ; 6
    mov     67h,#0F8h        ; 7
    mov     68h,#80h         ; 8
    mov     69h,#90h         ; 9
    ret

DIVFREQ:
; Operation performed by this function:
; 1000/FREQ
;
; The period for FREQ is definded by NCONT*0.1ms
; NCONT = 10 * (1000/FREQ)
; 1000d = 0b 0000 0011 1110 1000
; 6Ah -> DIVD[END] (8bit) (always 1000, but l-rotated to leave 1 in the MSB)
; 6Ch -> DIVS[OR] (16bit) - must be set before calling this function
; 6Eh -> QUO[CIENT] (16bit)
; 50h-59h -> general purpose
    mov     6Ah,#FAh
    mov     6Eh,#00h
    mov     6Fh,#00h
    mov     50h,#00h         ; DIVID will be rotated here
    mov     51h,#00h

    mov     5Ch,#0Ah
DIVFREQ_0:
    ; Rotate DIVID into 50h:
    mov     A,6Ah
    clr     C
    rlc     A
    mov     6Ah,A
    ;
    mov     A,50h
    rlc     A
    mov     50h,A
    mov     A,51h
    rlc     A
    mov     51h,A
    ; SUBB 50h,DIVIS(6Ch) if 50h>DIVIS
    mov     A,51h
    clr     C
    subb    A,6Dh
    jnz     CHECK_IF_GREATER
    mov     A,50h
    clr     C
    subb    A,6Ch
CHECK_IF_GREATER:
    JC      DIVFREQ_RL_0_QUO ; if(C==1): DIVS is greater
    ;
    mov     A,50h
    clr     C
    subb    A,6Ch
    mov     50h,A
    ;
    mov     A,51h
    subb    A,6Dh
    mov     51h,A
    ;
    setb    C
    sjmp    DIVFREQ_RL_1_QUO
DIVFREQ_RL_0_QUO:
    clr     C
DIVFREQ_RL_1_QUO:
    mov     A,6Eh
    rlc     A
    mov     6Eh,A
    ;
    mov     A,6Fh
    rlc     A
    mov     6Fh,A
    ;
    djnz    5Ch,DIVFREQ_0
    ; Return value in 6Eh (16bit)
    ret

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
