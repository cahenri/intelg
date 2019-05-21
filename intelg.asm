; compiled using ride7
$include(REG51.inc)
; Fixed memory functions:
; 30h -> Display0 (Left-most, BCD value)
; 31h -> Display1 (BCD value)
; 32h -> Display2 (BCD value)
; 33h -> FREQ (16bit)
; 35h -> BUTTON_MASK
; 36h -> press
; 37h -> pdone
; 39h -> xpress
; 3Ah -> button_en cont
; 3Bh -> display_en cont
; 3Ch -> scan_cont
; 3Dh -> duty_mode
;
; 40h -> NCONT (16bit)
; 42h -> NCONT_HIGH (16bit)
; 44h -> NCONT_LOW (16bit)
; 46h -> TCONT (16bit)
; 48h -> PSW_TEMP
;
; 60h -> _7seg_0
; 61h -> _7seg_1
; 62h -> _7seg_2
; 63h -> _7seg_3
; 64h -> _7seg_4
; 65h -> _7seg_5
; 66h -> _7seg_6
; 67h -> _7seg_7
; 68h -> _7seg_8
; 69h -> _7seg_9
; 6Ah ... 6Fh -> used as arguments for functions
;
; 3Eh -> W_TEMP
; 3Fh -> system flags
; 3Fh.0 -> buttond_en flag
; 3Fh.1 -> scan_en flag
; Hardware mappings:
; PORT0.0 ... PORT0.6: display output
; PORT1.0: Display0 common (ON when zero)
; PORT1.1: Display1 common (ON when zero)
; PORT1.2: Display2 common (ON when zero)
; PORT1.3: PWM OUT
; PORT1.4: Button0 DUTY (Left most)
; PORT1.5: Button1 DEC
; PORT1.6: Button2 INC
; TODO: add button timers

code at 0 ; Reset address
    ljmp    INIT
code

code at 000Bh ; T0 interrupt address
    ljmp    T0_INT
code

code at 0040h
T0_INT:
    lcall   RELOAD_T0
    mov     3Eh,A            ; Save A to W_TEMP
    mov     48h,PSW

    ; Enable BUTTOND each 100ms
    inc     3Ah
    mov     A,3Ah
    xrl     A,#0Ah
    jz      SKIP_BUTTOND_EN
    mov     3Ah,#00h
    mov     A,3Fh
    setb    ACC.0
    mov     3Fh,A
SKIP_BUTTOND_EN:

    ; Enable SCAN each 50ms
    inc     3Bh
    mov     A,3Bh
    xrl     A,#05h
    jz      SKIP_SCAN_EN
    mov     3Bh,#00h
    mov     A,3Fh
    setb    ACC.1
    mov     3Fh,A
SKIP_SCAN_EN:
    
    ; inc TCONT
    clr     C
    mov     A,46h
    addc    A,#01h
    mov     46h,A
    ;
    mov     A,47h
    addc    A,#00h
    mov     47h,A

    mov     A,3Eh            ; Reload A from W_TEMP
    mov     PSW,48h
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
    lcall   SET_DISPLAY_VALUE
    lcall   SCAN
    lcall   BUTTOND
    lcall   FREQ_ADJ
    lcall   CALC_NCONT
    lcall   OUTD
    ;
    ljmp    LOOP

OUTD:
    clr     C
    jb      P1.3,OUTD_HIGH

    ; if P1.3==0 && TCONT>NCONT_LOW then TCONT=0, P1.3=1
    mov     A,45h
    subb    A,47h
    jz      OUTD_IFG_NCONT_LOW
    mov     A,44h
    subb    A,46h
OUTD_IFG_NCONT_LOW:
    jc      OUTD_CPL
    ret

    ; if P1.3==1 && TCONT>NCONT_HIGH then TCONT=0, P1.3=0
OUTD_HIGH:
    mov     A,43h
    subb    A,47h
    jz      OUTD_IFG_NCONT_HIGH
    mov     A,42h
    subb    A,46h
OUTD_IFG_NCONT_HIGH:
    jc      OUTD_CPL
    ret

OUTD_CPL:
    mov     A,P1
    xrl     A,#08h
    orl     A,#70h ; for buttons
    mov     P1,A
    ; TCONT = 0
    mov     46h,#00h
    mov     47h,#00h
    ret

