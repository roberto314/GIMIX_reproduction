
            * IOPGMX

            * This program resides at $F400 in the GMXBUG 3.2 ROM,
            * It supports a serial terminal as console on port 1,
            * and a serial device as printer on port 2. IOPGMX
            * includes subroutines to support the GMXBUG calls
            * INCH, INCHEK, OUTCH, and PRINT, and also handles
            * the "force upper case" and "output to both screen
            * and printer" features.  The special general IRQ
            * mask of the CPU III is used to avoid the conflicts
            * that would result if an NMI, IRQ, or FIRQ were to
            * occur during console or printer I/O.  However, this
            * can cause spurious NMIs.  To avoid this a modified
            * NMI handler is provided.

            * IOPGMX also includes a patch to the "O" command for
            * switching to OS-9; this patch makes sure that the IOP
            * is in a state of reset when OS-9 comes up.

            * Because of this patch code, the binary image of this
            * program MUST overlay GMXBUG 3.2, rather than vice versa.

INCHE   EQU    $F806
PSTRNG  EQU    $F810
RENTER  EQU    $F86E            reentry address for GMXBUG 3.2
RENTR1  EQU    $F83B            reentry address for normal init
WARMS0  EQU    $F8A4            addresses for NMI handler
PRTR1   EQU    $F92D
TSR     EQU    $E280            Task Status Register of CPU III
INVEC   EQU    $E400            console input vector
UPCASE  EQU    $E421            force uppercase input flag
PTRFLG  EQU    $E435            printer type flag
DEST    EQU    $E436            printer output flag
NMICTL  EQU    $E462            NMI inhibit control flag
DRVADR  EQU    $2000            load address for driver code
DRVTFR  EQU    $2000            transfer address for driver
DRVSIZ  EQU    $77              size of driver code
FIODAT  EQU    $E000            address of FIO
FIOCTL  EQU    $E001
FIOIRQ  EQU    $E002
PPRINT  EQU    $E042            address of printer PIA

            * offsets for indirect addressing of FIO registers
CTLRG0  EQU    0                reset/mode control
CTLRG1  EQU    1                mailbox/REQ control
ISTAT0  EQU    2                message IRQ ctl
CTLRG2  EQU    9                port 2 control
MSGOUT  EQU    11               outgoing message byte
MSGIN   EQU    12               incoming message byte

        ORG    $F400

START   NOP                     address for alternate I/O ROM
        BRA    BEGIN            NOP at $F400 is flag to GMXBUG

            * These two vectors are set up for use by PRINT.SYS
PRTTST  LBRA   IOPCHP           vector to IOP printer check
PRTOUT  LBRA   IOPPRT           vector to IOP printer output

BEGIN   LDA    TSR              check CPU III sense bit (JA-9)
        BITA   #$10             if sense bit is 1, (jumper open)
        LBNE   RENTR1           resume normal initialization

        STA    FIOIRQ
        LDA    FIOCTL           reset sequence for FIO
        LDA    FIOCTL
        LDA    #CTLRG0
        LDB    #1               toggle FIO reset bit
        LBSR   STUFF
        CLRB
        LBSR   STUFF
        LDA    FIOCTL
        LDA    #CTLRG0
        LDB    #$14             set non-Z-bus, vector w/status
        LBSR   STUFF
        LDA    #CTLRG2
        LDB    #1
        LBSR   STUFF            enable IOP side

WAIT    LDA    #5
WAIT1   LDX    #62500           delay 1.25 seconds for
WAIT2   LEAX   -1,X              IOPROM to complete its setup
        BNE    WAIT2            and enter the wait loop
        DECA
        BNE    WAIT1

        LDB    #$F0             tell IOP to jump to GMX loader
        BSR    SEND
        LDA    #20              delay 100 cycles for
WAIT3   DECA                     loader internal setup
        BNE    WAIT3

