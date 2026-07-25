            * IOPDRV

            * This program resides in RAM on the IOP.  It supports
            * a terminal as console on port 1 and a printer on port 2.

RAM1    EQU    0                2K RAM
RAM2    EQU    $2000
RAMROM  EQU    $C000            2K RAM or 2K/4K/8K ROM
ROM1    EQU    $E000            2K/4K/8K ROM

            * addresses of DIP switch registers
SWTCH1  EQU    $6000
SWTCH2  EQU    $4000

            * addresses of 6551 serial ports
PORT1   EQU    $A004
PORT2   EQU    $A008
PORT3   EQU    $A010

            * offsets for 6551s
DATA51  EQU    0
STAT51  EQU    1
CMND51  EQU    2
CTRL51  EQU    3

            * address of FIO
FIODAT  EQU    $8000
FIOCTL  EQU    $8001

            * offsets for indirect addressing of FIO registers
CTLRG0  EQU    0                reset/mode control
CTLRG1  EQU    1                mailbox/REQ control
ISTAT0  EQU    2                message IRQ ctl
CTLRG2  EQU    9                port 2 control
MSGOUT  EQU    11               outgoing message byte
MSGIN   EQU    12               incoming message byte


        ORG    $2000                place in same RAM as stack

START   LDS    #$27FF           init stack pointer

        LDA    #$0B             no parity or IRQs, RTS & DTR low
        LDB    SWTCH1           get baud rate for port 1
        ANDB   #$0F
        ORB    #$10             1 stop bit, 8 data bits, no echo
        STD    PORT1+CMND51     set up port 1 (console)
        LDB    SWTCH1           get baud rate for port 2
        LSRB
        LSRB
        LSRB
        LSRB
        ORB    #$10             1 stop bit, 8 data bits, no echo
        STD    PORT2+CMND51     set up port 2 (printer)

            * main execution loop

DOFIFO  BSR    RECEIV           get a command byte from host
        CMPB   #CMDLMT
        BHI    DOFIFO           do not accept undefined commands
        LEAX   CMDTBL,PCR
        ASLB
        JSR    [B,X]            call selected routine
        BRA    DOFIFO           return and do next command

CMDTBL  FDB    NULL             null command
        FDB    CNSTAT           sample status of console ACIA
        FDB    PRSTAT           sample status printer ACIA
        FDB    CNSEND           send data to console
        FDB    PRSEND           send data to printer
        FDB    CNRECV           receive data from console

TBLSIZ  EQU    *-CMDTBL
CMDLMT  EQU    TBLSIZ/2-1

            * get status of console

CNSTAT  LDB    PORT1+STAT51     get status byte from 6551
        BSR    SEND             return it to host
NULL    RTS

            * get status of printer

PRSTAT  LDB    PORT2+STAT51     get status byte from 6551
        BSR    SEND             return it to host
        RTS

            * output a character to console

CNSEND  BSR    RECEIV           get data byte from host
        STB    PORT1+DATA51     put it in console 6551
        RTS

            * output a character to printer

PRSEND  BSR    RECEIV           get data byte from host
        STB    PORT2+DATA51     put it in printer 6551
        RTS

            * receive character from console

CNRECV  LDB    PORT1+DATA51     get data byte from 6551

            * send a byte (in ACCB) to the host

SEND    LDA    #MSGOUT
        BSR    STUFF            send the byte
SEND1   LDA    #CTLRG1          wait till last byte is accepted
        BSR    GRAB
        BITB   #$20
        BNE    SEND1
        RTS

            * receive a byte through the 8038 mailbox from the host

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

CODSIZ  EQU    *-START
        FILL   $FF,404
        END