; compiled using ride7
$include(REG51.inc)
; Fixed memory functions:
; 30h -> Display0 (Left-most, BCD value)
; 31h -> Display1 (BCD value)
; 32h -> Display2 (BCD value)
; 33h -> FREQ (16bit)
; 35h -> 
; Hardware mappings:
; PORT0.0 ... PORT0.6: display output
; PORT1.0: Display0 common (ON when zero)
; PORT1.1: Display1 common (ON when zero)
; PORT1.2: Display2 common (ON when zero)
; PORT1.3: Button0
; PORT1.4: Button1
; PORT1.5: Button2

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

BIN10_BCD:
; double-dabble optimized for 10 bit numbers 
; Pass parameter to 50h before calling this func
    mov     5Ah,#06h
BIN10_BCD_INIT:
    lcall   BIN10_BCD_RLC
    djnz    5Ah,BIN10_BCD_INIT

BIN10_BCD_LOOP:
    mov     5Ah,#0Ah
    lcall   BIN10_BCD_RLC
    ;
    mov     A,52h
    rlc     A
    mov     52h,A
    ;
    mov     A,53h
    rlc     A
    mov     53h,A
    ;
    mov     R0,#52h
    lcall   BIN10_BCD_ADJ
    ;
    mov     R0,#53h
    lcall   BIN10_BCD_ADJ
    ;
    djnz    5Ah,BIN10_BCD_LOOP
    ; Return value in 52h and 53h
    ret
;
BIN10_BCD_ADJ:
    mov     A,@R0
    add     A,#03h
    jnb     ACC.3,BIN10_BCD_ADJ_SKIP0
    mov     @R0,A
BIN10_BCD_ADJ_SKIP0:
    mov     A,@R0
    add     A,#30h
    jnb     ACC.7,BIN10_BCD_ADJ_SKIP1
    mov     @R0,A
BIN10_BCD_ADJ_SKIP1:
    ret
;
BIN10_BCD_RLC:
    mov     A,50h
    clr     C
    rlc     A
    mov     50h,A
    ;
    mov     A,51h
    rlc     A
    mov     51h,A
    ;
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