CALC_NCONT:
; T = 1/f
; NCONT = 10 * (1000/FREQ) ; number of timer conts for one period
; 40h: NCONT (16bit)
; 42h: NCONT_HIGH (16bit)
; 33h -> FREQ (16bit)
; 35h -> BUTTON_MASK
; 3Dh -> duty_mode
    mov     6Ch,33h
    mov     6Dh,34h
    lcall   DIVFREQ
    mov     R2,6Eh
    mov     R3,6Fh
    ; 2*QUO:
    clr     C
    mov     A,R2
    rlc     A
    mov     R2,A
    ;
    mov     A,R3
    rlc     A
    mov     R3,A
    ;
    ; QUO*10:
    mov     R7,#03h
CALC_NCONT_MUL:
    clr     C
    mov     A,6Eh
    rlc     A
    mov     6Eh,A
    ;
    mov     A,6Fh
    rlc     A
    mov     6Fh,A
    ;
    djnz    R7,CALC_NCONT_MUL
    ; end by adding 2:
    clr     C
    mov     A,6Eh
    addc    A,R2
    mov     40h,A
    ;
    mov     A,6Fh
    addc    A,R3
    mov     41h,A
    ;
CALC_NCONT_HIGH:
    ; NCONT/4:
    mov     43h,41h
    mov     42h,40h
    mov     R7,#02h
CALC_NCONT_HIGH_4:
; 3Dh -> duty_mode
    clr     C
    mov     A,43h
    rrc     A
    mov     43h,A
    ;
    mov     A,42h
    rrc     A
    mov     42h,A
    ;
    djnz    R7,CALC_NCONT_HIGH_4
    ;
    mov     A,3Dh
    xrl     A,#00h
    jnz     NCONT_HIGH_SUM
    sjmp    CALC_NCONT_LOW
NCONT_HIGH_SUM:
    mov     R3,43h
    mov     R2,42h
    mov     R7,3Dh
NCONT_HIGH_SUM_LOOP:
    clr     C
    mov     A,42h
    addc    A,R2
    mov     42h,A
    ;
    mov     A,43h
    addc    A,R3
    mov     43h,A
    ;
    djnz    R7,NCONT_HIGH_SUM_LOOP
CALC_NCONT_LOW:
    clr     C
    mov     A,40h
    subb    A,42h
    mov     44h,A
    ;
    mov     A,41h
    subb    A,43h
    mov     45h,A
    ;
    ret

FREQ_ADJ:
; PORT1.4: Button0 DUTY (Left most)
; PORT1.5: Button1 DEC
; PORT1.6: Button2 INC
; 3Dh -> duty_mode
; 0 -> 25%
; 1 -> 50%
; 2 -> 75%
; 3 -> 100%
; 36h -> press
; 37h -> pdone
; 39h -> xpress
    mov     A,39h
    jnb     ACC.6,BTN_DEC_CHECK
    ; Set pdone
    mov     A,37h
    setb    ACC.6
    mov     37h,A
    ; FREQ += 1
    clr     C
    mov     A,33h
    addc    A,#01h
    mov     33h,A
    ;
    mov     A,34h
    addc    A,#00h
    mov     34h,A
;
BTN_DEC_CHECK:
    mov     A,39h
    jnb     ACC.5,BTN_DUTY_CHECK
    ; Set pdone
    mov     A,37h
    setb    ACC.5
    mov     37h,A
    ; FREQ -= 1
    clr     C
    mov     A,33h
    subb    A,#01h
    mov     33h,A
    ;
    mov     A,34h
    subb    A,#00h
    mov     34h,A
;
BTN_DUTY_CHECK:
; 3Dh: Duty mode
    mov     A,39h
    jnb     ACC.4,FREQ_ADJ_END
    ; Set pdone
    mov     A,37h
    setb    ACC.4
    mov     37h,A
    ; duty++
    inc     3Dh
    mov     A,3Dh
    xrl     A,#04h
    jnz     FREQ_ADJ_END
    mov     3Dh,#00h
;
FREQ_ADJ_END
    ret

SET_DISPLAY_VALUE:
; 33h -> FREQ (16bit)
    mov     6Ah,33h
    mov     6Bh,34h
    lcall   BIN10_BCD
    ; set display[0]
    mov     A,6Ch
    anl     A,#0Fh
    add     A,#60h
    mov     R0,A
    mov     30h,@R0
    ; set display[1]
    mov     A,6Ch
    swap    A
    anl     A,#0Fh
    add     A,#60h
    mov     R0,A
    mov     31h,@R0
    ; set dipslay[2]
    mov     A,6Dh
    anl     A,#0Fh
    add     A,#60h
    mov     R0,A
    mov     32h,@R0
    ;
    ret
    
RELOAD_T0:
; Crystal used: 16MHz
; machine-cycle: 12*1/16M = 0.75us
; 133 * 0.75 ~= 0.1ms
; 65536 - 133 - 3 - 6 - 1 = 65393 (0xFF71)
    mov     TCON,#00h        ; T0_OFF
    mov     TH0,#0FFh
    mov     TL0,#71h
    mov     TCON,#10h        ; T0_ON    
    ret

