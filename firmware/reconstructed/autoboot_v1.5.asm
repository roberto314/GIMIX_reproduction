

********************************************
*                                         *
*         Gimix AUTOBOOT                  *
* --------------------------------------  *
* For Gimix DMA and Gimix and SWTPc       *
* programmed I"O disk controllers:        *
* Gimix DMA 68, PIO 28, and 5"8 58,       *
* and SWTPc DC-1, DC-2, and DC-3.         *
* --------------------------------------  *
*                                         *
*         Version 1.5                     *
*                                         *
*     Copyright (C) 1983 by               *
*         GIMIX, Inc.                     *
*     1337 West 37th Place                *
* Chicago, Illinois  60626                *
*     (312) 927-5510                      *
*                                         *
*     All rights reserved                 *
*                                         *
********************************************
*
*AUTOBOOT first looks for a Gimix DMA 68 controller
*at its standard Gimix FLEX address ($E3B0).
*If the controller is found, the boot for the
*DMA 68 is executed. If not, AUTOBOOT looks for
*a PIO 28 controller (or 5"8 58, or DC-1, -2, or -3)
*at its standard Gimix FLEX address ($E010).
*If it is found, the PIO 28 boot is executed.
*If neither controller is found, AUTOBOOT prints
*an error message and returns to the monitor.

*Note: execution of AUTOBOOT disables the interrupt
*output of the 58167 or 146818 time-of-day clock on
*the Gimix CPU board.

*AUTOBOOT also includes a short routine which switches
*to OS-9. This routine uses 12 bytes of memory at $E50,
*and can be reached by a JMP instruction or a "J" command.

*DISK CONTROLLER EQUATES

*PIO-TYPE CONTROLLERS

PORT    EQU    $E014            BASE ADDRESS OF CONTROLLER
PDRVRG  EQU    PORT             CONTROLLER DRIVE SELECT REGISTER
PCOMRG  EQU    PORT+4           1771 COMMAND"STATUS REGISTER
PSECRG  EQU    PORT+6           1771 SECTOR REGISTER
PDATRG  EQU    PORT+7           1771 DATA REGISTER

*GIMIX DMA 68 CONTROLLER

PORT1   EQU    $E3B0            BASE ADDRESS OF DMA 68
DRVREG  EQU    PORT1            DRIVE SELECT REGISTER
DMAREG  EQU    PORT1+1          DMA CONTROL REGISTER
ADDREG  EQU    PORT1+2          DMA ADDRESS REGISTER
COMREG  EQU    PORT1+4          1797 COMMAND"STATUS REGISTER
TRKREG  EQU    PORT1+5          1797 TRACK REGISTER
SECREG  EQU    PORT1+6          1797 SECTOR REGISTER
DATREG  EQU    PORT1+7          1797 DATA REGISTER

*GMXBUG VECTOR ADDRESSES

NXTCMD  EQU    $F802            WARM START
INCHE   EQU    $F806            INPUT CHARACTER W"ECHO
OUTCH   EQU    $F80A            OUTPUT CHARACTER
PSTRNG  EQU    $F810            PRINT STRING W"CR-LF
LRA     EQU    $F812            LOAD REAL ADDRESS
TIMCLK  EQU    $E230            Gimix 6809 clock address (CPU+)
CLKIII  EQU    $E240            clock address (CPU III)
TSRIII  EQU    $E280            controls CPU III clock access

*START OF PROGRAM

        SETDP  $E3

        ORG    $F000

AUTBOT  CLR    TIMCLK+1        DISABLE 58167 INTERRUPTS
        TST    TIMCLK          CLEAR ANY PENDING INTERRUPT
        LDA    #8
        STA    TSRIII
        LDA    CLKIII+11       suppress 146818 interrupts
        ANDA   #$87
        STA    CLKIII+11
        CLR    TSRIII
        TST    CLKIII+12       clear pending interrupts

*LOOK FOR GIMIX DMA 68 CONTROLLER

        LDA    #$E3            SET DP TO DMA 68 CONTROLLER PAGE
        TFR    A,DP
        CLR    <DMAREG         CLEAR DMA ENABLE

        CLR    <DRVREG         CLEAR DRIVE SELECT REGISTER
        LDA    <DRVREG         READ DRIVE SELECT REGISTER
        BITA   #$16            ARE FLAGS ALL CLEAR?
        BNE    PIO             NO: CHECK FOR PIO
        LDD    #$C010          SET DMA, 8" & 2MHZ FLAGS
        STD    <DRVREG
        LDA    <DRVREG         READ THEM BACK
        ANDA   #$16            MASK UNWANTED BITS
        CMPA   #$16            CORRECT FOR DMA 68 CONTROLLER?
        LBEQ   DMABOT          YES: DO DMA BOOT
*                              ELSE DROP THROUGH TO PIO CHECK

*LOOK FOR PIO-TYPE CONTROLLER

PIO     LDX    #PORT+4         POINT TO PIO PAGE
        LDA    #$D0            GIVE IT FORCE INTERRUPT COMMAND
        STA    ,X+
        LDA    #3              CLEAR $E019-$E01B
PIO1    CLR    ,X+
        DECA
        BNE    PIO1
        LDA    #3              NOW CHECK THOSE BYTES
PIO2    TST    ,-X
        BNE    NOTHIN          STILL ZERO? NO: NO CONTROLLER INSTALLED
        DECA
        BNE    PIO2
        LDA    #3
        LDB    #$5A
PIO3    STB    ,X+            WRITE ROTATING PATTERN TO PIO
        RORB
        DECA
        BNE    PIO3
        LEAX   -3,X            RESET POINTER
        LDA    #3              CHECK THOSE THREE BYTES AGAIN
        LDB    #$5A            SET UP STARTING MASK
PIO4    CMPB   ,X+
        BNE    NOTHIN          DOESN'T MATCH - NOBODY THERE
        RORB
        DECA
        BNE    PIO4
*                              ALL BYTES MATCHED:
        BRA    BOOT            DO PROGRAMMED I"O BOOT

*PRINT NOTHING MESSAGE

NOTHIN  LEAX   NOTHMS,PCR      PRINT MESSAGE
MONOUT  JSR    [PSTRNG]
MONOT1  JMP    [NXTCMD]        RETURN TO MONITOR WARM START
NOTHMS  FCC    "NO CONTROLLER INSTALLED"
        FCB    4


*START OF PROGRAMMED I"O BOOT

        SETDP  $E0

BOOT   LDA    #$E0            POINT DP TO PIO PAGE
       TFR    A,DP
       LEAX   PIOMSG,PCR      PRINT PIO MESSAGE
       JSR    [PSTRNG]
       LDS    #$DFFF          SET STACK POINT
       PSHS   DP              SAVE DP
       CLR    <PDRVRG         START MOTOR AND SELECT DRIVE ZERO
       LDA    #$D0            CLEAR 1771 INTERRUPT
       STA    <PCOMRG
       BSR    CHKRDY           WAIT FOR READY
       LDA    #3              SET COUNT OF 3 TRACKS
       PSHS   A               PUT ON STACK
BOOTA  LDA    #$5B            STEP IN
       STA    <PCOMRG
       BSR    CHKRDY           WAIT FOR READY
       DEC    ,S
       BNE    BOOTA           LOOP TILL THREE STEPS DONE
       LEAS   1,S             ADJUST STACK
       LDA    #$0B            HOME AT 40ms"STEP W"HEAD LOAD
       STA    <PCOMRG

*DELAY 2,00,000 MACHINE CYCLES FOR MOTORS TO SPEED UP.

       LDX    #$4009          NUMBER OF TIMES THROUGH LOOP
BOOT1  BSR    DELAY           DELAY FOR 114 CYCLES
       LEAX   -1,X            DECREMENT COUNTER
       BNE    BOOT1           LOOP TILL COUNTER DONE
       BSR    CHKRDY           WAIT FOR NOT BUSY
       ASLB                    DRIVES READY?
       BMI    ERROR           IF NOT THEN ERROR
       LDA    #1              SET FOR SECTOR ONE
       STA    <PSECRG
       LDB    #$8C            READ SINGLE RECORD, IBM FORMAT,
       STB    <PCOMRG         HLD, HLT AND 10 ms DELAY
       LDX    #$C000          DESTINATION FOR DATA FROM DISK
       BSR    DELAY           GIVE DISK TIME TO SETTLE
READ   LDB    <PCOMRG         GET 1771 STATUS
       BITB   #$02            DATA REQUEST?
       BEQ    NODATA
       LDA    <PDATRG         READ BYTE FROM 1771
       STA    ,X+            STORE IN MEMORY AND BUMP POINTER
       BRA    READ            AND RE-ENTER READ LOOP
NODATA BITB   #01             IS 1771 BUSY?
       BNE    READ            YES: GO READ STATUS AGAIN
ALLDON PULS   DP              RESTORE DP REGISTER
       BITB   #$9C            ANY ERRORS FOUND?
       BNE    ERROR           YES: PRINT ERROR MESSAGE
       JMP    $C000           NO: JUMP TO BOOT FROM DISK

*THIS ROUTINE WAITS FOR THE
*1797 TO FINISH EXECUTING
*THE CURRENT COMMAND.

CHKRDY  BSR    DELAY           DELAY FOR 114 CYCLES
CKRDY1  LDB    <PCOMRG         GET STATUS FROM 1771
        ASRB                    BUSY?
        BCS    CKRDY1          YES: WAIT TILL DONE
        RTS

*THIS SUBROUTINE DELAYS FOR EXACTLY 114 MACHINE CYCLES
*INCLUDING THE BSR AND RTS.  THE NUMBER OF CYCLES FOR
*EACH INSTRUCTION IS IN PARENTHESIS.

*THE BSR TAKES 7 CYCLES

DELAY   LDB    #20             SET INNER LOOP COUNT (2)
DELAY1  DECB                    DECREMENT COUNTER      (2) X 20
        BNE    DELAY1          LOOP TILL DONE          (3) X 20
        RTS                     RETURN                  (5)

*ERROR REPORT ROUTINE
*CHECKS FOR DRIVES NOT READY
*AND TELLS THE USER IF THAT IS
*THE CASE.

ERROR  LEAX   ERRMSG,PCR      PRINT ERROR MESSAGE
       JSR    [PSTRNG]
       PSHS   B
       BSR    PDIGIT           PRINT 1ST 1771"1797 STATUS DIGIT
       PULS   B
       BSR    PDIGT1           PRINT 2ND DIGIT
       TSTB                    CHECK DRIVES NOT READY
       BPL    ERR1
       LEAX   NRDYMS,PCR      IF SO PRINT MESSAGE
       JSR    [PSTRNG]
ERR1   LEAX   ERRM1,PCR      PRINT RETRY PROMPT
       JSR    [PSTRNG]
       JSR    [INCHE]          GET A CHARACTER FROM KEYBOARD
       CMPA   #$60
       BLT    ERR2
       SUBA   #$20            CONVERT LOWER CASE TO UPPER CASE
ERR2   CMPA   #'Y'            IS IT A 'Y'?
       LBEQ   AUTBOT           YES: TRY AGAIN
       CMPA   #'N'            IS IT AN 'N'?
       LBEQ   MONOT1           YES: GO BACK TO MONITOR THROUGH
       BRA    ERR1             RE-PROMPT IF NOT 'Y' OR 'N'

*ENTRANCE FOR LEFT DIGIT

PDIGIT LSRB                    MOVE LEFT NYBBLE TO RIGHT NYBBLE
       LSRB
       LSRB
       LSRB
*ENTRANCE FOR RIGHT DIGIT
PDIGT1 TFR    B,A             COPY TO ACCA
       ANDA   #$0F            MASK TO 4 LS BITS
       CMPA   #9              CONVERT TO HEX ASCII
       BLE    PDG1
       ADDA   #7              OFFSET FOR A-F
PDG1   ADDA   #$30            OFFSET FOR ASCII
       JMP    [OUTCH]          PRINT CHARACTER & RETURN

*ERROR MESSAGES

ERRMSG  FCC    "ERROR IN BOOT - DEVICE STATUS = "
        FCB    4
ERRM1   FCC    ;RE-TRY (Y/N)?;
        FCB    4
NRDYMS  FCB    13
        FCB    10
        FCC    "NOT READY"
        FCB    4
PIOMSG  FCC    ;EXECUTING GIMIX PROGRAMMED I/O BOOTSTRAP;
        FCB    4

*START OF DMA BOOT

                            SETDP  $E3

DMABOT LEAX   DMAMSG,PCR      PRINT DMA MESSAGE
       JSR    [PSTRNG]
       LDS    #$DFFF          SET STACK POINTER
       PSHS   DP              SAVE DP
       LDA    #$E3            POINT DP TO DMA 68 PAGE
       TFR    A,DP
       LDA    #$D0            CLEAR ANY INTERRUPT IN 1797
       STA    <COMREG
       LDA    #1              SELECT DRIVE ONE
       STA    <SECREG         AND SET FOR SECTOR ONE
       LDB    <DRVREG         GET DMA 68 STATUS
       LSRB                    CHECK SENSE SWITCH
       BCC    BOOT0           OFF - 5" BOOT DRIVE
       ORA    #$C0            ON - MAKE EIGHT INCH
BOOT0  STA    <DRVREG         GIVE TO DMA 68
BOOTL1 LDB    <COMREG
       BPL    BOOT2           check drive ready
       CLR    <DRVREG         if not, momentarily deselect
       STA    <DRVREG         and reselect drives
       LDY    #20000
BLP1   LDB    #20
BLP2   DECB
       BNE    BLP2            wait 2 seconds
       LDB    <COMREG
       BPL    BOOT2           check drive ready every 100 usec
       LEAY   -1,Y
       BNE    BLP1
       LEAX   NRDYMS,PCR      if wait expires, abort boot
       LBRA   MONOUT           with message & return to GMXBUG

BOOT2  ORA    #$20            SET FOR SINGLE DENSITY
       STA    <DRVREG         SELECT DRIVE, DENSITY, & SIZE
       CLR    <DMAREG         DISABLE DMA
       LDA    #3
BOOT3  LDB    #$5B            STEP IN WITH UPDATE 3 TIMES
       BSR    CHKRDA
       DECA
       BNE    BOOT3
       LDB    #$0B            HOME AT 40ms PER STEPPING PULSE,
*                             LOAD HEAD AND VERIFY POSITION
       CLRA                    DISABLE DMA
       BSR    DCHKRD
       BITB   #04             CHECK FOR TRACK ZERO
       LBEQ   ERROR            IF NOT THEN ERROR
       LDX    #$C000          ADDRESS TO LOAD FROM DISK
       JSR    [LRA]            GET REAL ADDRESS
       STX    <ADDREG         GIVE ADDRESS TO DMA CONTROLLER
       ORA    #$10            ENABLE DMA
       LDB    #$8C            READ SINGLE RECORD, IBM FORMAT,
       BSR    DCHKRD           HLD, HLT AND 10 ms DELAY
       LBRA   ALLDON           GO DO FINAL STUFF

*THIS SUBROUTINE OUTPUTS SETTINGS TO THE DMA 68 AND A
*COMMAND TO THE 1797, THEN WAITS FOR THE 1797 TO FINISH
*THE COMMAND, AS INDICATED BY THE DMA 68 IRQ FLAG.

DCHKRD STA    <DMAREG         OUTPUT SETTINGS TO DMA 68
*                              ENTRANCE FOR LOOPED STEP COMMAND
CHKRDA STB    <COMREG         OUTPUT COMMAND TO 1797
CHKRD1 LDB    <DRVREG         WAIT TILL DMA 68 IRQ FLAG IS SET
       TST    <TRKREG         keep drives running
       ASLB
       BPL    CHKRD1
       LDB    <COMREG         RETURN 1797 STATUS IN ACCB
       RTS
DMAMSG FCC    "EXECUTING GIMIX DMA BOOTSTRAP"
       FCB    4
       FCB    10
NRFLAG FCC    "not ready"
       FCB     4

*Extra code to allow switching to OS-9 without FLEX
       
RESET  EQU    $FFFE            reset vector address
TSR    EQU    $FF7F            Task select register
       FILL $FF,173

       ORG    $F300
OS9    LEAX   SWITCH,PCR      point to switch code
       LDY    #$E500          point to scratchpad
       LDB    #12             set byte count
OS91   LDA    ,X+            copy switch code to RAM
       STA    ,Y+
       DECB
       BNE    OS91
       JMP    $E500           execute it
SWITCH CLRA
       TFR    A,DP            clear the DP register
       LDA    #$20
       STA    TSR             select OS9 task
       JMP    [RESET]          jump on reset vector
       FILL $FF,$4e0
       END