HEADBT  LDB    #$55             send start-of-record byte
        BSR    SEND
        BSR    RECEIV
        CMPB   #$55             get $55 back from IOP
        BNE    HEADBT

        LDB    #DRVADR/256      send load address
        BSR    SEND
        LDD    #DRVADR
        BSR    SEND
        LDB    #DRVSIZ/256      send byte count
        BSR    SEND
        LDD    #DRVSIZ
        BSR    SEND

        LDB    #DRVTFR/256      send transfer address
        BSR    SEND
        LDD    #DRVTFR
        BSR    SEND

        LEAX   DRIVER,PCR       send the block of code
        LDY    #DRVSIZ
SNDBLK  LDB    ,X+             get a byte
        BSR    SEND             send it
        LEAY   -1,Y             end of block?
        BNE    SNDBLK           continue if not

            * IOP will now be running in GMXBUG driver mode

        LDU    #INVEC           point to GMXBUG vector area
        LDD    #IOPINP
        STD    ,U++
        LDD    #IOPKEY          set up console I/O vectors
        STD    ,U++
        LDD    #IOPTST
        STD    ,U++
        LDD    #IOPOUT
        STD    ,U++
        LDD    #IOPPRT          set up printer vector
        STD    ,U++
        LDD    #IOPNMI          set up NMI handler
        STD    ,U++
        CLR    NMICTL           enable NMI reenable
        JMP    RENTER           reenter GMXBUG

            * send a byte (in ACCB) to the slave

SEND    LDA    #MSGOUT
        BSR    STUFF            send the byte
SEND1   LDA    #CTLRG1          wait till last byte is accepted
        BSR    GRAB
        BITB   #$20
        BNE    SEND1
        RTS

            * receive a byte through the 8038 mailbox from the slave

RECEIV  LDA    #ISTAT0          get Interrupt Status 0
RECV1   BSR    GRAB
        BITB   #$20             check Message IP
        BEQ    RECV1            wait till it's set
        LDA    #MSGIN           get Message byte

            * read the 8038 register pointed to by ACCA

GRAB    STA    FIOCTL           point to the register
        LDB    FIOCTL           read it
        RTS

            * put the value in ACCB in the register pointed to by ACCA

STUFF   STA    FIOCTL           point to the register
        STB    FIOCTL           write to it
        RTS

            * INCH equivalent - get input from console

IOPINP  PSHS   B
IOPIN1  BSR    IOPTST           check console 6551 status
        BEQ    IOPIN1           if no data, continue to wait
        BSR    IOPGET           else get character
        PULS   B,PC             and exit

            * INCHEK equivalent - test for console input waiting

IOPTST  PSHS   D
        LBSR   MASK             mask interrupts
        LDB    #1               get status of console 6551
        BSR    SEND
        BSR    RECEIV
        LBSR   UNMASK           unmask interrupts
        BITB   #8               test RxDRF bit
        PULS   D,PC             return Z=1 or Z=0

            * INKEY equivalent - get input from console without waiting

IOPKEY  PSHS   B
        BSR    IOPTST           test for input waiting
        BEQ    IOPK1            if none, exit with Z=1
        BSR    IOPGET           else get input and exit
        ANDCC  #$FB             with Z=0 (input found)
IOPK1   PULS   B,PC

            * get a character from console through IOP

IOPGET  PSHS   B
        LBSR   MASK             mask interrupts
        LDB    #5               get data
        BSR    SEND
        BSR    RECEIV
        LBSR   UNMASK           unmask interrupts
        TFR    B,A              move data to ACCA
        TST    UPCASE           force upper case flag set?
        BEQ    IOPG1
        CMPA   #'a'             if so, is input a-z?
        BLT    IOPG1
        CMPA   #'z'
        BGT    IOPG1
        ANDA   #$DF             if so, convert to upper case
IOPG1   PULS   B,PC             restore ACCB and exit

            * OUTCH equivalent - send character to console through IOP