BUTTOND:
; 35h: button_mask
; 36h: press
; 37h: pdone
; 39h: xpress
; 3Fh.0 : buttond_en flag
; press = button & button_mask
; pdone = pdone & press
; xpress = press ^ pdone
    mov     A,3Fh
    jb      ACC.0,BUTTOND_RUN
    ret
BUTTOND_RUN:
    clr     ACC.0
    mov     3Fh,A
    ; press = button & button_mask
    mov     A,P1
    cpl     A
    anl     A,35h
    mov     36h,A
    ;
    mov     A,P1
    cpl     A
    mov     35h,A
    ; pdone = pdone & press
    mov     A,36h
    anl     A,37h
    mov     37h,A
    ; xpress = press ^ pdone
    mov     A,36h
    xlr     A,38h
    mov     39h,A
    ;
    ret

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

SCAN:
; 30h: DISPLAY0
; 31h: DISPLAY1
; 32h: DISPLAY2
; 3Ch: scan_cont
; PORT0.0 ... PORT0.6: display output
; PORT1.0: Display0 common (ON when zero)
; PORT1.1: Display1 common (ON when zero)
; PORT1.2: Display2 common (ON when zero)
    mov     A,3Fh
    jb      ACC.1,SCAN_RUN
    ret
    ;
SCAN_RUN:
    clr     ACC.1
    mov     3Fh,A
    ; All commons off:
    mov     A,P1
    orl     A,#77h ; include 1's for button inputs
    mov     P1,A
    ; P0 = display[scan_cont]
    mov     A,#30h
    add     A,3Ch
    mov     R0,A
    mov     A,@R0
    mov     P0,A
    ; Display on:
    mov     R7,3Ch
    inc     R7
    mov     A,#00h
    setb    C
SCAN_ROTATE_COMMON:
    rlc     A
    clr     C
    djnz    R7,SCAN_ROTATE_COMMON
    cpl     A
    ;
    mov     R7,A
    mov     A,P1
    anl     A,R7
    mov     P1,A
    ;
    ; inc scan_cont:
    inc     3Ch
    mov     A,3Ch
    xrl     A,#03
    jz      SKIP_CLR_SCAN_CONT 
    mov     3Ch,#00h
SKIP_CLR_SCAN_CONT:
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
    mov     6Ah,#FAh
    mov     6Eh,#00h
    mov     6Fh,#00h
    mov     R6,#00h         ; DIVID will be rotated here
    mov     R7,#00h

    mov     R5,#0Ah
DIVFREQ_0:
    ; Rotate DIVID into R6:
    mov     A,6Ah
    clr     C
    rlc     A
    mov     6Ah,A
    ;
    mov     A,R6
    rlc     A
    mov     R6,A
    mov     A,R7
    rlc     A
    mov     R7,A
    ; SUBB R6,DIVIS(6Ch) if R6>DIVIS
    mov     A,R7
    clr     C
    subb    A,6Dh
    jnz     CHECK_IF_GREATER
    mov     A,R6
    clr     C
    subb    A,6Ch
CHECK_IF_GREATER:
    JC      DIVFREQ_RL_0_QUO ; if(C==1): DIVS is greater
    ;
    mov     A,R6
    clr     C
    subb    A,6Ch
    mov     R6,A
    ;
    mov     A,R7
    subb    A,6Dh
    mov     R7,A
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
    djnz    R5,DIVFREQ_0
    ; Return value in 6Eh (16bit)
    ret

BIN10_BCD:
; double-dabble optimized for 10 bit numbers 
; Pass parameter to 6Ah before calling this func
    mov     R7,#06h
BIN10_BCD_INIT:
    lcall   BIN10_BCD_RLC
    djnz    R7,BIN10_BCD_INIT
;
BIN10_BCD_LOOP:
    mov     R7,#0Ah
    lcall   BIN10_BCD_RLC
    ;
    mov     A,6Ch
    rlc     A
    mov     6Ch,A
    ;
    mov     A,6Dh
    rlc     A
    mov     6Dh,A
    ;
    mov     R0,#6Ch
    lcall   BIN10_BCD_ADJ
    ;
    mov     R0,#6Dh
    lcall   BIN10_BCD_ADJ
    ;
    djnz    R7,BIN10_BCD_LOOP
    ; Return value in 6Ch and 6Dh
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
    mov     A,6Ah
    clr     C
    rlc     A
    mov     6Ah,A
    ;
    mov     A,6Bh
    rlc     A
    mov     6Bh,A
    ;
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