IOPOUT  PSHS   D
IOP01   LBSR   MASK             mask interrupts
        LDB    #1               get console 6551 status
        BSR    SEND
        BSR    RECEIV
        LBSR   UNMASK           unmask interrupts
        BITB   #$10             test TxDRE
        BEQ    IOP01            if 0 continue to wait
        BITB   #$60             test DCD and DSR bits also
        BNE    IOP01            if either not 0, wait
        LBSR   MASK             mask interrupts
        LDB    #3
        LBSR   SEND
        LDB    ,S              output byte to console
        LBSR   SEND
        LBSR   UNMASK           unmask interrupts
        TST    DEST
        BEQ    IOP02
        LDA    ,S
        BSR    IOPPRT           if so do it
IOP02   PULS   D,PC             restore ACCs and exit

            * PRINT equivalent - send character to printer through IOP

IOPPRT  PSHS   D
        TST    PTRFLG           check for parallel printer
        BNE    PARLEL           if so branch to parallel driver
IOPPR1  BSR    IOPCHP           check printer 6551 status
        BEQ    IOPPR1           wait till printer is ready
        LBSR   MASK             mask interrupts
        LDB    #4
        LBSR   SEND
        LDB    ,S              output data byte to printer
        LBSR   SEND
        LBSR   UNMASK           unmask interrupts
        PULS   D,PC             restore regs and exit

            * Parallel printer routine

PARLEL  TST    PPRINT+1         wait for printer ready
        BPL    PARLEL
PARLL1  TST    PPRINT           clear IRQ flag
        STA    PPRINT           put data in PiA
        LDB    #$36
        STB    PPRINT+1         toggle handshake output
        LDB    #$3E
        STB    PPRINT+1
        PULS   D,PC             exit

            * subroutine for FLEX: sample printer status
            * and return Z=0 if printer is ready

IOPCHP  PSHS   D
        LBSR   MASK             mask interrupts
        LDB    #2
        LBSR   SEND             get status of printer 6551
        LBSR   RECEIV
        LBSR   UNMASK           unmask interrupts
        BITB   #$10             test for TxDRE=1
        BEQ    IOPCH1           if 0 exit immediately with Z=1
        BITB   #$60             else test for DCD=1 or DSR=1
        TFR    CC,A             and invert resulting Z-bit;
        EORA   #4               thus at exit
        TFR    A,CC             Z=0 IFF TxDRE=1 & DCD=0 & DSR=0
IOPCH1  PULS   D,PC             restore ACCs and exit

            * Mask all interrupts during FIO handshake operations

MASK    LDA    TSR              get TSR value
        ANDA   #8               preserve clock write enable bit
        ORA    #1               set TSR task bits to non-zero
        STA    TSR              value, masking all interrupts
        RTS

            * Restore interrupts

UNMASK  TST    NMICTL           is NMI active?
        BNE    UNMSK2           if so leave it masked
        LDA    TSR              get TSR value
        ANDA   #8               preserve clock write enable bit
        STA    TSR              clear task bits
UNMSK2  RTS

            * revised handler for Non-Maskable Interrupt

IOPNMI  INC    NMICTL           "inhibit" bogus extra NMIs
        TFR    S,U              copy stack pointer
        JSR    PRTR1            print register contents
        LEAX   NMIMSG,PCR       output NMI message
        JSR    [PSTRNG]
        JSR    [INCHE]           get a char
        PSHS   A
        CLR    NMICTL           release NMI unmask control
        BSR    UNMASK           unmask NMI
        PULS   A
        ANDA   #$DF             force upper case
        CMPA   #'Y'             Y??
        LBNE   WARMS0           if not, go to GMXBUG
        RTI                  else return to program
NMIMSG  FCC    ;NMI: restart (Y/N)? ;
        FCB    4
            * Extension to "O" command in GMXBUG

OS9ADD  STA    FIOIRQ           reset the IOP if any
            * 1 line of code was replaced by JSR to here
            * must be performed before returning
        LDY    #$E500           point to RAM for switch code
        RTS

DRIVER  RMB    DRVSIZ           driver code storage area

CODSIZ  EQU    *-START          total size of IOP support code

* "O" command patch (is already included)
*        ORG    $FC9E
*        JSR    OS9ADD           call to extension
*        NOP                     replaced instruction was 4 bytes
        END

