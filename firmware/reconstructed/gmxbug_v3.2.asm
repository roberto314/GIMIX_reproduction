* GMXBG32

* GMXBUG interrupt handlers and DAT initialization for
* CPU-III board with vector for UAM and WPR trapping

* version to set up DAT for switching system
* also includes patch for new monitor switching circuit
* and new header string

SW3VEC  EQU    $DFC2
SW2VEC  EQU    $DFC4            soft interrupt vectors   
FIRVEC  EQU    $DFC6
IRQVEC  EQU    $DFC8
SWIVEC  EQU    $DFCA
NMIVEC  EQU    $E40A            
TRPVEC  EQU    $E460            vector for UAM/WPR/WDT/SST trap 
TSR     EQU    $E280            task select/control register
DATRAM  EQU    $F800            start of DAT memory
*COLD    EQU    $F82E            GMXBUG cold start
OS9ADD  EQU    $F5ED

*GMXBUG-09 V2.2F

*6809 ROM debugger"monitor
*Copyright (C) 1983 by Gimix, Inc. Chicago, Illinois
*All rights reserved

*Section origins

SBUGS   EQU     $DFC0     SBUG scratchpad
SCRATC  EQU     $E400     GMXBUG scratchpad
VIDPRM  EQU     $F400     Video ROM
GMXBUG  EQU     $F800     Start of GMXBUG
VECTOR  EQU     $FFF0     Interrupt vectors

*DP value for direct addressing of scratchpad

DPR     EQU     $E4
        SETDP   $E4

*I/O addresses

TERM    EQU     $E004     control terminal port
SPRINT  EQU     $E000     serial printer port
PPRINT  EQU     $E042     parallel printer port
*UPCASE  EQU     $E421

*SBUG compatible scratchpad

        ORG     SBUGS
        RMB     2

*pointers to interrupt handlers (SWTPc compatible)
*SW3VEC  RMB    2                SWI3
*SW2VEC  RMB    2                SWI2
*FIRVEC  RMB    2                FIRQ
*IRQVEC  RMB    2                IRQ
*SWIVEC  RMB    2                SWI

*Supervisor call table start & end

SVCORG  RMB    2
SVCLIM  RMB    12
CTLADR  RMB    2                address of control port

*GMXBUG scratchpad usage

        ORG     SCRATC

*I/O vectors

INVEC   RMB    2         char input
KEYVEC  RMB    2         quick char input
TSTVEC  RMB    2         char input test
OUTVEC  RMB    2         char output
PRTVEC  RMB    2         printer vector
        RMB    2         NMI vector
LINBUF  RMB    2
ENDLIN  RMB    2         end of line in buffer
BRKTBL  RMB    16        breakpoint table
MMODE   RMB    1         memory mode flag
UPCASE  RMB    1         force uppercase flag
BEGIN1  RMB    2         general purpose pointers
END1    RMB    2
BEGIN2  RMB    2
        RMB    2
SUBTOT  RMB    1         extra work byte
        RMB    4
WAIT    RMB    1         output suspended flag
MEMPTR  RMB    2         memory mode pointer
POINTR  RMB    2         extra pointer
NULLS   RMB    1         # of nulls after CR for printer
PRTFLG  RMB    1         printer type flag
DEST    RMB    1         console output flag
MATCH1  RMB    1         match bytes for hex locate
MATCH2  RMB    1
MATCH3  RMB    1

*ASCII equates

BS      EQU    $08       backspace
LF      EQU    $0A       line feed
CR      EQU    $0D       carriage return
CTLS    EQU    $13       control-S
ESC     EQU    $1B       escape
SPC     EQU    $20       space

********************************
*                             *
*                             *
*     START OF MONITOR        *
*                             *
*                             *
********************************

        ORG     GMXBUG

*vectors for indirect JMPs and JSRs

*SBUG-E compatible vectors

MONITR  FDB    COLD             cold start
NXTCMD  FDB    WARMS            warm start
INCH    FDB    INCHAR           char input
INCHE   FDB    INECHO           char input with echo
INCHEK  FDB    INTEST           test for char input
OUTCH   FDB    OUTCHR           char output
PDATA   FDB    PRTDAT           output string
PCRLF   FDB    CARRTN           output CR"LF
PSTRNG  FDB    PRTST            output string with CR"LF
LRA     FDB    LREAL            Load Real Address

        BRA    WARMS           for FLEX compatibility

*GMXBUG-09 V2.0 additional system calls

PSPACE  FDB    PRTSPC           output a space
PREGS   FDB    PRTREG           output register values
PBYTE   FDB    PRTBYT           output byte in hex
INKEY   FDB    GETKEY           quick char input
INCAPS  FDB    GETUPS           input uppercase char
HEXIN   FDB    GETHEX           input value in hexadecimal
BINHEX  FDB    BINCVT           convert binary to hex ASCII
HEXBIN  FDB    HEXCVT           convert hex ASCII to binary
LINEIN  FDB    GETLIN           input a line
TBSRCH  FDB    LOOKUP           table search
MOVBLK  FDB    MOVER0           move block of memory
PRINT   FDB    PRTOUT           hardcopy output

*Start of executable code

*Cold start initialization

COLD    LDS    #SCRATC+$3FF     set stack at top of scratch
        LDA    VIDPRM           test for video ROM
        CMPA   #$12             1st byte would be NOP
        LBEQ   VIDPRM

*default - initialize serial terminal

        LDU    #SCRATC          set up vectors to serial I/O
        LDX    #SERIN           routines in the scratch pad
        STX    ,U++
        LDX    #SERKEY
        STX    ,U++
        LDX    #SERTST
        STX    ,U++
        LDX    #SEROUT
        STX    ,U++
        LDX    #SPRINT+4        set SBUG control port pointer
        STX    SBUGS+$20
        LDA    #$13             reset printer & terminal ACIAs
        STA    ,X
        STA    -4,X

*initial setting for ACIAs:
*8 data bits, 1 stop bit, no parity, interrupt disabled

        LDA    #$15
        STA    ,X
        STA    -4,X

*Video initialization jumps here when done

SETUP   LDX    #HARDC           set printer output vector
        STX    ,U++
        LDX    #NMITRP          set NMI vector to point
        STX    ,U++            to GMXBUG abort handler
        LDD    #SCRATC+$300
        STD    ,U++            set line buffer pointer
        LEAU   18,U             skip over breakpoint table
        LDB    #26
COLD1   CLR    ,U+             zero the next 26 bytes
        DECB
        BNE    COLD1
        LDX    #DUMRTI
        LDU    #SW3VEC          set SBUG SWI2,SWI3,IRQ & FIRQ
        LDB    #4               vectors to point to RTI
COLD2   STX    ,U++
        DECB
        BNE    COLD2
        LDX    #BRKPT           set SBUG SWI vector to point
        STX    ,U++            to GMXBUG breakpoint routine
        LDX    #$FFFF           set SBUG SVC table pointers
        STX    ,U++            to SBUG default

*Warm start - also mainline loop re-entry

WARMS   LDX    #GMXHED          output header message
        BSR    PRTST
        LDX    #WARMS           put warmstart addr on stack
        LEAS   -2,S
        STX    ,S
        ORCC   #$80             set Entire flag in CCR
        PSHS   #$7F             save all the registers but PC

*Entrance from NMI trap

WARMS0  CLR    >MMODE
WARMS1  BSR    CARRTN
        LDA    #DPR
        TFR    A,DP              set DP to scratchpad
        TST    <MMODE
        BEQ    WARMS2            if in memory mode
        LDD    <MEMPTR           output pointer & byte contents
        LBSR   OUT4HS            instead of prompt
        LDU    <MEMPTR
        LDA    ,U
        LBSR   OUT2HS
        BRA    WARM25
WARMS2  LDX    #PROMPT          prompt the user for a command
        BSR    PRTDAT
WARM25  BSR    GETUPS          input command letter
        LDX    #CODTBL
        TST    <MMODE
        BEQ    WARMS3
        LDX    #MEMTBL
WARMS3  LBSR   LOOKUP        look up command in table
        BNE    WARMS1
        JSR    [,X]            do the command
        BRA    WARMS1           do another command
INCHAR  JMP    [INVEC]
INECHO  BSR    INCHAR
        CMPA   #$1B
        BEQ    INECX
OUTCHR  JMP    [OUTVEC]
GETUPS  INC    >UPCASE
        BSR    INECHO
        CLR    >UPCASE
INECX   RTS
INTEST  JMP    [TSTVEC]
GETKEY  JMP    [KEYVEC]
PRTST   BSR    CARRTN
PRTDAT  PSHS   A
ZF8FC   LDA    ,X+
        CMPA   #$04
        BEQ    PRTDT2
        BSR    OUTCHR
        BRA    ZF8FC
CARRTN  PSHS   A
        LDA    #$0D
        BSR    OUTCHR
        LDA    #$0A
        BSR    OUTCHR
PRTDT2  PULS   PC,A
LREAL   CLRA
        CMPX   #$DFFF
        BLS    LRAOUT
        ORA    #$0F
LRAOUT  RTS

*GMXBUG 09 extended utility subroutines

*Output a space

PRTSPC  PSHS   A
        LDA    #SPC
        BSR    OUTCHR
        PULS   A,PC

*Output registers
*This routine outputs the current contents
*of the machine registers. The PC value is the
*return address left by the call to this routine.

PRTREG  PSHS   #$7F              push all but PC
        TFR    S,U               copy stack pointer
        BSR    PRTR1             call output routine
        PULS   #$FF              exit by pulling all regs

*Callable subroutine for use by debugger - outputs
*registers previously stacked by breakpoint or interrupt

REGPRT  LEAU   4,S               point to stack
PRTR1   PSHS   U                 save SP value
        LDX    #REGID            output label string
        BSR    PRTST
        LDB    ,U+              output CCR as binary
        LBSR   BINRY1
        BSR    PRTSPC
        LDB    #3                output ACCA, ACCB, DPR
PRTRG1  LDA    ,U+
        LBSR   OUT2HS
        DECB
        BNE    PRTRG1
        LDB    #4                output IX, IX, US, PC
        PSHS   B                 keep count on stack
PRTRG2  LDD    ,U++
        LBSR   OUT4HS
        DEC    ,S
        BNE    PRTRG2
        LEAS   1,S               pop count off stack
        PULS   D                 output SP value
        BSR    PRTBYT
        TFR    B,A
*Fall thru to output LS byte of SP & exit

*Output ACCA contents as 2 hex digits

PRTBYT  PSHS   D                 save regs
PRTB1  BSR    BINCVT          convert ACCA
        BSR    OUTCHR            output 1st digit
        TFR    B,A
        LBSR   OUTCHR            output 2nd digit
        PULS   D,PC              restore regs & exit

*Hexadecimal input from console

GETHEX  INC    >UPCASE          force upper case input
        PSHS   X,Y
        BSR    GETLNL           input a line
        CLR    >UPCASE           reset case flag
        CMPA   #ESC              abort if terminated with ESC
        BEQ    GETHX3
        LDX    >LINBUF           get buffer pointer & convert
        BRA    HXCVT0
GETHX3  ORCC   #2                abort & set V=1
HXCVT9  TFR    Y,D               return with value in D
        PULS   X,Y,PC

*Convert string pointed to by IX to binary value in D

HEXCVT  PSHS   X,Y
HXCVT0  LDY    #0                clear IY as accumulator
HXCVT1  LDB    ,X+              get a char
        SUBB   #$30              remove ASCII offset
HXCVT2  CMPB   #9
        BLS    HXCVT3            if 0-9 OK
        CMPB   #$10
        BLS    HXCVT9            if :-? exit
        SUBB   #$7               adjust for A-F
        BITB   #$F0
        BNE    HXCVT9            terminate if not 0-$F
HXCVT3  CLRA                     clear MS byte of D
        EXG    D,Y               swap new nybble and total
        ASLB
        ROLA                    shift total 4 bits to the left
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        LEAY   D,Y               add back to next 4 bits
        BRA    HXCVT1

*Convert binary value in ACCA to hex digits in A:B

BINCVT  TFR    A,B               copy number
        BSR    CONVRT           convert low digit
        EXG    A,B               swap with orig value
        LSRA
        LSRA
        LSRA                    convert high digit
        LSRA
CONVRT  ANDA   #$F
        ADDA   #$90              trick convert 1 digit in ACCA
        DAA
        ADCA   #$40
        DAA
        RTS

*Input line into line buffer

GETLNL  LBSR   PRTSPC       leading space if needed
GETLIN  PSHS   B,X
        CLRB                     init char pointer
        LDX    >LINBUF
GETLN1  LBSR   INCHAR       input char no echo
        CMPA   #ESC
        BEQ    GETLN6       abort on ESC
        CMPA   #CR
        BEQ    GETLN6       terminate on CR
        CMPA   #BS
        BNE    GETLN3       move pointer back on BS
        TSTB
        BEQ    GETLN1       except at beginning
        DECB
        BRA    GETLN5
GETLN3  CMPB   #79               buffer full?
        BEQ    GETLN1           ignore printing chars
        STA    B,X               store char
        INCB                     bump pointer
GETLN5  LBSR   OUTCHR       echo char
        BRA    GETLN1
GETLN6  STA    B,X               store terminator
        ABX
        STX    >ENDLIN           store term position
        PULS   B,X,PC            exit

*Search table at [IX] for byte in ACCA

LOOKUP  CMPA   ,X+              match?
        BEQ    LOKOUT           yes - return Z=1
        LEAX   2,X              skip 2 data bytes
        TST    ,X              end of table?
        BNE    LOOKUP
        ANDCC  #$FB
LOKOUT  RTS                      not found: return Z=0

*Output to hard copy device

PRTOUT  JMP    [PRTVEC]

*Header message

GMXHED  FCC    "GMXBUG-09  V3.2"
        FCB    13
        FCB    10
        FCC    "(C) 1983 Gimix Inc"
        FCB    13
        FCB    10
        FCB     4

*Prompt string

PROMPT  FCC    "GMX:"
        FCB    4

*Label string for register dump

REGID   FCC    " EFHI NZVC A  B  DP  X    Y    U    PC   SP"
        FCB    13
        FCB    10
        FCB     4

*GMXBUG-09 commands

*Memory mode commands

MEMTBL  FCC    " "                    change & next
        FDB    CHGBMP
        FCC    "+"                    next
        FDB    BUMP
        FCC    "-"                    previous
        FDB    DROP
        FCC    "="                    change
        FDB    CHANGE
        FCC    "2"                    binary
        FDB    BINARY
        FCC    ;";                    ASCII entry
        FDB    ASCII
        FCC    "$"                    hex entry
        FDB    HEX
        FCB    CR                     exit memory mode
        FDB    MEMOFF
CODTBL  FCC    "A"                    hex arithmetic
        FDB    ARITHM
        FCC    "B"                    set breakpoint
        FDB    BRKSET
        FCC    "C"                    checksum
        FDB    CHKSUM
        FCC    "F"                    disassembly dump
        FDB    FDUMP
        FCC    "D"                    formatted memory dump
        FDB    DDUMP
        FCC    "G"                    exit from breakpoint
        FDB    GOTO
        FCC    "H"                    hex locate
        FDB    HEXLOC
        FCC    "I"                    initialize system values
        FDB    INIT
        FCC    "J"                    jump to address
        FDB    JUMP
        FCC    "K"                    kill breakpoints
        FDB    KILBRK
        FCC    "M"                    memory mode
        FDB    MEMODE
        FCC    "O"                    OS-9
        FDB    OS9CMD
        FCC    "P"                    print breakpoints
        FDB    PRTBRK
        FCC    "R"                    register dump & change
        FDB    REGDMP
        FCC    "T"                    test memory
        FDB    TSTMEM
        FCC    "U"                    jump to $F000
        FDB    USER
        FCC    "X"                    block move
        FDB    BLKMOV
        FCC    "Z"                    fill memory
        FDB    ZAPMEM
        FCC    "W"                    FLEX warm start
        FDB    FLXWRM
        FCB    0

*'A' - hex arithmetic

ARITHM  LBSR   GETADS       get 2 values
        BSR    OUTSPC
        LDD    <BEGIN1
        ADDD   <END1             add them together
        BSR    OUT4HS           output result
        LDD    <BEGIN1
        SUBD   <END1             subtract 2nd from 1st
        BRA    OUT4HS           print result & exit

*'C' - checksum a block of memory

CHKSUM  BSR    GETADS         get limits
        LDX    <BEGIN1          get start address
        CLRA                    zero accumulator
        CLRB
        CLR    <SUBTOT           zero 3rd byte
CHKSM1  ADDB   ,X+
        ADCA   #0                add carry if any
        BCC    CHKSM2
        INC    <SUBTOT           carry to 3rd byte if any
CHKSM2  LEAX   ,X
        BEQ    CHKSM3           terminate at 0000
        CMPX   <END1
        BLS    CHKSM1           end at END1 address
CHKSM3  PSHS   D                save low bytes of total
        BSR    OUTSPC
        LDA    <SUBTOT          output highest byte
        LBSR   PRTBYT

*Recover & output the lower 2 bytes

FADA    PULS   D

*Output 16-bit value in hex followed by a space

OUT4HS  LBSR   PRTBYT
        TFR    B,A

*Output 8-bit value followed by a space

OUT2HS  LBSR   PRTBYT
OUTSPC  LBRA   PRTSPC

*'D' - dump memory as hexadecimal and ASCII

DDUMP   BSR    GETADS         input start and end addresses
        LDX    #SPCMSG
        LBSR   PRTST           new line + 5 spaces
        LDB    #16
        LDA    <BEGIN1+1         at the top of each column
DDUMP1  ANDA   #$F               output the 4th digit of
        BSR    OUT2HS           the addresses
        INCA
        DECB
        BNE    DDUMP1
        LDX    <BEGIN1          get start address

*beginning of line loop

DDUMP2  LBSR   CARRTN       new line
        TFR    X,D
        BSR    OUT4HS       output current address
        LDB    #16
DDUMP3  LDA    ,X+              output 16 bytes in hex
        BSR    OUT2HS
        DECB
        BNE    DDUMP3
        BSR    OUTSPC           output 2 spaces
        BSR    OUTSPC
        LEAX   -16,X             move pointer back
        LDB    #16
DDUMP4  LDA    ,X+              print 16 bytes as ASCII
        ANDA   #$7F
        CMPA   #$20
        BHI    DDUMP7
DDUMP6  LDA    #'.'              replace 0-1F & 7F with "."
DDUMP7  CMPA   #$7F
        BEQ    DDUMP6
        LBSR   OUTCHR
        DECB
        BNE    DDUMP4
        BSR    EOLCHK          end check or pause at end of line
        BRA    DDUMP2

SPCMSG  FCC    "     "           string of 5 spaces for dump
        FCB    4
*Input 2 16-bit values & store in scratchpad with abort of
*calling routine if either input is terminated with ESC

GETADS  LBSR   GETHEX
        BVS    ESCOUT
        STD    <BEGIN1
        LBSR   GETHEX
        BVS    ESCOUT
        STD    <END1
        RTS

*Input hex value with caller abort on ESC

GETHX1  LBSR   GETHEX       input the value
        BVS    ESCOUT       if term was ESC return 2 levels
        RTS                  else return normally

*End of line end check or pause for dump & disassembly

EOLCHK  CMPX   <END1              compare current addr to bounds
        BHI    EOLCH1
        CMPX   <BEGIN1
        BLS    EOLCH1          if outside bounds check for done
        LBSR   INTEST           if in bounds, check for pause
        BNE    EOLCH2
        RTS                  continue if no input waiting

EOLCH1  LDD    <END1             check end value
        BEQ    EOLCH2          if end>0 exit command
ESCOUT  LEAS   2,S              exit calling routine (command)
        CLR    <WAIT             leave WAIT off
        RTS

EOLCH2  LBSR   INCHAR       if end=0 then pause
        CMPA   #ESC
        BEQ    ESCOUT       if ESC is typed exit command
        CMPA   #CTLS
        BNE    EOLCH3       if ctl-S is typed toggle WAIT
        COM    <WAIT
EOLCH3  TST    <WAIT             continue after 2nd ctl-S
        BNE    EOLCH2
        RTS

*'F' - disassembly dump

FDUMP   BSR    GETADS
        LDX    <BEGIN1
        STX    <POINTR

FDUMP1  LBSR   CARRTN
        LDD    <POINTR      output current address
        LBSR   OUT4HS
        LDB    #1           initialize byte count
        LDA    ,X+         get instruction byte
FDUMP2  CMPA   #$5F        changed from $60 in GMXBUG 2.2f
        BHI    FDUM50
        CMPA   #$3C
        BEQ    FDUMP4          CWAI
        CMPA   #$38         misc 1-bytes
        BGE    FDUM90
        BITA   #$10
        BEQ    FDUMP4          branches, direct one-ops
        CMPA   #$1E
        BLT    FDUMP3
        BITA   #4
        BEQ    FDUM58          LEA
        BRA    FDUMP4          EXG, TFR, PSH, PUL

FDUMP3  COMA
        BITA   #9
        BEQ    FDUM90          DAA, SEX
        COMA
        ANDA   #$0E
        BNE    FDUMP6
        INCB                extended page instructions
        LDA    ,X+        bump count & decode 2nd byte
        CMPA   #$2F
        BHI    FDUMP2
        INCB                add 1 for long branches
        BRA    FDUMP2

FDUMP6  CMPA   #6
        BLT    FDUM90          SYNC, NOP
        BGT    FDUMP4          ORCC, ANDCC
        INCB                LBRA, LBSR
        BRA    FDUMP4

*2-operand, & 1-operand indexed & extended

FDUM50  INCB
        ANDA   #$3F
        CMPA   #$30         extended
        BGE    FDUMP4
FDUM55  BITA   #$10             direct

        BNE    FDUM90
        BITA   #$20
        BNE    FDUM60
        CMPA   #3           test for 3-byte immediates
        BEQ    FDUMP4
        CMPA   #$0C
        BEQ    FDUMP4
        CMPA   #$0E
        BEQ    FDUMP4
        BRA    FDUM90

*indexed

FDUM58  INCB
FDUM60  LDA    ,X               decode postbyte
        BPL    FDUM90           5-bit offset
        ANDA   #$0F
        CMPA   #8
        BLT    FDUM90           auto(+ & -), reg & no offset
        CMPA   #$0B
        BEQ    FDUM90           D offset
        INCB
        BITA   #1
        BEQ    FDUM90           8-bit & 8-bit PC offset
FDUMP4  INCB

*output the instruction bytes in hex

FDUM90  LDX    <POINTR
FDUM91  LDA    ,X+
        LBSR   OUT2HS
        DECB
        BNE    FDUM91
        STX    <POINTR
         LBSR   EOLCHK           check for completion
         LBRA   FDUMP1

*'H' - hexadecimal locate for 1, 2, or 3 bytes

HEXLOC  LBSR   GETADS       get bounds for search
        LDX    #MATCH1
        CLR    <SUBTOT          get 1, 2, or 3 match byte values
        LDB    #3
        STB    <BEGIN2

HXLOC1  LBSR   GETHX1       input a hex value
        LDU    <ENDLIN          check line length
        CMPU   <LINBUF
        BEQ    HXLOC2          if null string, go search
        STB    ,X+
        INC    <SUBTOT          store match byte
        DEC    <BEGIN2
        BNE    HXLOC1

*beginning of search loop

HXLOC2  LDX    <BEGIN1
        LDU    #MATCH1
HXLOC3  CLRB
HXLOC4  LDA    B,X               compare a byte
        CMPA   B,U
        BNE    HXLOC5          if no match move pointer
        INCB                try the next byte
        CMPB   <SUBTOT
        BNE    HXLOC4          if match complete output address
HXLOC6  LBSR   CARRTN
        TFR    X,D
        LBSR   OUT4HS
HXLOC5  LEAX   1,X               bump pointer and check bounds
        BEQ    HXLOC7          terminate at 0000
        CMPX   <END1
        BLS    HXLOC3
HXLOC7  RTS

*'I' - initialize system values

INIT    BSR    SPCIL1
        LBSR   GETUPS        get subcommand
        LDX    #INITAB        scan table
        LBSR   LOOKUP
        BNE    REPORT          do report if no command
        BSR    SPCIL1
        JMP    [,X]             if found execute

*Initialization subcommand table

INITAB  FCC    "D"                    output device
        FDB    SETDST
        FCC    "N"                    null count
        FDB    SETNUL
        FCC    "P"                    printer type - in  part III
        FDB    SETPRT
        FCC    "U"                    soft reset
        FDB    RESETI
        FCB    0

*set console output device
*B=Both (screen & printer) otherwise screen only

SETDST  BSR    UPSIL1
        CMPA   #'B'
        BEQ    STDST1
        CLRA
STDST1  STA    <DEST
        RTS

*set null count - number of nulls after CR in printer output

SETNUL  BSR    GETHXX
        STB    <NULLS
        RTS

*report system status

REPORT  LDX    #SYSTAT          output status header
        LBSR   PRTST
        LDX    #NULLS
        LDA    ,X+
        LBSR   OUT2HS           output null count
        LDA    #'P'
        LDB    ,X+             output printer type
        BNE    REPRT1
        LDA    #'S'
REPRT1  BSR    REPRT2
        BSR    SPCIL1
        LDA    #'B'
        LDB    ,X+             output console device
        BNE    REPRT2
        LDA    #'S'
REPRT2  LBRA   OUTCHR

*status header

SYSTAT  FCC    "NL P D"
        FCB    13
        FCB    10
        FCB     4

*'O' - switch to OS-9 or other alternate monitor

OS9CMD  BSR    GETHXX
        LDX    #SWITCH
OS9     JSR    OS9ADD           call to extension
        NOP                     replaced instruction was 4 bytes
        LDB    #12
OS91    LDA    ,X+             copy switch code to RAM
        STA    ,Y+
        DECB
        BNE    OS91
        JMP    $E500             execute it

*this code is actually executed at $E500

SWITCH  CLRA
        TFR    A,DP              clear the DP register
        LDA    #$20
        STA    TSR+1             select OS9 task (was TSR in 2.2f)
        JMP    [RESET]           jump on reset vector

SPCIL1  LBRA   PRTSPC
UPSIL1  LBRA   GETUPS
GETHXX  LBRA   GETHX1

*'J' - JSR to user program
*RTS goes back to debugger mainline

JUMP    BSR    GETHXX           input jump address
        TFR    D,X
JUMP1   CLRA
        TFR    A,DP             set DP to 0
        JMP    ,X              go to user routine

*'U' - jump to PROM at $F000

USER    BSR    GETHXX
        LDX    #$F000
        BRA    JUMP1

*'W' - jump to FLEX warm start

FLXWRM  BSR    GETHXX
        LDX    #$CD03
        BRA    JUMP1

*'Z' - fill memory

ZAPMEM  LBSR   GETADS         input bounds
        BSR    GETHXX         input fill byte
        LDX    <BEGIN1
ZPMEM1  STB    ,X+              fill with specified value
        CMPX   <END1
        BLS    ZPMEM1
        RTS

*Memory mode commands

*'M' - turn on memory mode

MEMODE  BSR    GETHXX          input pointer value
        STD    <MEMPTR
        INC    <MMODE          set flag
        RTS

*CR - turn off memory mode

MEMOFF  CLR    <MMODE            exit memory mode on CR
        RTS

*' ' - change byte & bump pointer

CHGBMP  BSR    CHANGE

*'+' - bump pointer

BUMP    LEAU   2,U

*'-' - decrement address

DROP    LEAU   -1,U
DRPRTS  STU    <MEMPTR          store changed pointer
        RTS

*'=' - change byte

CHANGE  BSR    GETHXX          input a value
        STB    ,U             store it in memory
        RTS

*'2' - binary display

BINARY  LDB    ,U              get byte contents
BINRY1  BSR    DSPLAY          display MS nybble

*fall thru to display LS nybble

DSPLAY  BSR    SPCIL1          space between nybbles
        LDA    #4              output 4 bits
        PSHS   A
DSPLY1  CLRA

        ASLB                   shift a bit to ACCA
        ROLA
        ORA    #'0'            make ASCII
DSPLY2  LBSR   OUTCHR         output it
        DEC    ,S
        BNE    DSPLY1         decrement & loop
        PULS   A,PC            exit

*'"' - ASCII entry
*terminates on a CR, which is not stored

ASCII   LBSR   INECHO         input & echo a byte
        CMPA   #CR
        BEQ    DRPRTS         exit on CR
        STA    ,U+            store the byte in memory
        BRA    ASCII

*'$' - hexadecimal entry

HEX     BSR    GETHXX           input a value
        STB    ,U+             store in memory
        STU    <MEMPTR
        BRA    HEX              exit on GETHX1 abort

*End of memory mode commands

*'R' - register display & change

REGDMP  LBSR   REGPRT         output the register values
        LDX    #CHGMSG        output prompt
        LBSR   PRTST
        LBSR   GETUPS          input a char
        CMPA   #CR
        BEQ    RGD15          exit on CR
        LDX    #REGTBL        find char in register table
RGDMP1  CMPA   ,X++
        BEQ    RGDMP2
        TST    ,X
        BNE    RGDMP1
RGDABT  LDA    #'?'
        LBRA   OUTCHR         invalid char - exit with ?

RGDMP2  LDA    -1,X             get offset into stack from table
        PSHS   A
        LBSR   GETHEX         input new value
        TFR    D,Y
        PULS   A
        BVS    RGDABT         abort if ESC is entered
        TSTA                    changing stack value?
        BPL    RGDMP3
        TFR    Y,S            yes - set new SP
        LDX    #WARMS         setup return to mainline
        STX    ,-S
        JMP    ,X

RGDMP3  LEAU   2,S              adjust around return address
        LEAU   A,U             point to register
        CMPA   #4               1 or 2 byte register?
        BLT    RGDMP5
        STY    ,U              store 2 bytes
        RTS
RGDMP5  STB    ,U              store 1 byte
RGD15   RTS

*Prompt for register change

CHGMSG  FCC    "Register to change? "
        FCB    4

*Offsets for register change

REGTBL  FCC    "C"             CCR
        FCB    0
        FCC    "A"             ACCA
        FCB    1
        FCC    "B"             ACCB
        FCB    2
        FCC    "D"             DPR
        FCB    3
        FCC    "X"             IX
        FCB    4
        FCC    "Y"             IY
        FCB    6
        FCC    "U"             US
        FCB    8
        FCC    "P"             PC
        FCB    10
        FCC    "S"             SP
        FCB    255
        FCB    0

*'T' - memory test - does a convergence test
*that will detect most memory failures

TSTMEM  LBSR   GETADS          input bounds of test area
        CLRB                    init pass counter
TESTM1  LBSR   CARRTN

*fill memory with pattern

TSTM1A  LDX    <BEGIN1
TESTM2  BSR    MAKBYT           make byte & store
        STA    ,X+
        CMPX   <END1
        BLS    TESTM2

*compare memory with pattern

        LDX    <BEGIN1
TESTM3  BSR    MAKBYT           make byte & compare
        EORA   ,X+
        BNE    ERROR            exit on error
        CMPX   <END1
        BLS    TESTM3
        LDA    #'#'             output '#' for each pass
        LBSR   OUTCHR
        CLRA
        LBSR   GETKEY
        CMPA   #ESC
        BEQ    MKBRTS           exit if ESC is typed on console
        INCB                    bump pass counter
        BEQ    MKBRTS           exit after 256 passes
        BITB   #$3F
        BNE    TSTM1A           output CRLF every 64th pass
        BRA    TESTM1

*make byte for test - MS byte of addr + LS byte + pass #

MAKBYT  STX    <BEGIN2
        TFR    B,A
        ADDA   <BEGIN2
        ADDA   <BEGIN2+1
MKBRTS  RTS

*output error message, display wrong bits & exit

ERROR   LBSR   CARRTN
        LEAX   -1,X
        PSHS   A
        TFR    X,D
        LBSR   OUT4HS           output error address
        PULS   B
        LBRA   BINRY1           output error mask in binary

*'X' - block move

BLKMOV  LBSR   GETADS           input bounds of area to move
        LBSR   GETHX1           input destination address
        STD    <BEGIN2
MOVER1  LDD    <BEGIN2
        CMPD   <BEGIN1
        BLS    NORMAL           check for start<dest<=end
        CMPD   <END1
        BHI    NORMAL
        LDD    <END1
        SUBD   <BEGIN1
        ADDD   <BEGIN2
        TFR    D,U
        LDX    <END1
        LDD    <BEGIN1
        STD    <END1            invert end pointer
        LDB    #-1
        BRA    NORML1           go to move loop
NORMAL  LDX    <BEGIN1              load pointers
        LDU    <BEGIN2
        LDB    #1
NORML1  LDA    ,X                  move a byte
        STA    ,U
        LEAX   B,X
        LEAU   B,U
        CMPX   <END1            continue till bound is reached
        BNE    NORML1
        LDA    ,X
        STA    ,U              move last byte
        RTS

*entry for MOVBLK utility subroutine

MOVER0  PSHS   A,B,DP,X,U       save working registers
        LDA    #DPR             set DP
        TFR    A,DP
        BSR    MOVER1           do the move
        PULS   A,B,DP,X,U,PC   restore registers & exit

*'P' - output breakpoint table contents

PRTBRK  CLRB
        LDX    #BRKTBL          set pointer
PRTBK1  LBSR   CARRTN
        PSHS   B
        TFR    B,A
        LBSR   OUT2HS           output breakpoint #
        LDD    ,X
        LBSR   OUT4HS           output address
        LDA    8,X
        LBSR   PRTBYT           output saved byte
        LEAX   2,X
        PULS   B
        INCB
        CMPB   #4               loop for 4 breakpoints
        BLT    PRTBK1
        RTS

*'B' - set a breakpoint

BRKSET  BSR    PICKBR           input breakpoint number
        LBSR   GETHX1           input address
        CMPD   #$0000
        BEQ    BREAKX           exit if address is 0000
        PSHS   D                save address
        BSR    KLBRK1           if break set already kill it
        PULS   U                recover address
        LDA    ,U
        STU    ,X              put break address and contents
        STA    8,X              of byte in table
        LDA    #$3F
        STA    ,U              put SWI at address
BREAKX  RTS

*'K' - kill a breakpoint
*kill all 4 breakpoints if 'X' is entered

KILBRK  BSR    PICKBR           input brkpt number & set pointer
        LDU    <ENDLIN
        LDA    -1,U
        CMPA   #'X'             check for X
        BEQ    KILALL
KLBRK1  LDU    ,X              get address from table
        LDA    ,U
        CMPA   #$3F             check for SWI at addr
        BNE    KLBRK2           if no SWI, don't replace byte
        LDA    8,X              get byte contents
        STA    ,U              replace the byte
KLBRK2  CLR    ,X              zero the address & data entries
        CLR    1,X
        CLR    8,X
        RTS

*kill all 4 breakpoints

KILALL  LDX    #BRKTBL
        LDB    #4               loop for 4 entries
KILAL1  BSR    KLBRK1           use part of main routine
        LEAX   2,X
        DECB
        BNE    KILAL1
        RTS

*Input a breakpoint number & point into the table

PICKBR  LBSR   GETHEX           input a number
        BVS    PICKBX           abort with '?' if >3
        CMPD   #3
        BHI    PICKBX
        ASLB
        LDX    #BRKTBL          make pointer into brk table
        ABX
        RTS
PICKBX  LDA    #'?'             print '?' & exit to mainline
        LEAS   2,S
        LBRA   OUTCHR

*'G' - continue from breakpoint - executes an RTI

GOTO    LBSR   PRTSPC
        LBSR   INECHO           get a char
        CMPA   #CR
        BNE    BREAKX           abort if not CR
GOTO1   LEAS   2,S              pop return to GMXBUG mainline
        RTI

*Breakpoint handler

BRKPT   LDX    10,S
        LEAU   -1,X             adjust return address
        BEQ    BRKSWI           if addr=0 can't be breakpoint
        CLRB
        LDX    #BRKTBL
BRKP1   CMPU   ,X++           search breakpoint table for addr
        BEQ    FDBKPT
        INCB
        CMPB   #4               check four entries
        BNE    BRKP1
BRKSWI  LDB    #$FF             not in table - user SWI
FDBKPT  PSHS   B
        LBSR   CARRTN           found - output "#"
        LDA    #'#'
        LBSR   OUTCHR
        PULS   A
        LBSR   PRTBYT           output breakpoint #
        STU    10,S             put adjusted PC back in stack
        TFR    S,U
        LBSR   PRTR1            output register contents
        LBRA   WARMS1           jump to debugger mainline

*Console I/O routines for serial interface

*Wait for input then return with char in ACCA

SERIN   BSR    SERKEY
        BEQ    SERIN            wait till SERKEY returns Z=0
        RTS

*Return any pending input in ACCA; Z=0 if input found

SERKEY  BSR    SERTST
        BEQ    SERKYX           exit if no input waiting
        LDA    TERM+1           get the char
        ANDA   #$7F             mask off parity bit
        TST    >UPCASE
        BEQ    SERKY8           force uppercase if flag is set
        CMPA   #'a'
        BLT    SERKY8
        CMPA   #'z'
        BGT    SERKY8
        ANDA   #$5F
SERKY8  ANDCC  #$FB             set Z=0 to indicate data
SERKYX  RTS

*Test for pending input; Z=0 if so, else Z=1

SERTST  PSHS   A
        LDA    TERM
        BITA   #$1              check RxDRF
        PULS   A,PC

*Serial terminal output - character in ACCA

SEROUT  PSHS   D
SER1    LDB    TERM
        BITB   #2
        BEQ    SER1             wait for TxDRE
        STA    TERM+1           put char in ACIA
        TST    >DEST
        BNE    HRDCPY           do hardcopy if flag is set
SERX    PULS   D,PC             else exit

*Printer output subroutines

*Print the char in ACCA on the hard copy device

HARDC   PSHS   D
HRDCPY  BSR    HRDOUT           output the char
        CMPA   #CR
        BNE    HARDCX           if char was CR, output nulls
        LDB    >NULLS
        BEQ    HARDCX           if null count=, exit
        CLRA
HRDCP1  BSR    HRDOUT           output # of nulls in NULLS
        DECB
        BNE    HRDCP1
HARDCX  PULS   D,PC             exit

*Actual printer output routine

HRDOUT  PSHS   B
        TST    >PRTFLG          check printer type flag
        BNE    PARLEL

*Serial printer routine

SERIAL  LDB    SPRINT           wait for TxDRE
        BITB   #2
        BEQ    SERIAL
        STA    SPRINT+1         put char in ACIA
        PULS   B,PC             exit

*Parallel printer routine

PARLEL  TST    PPRINT+1         wait for printer ready
        BPL    PARLEL
PARLL1  TST    PPRINT           clear IRQ flag
        STA    PPRINT           put data in PiA
        LDB    #$36
        STB    PPRINT+1         toggle handshake output
        LDB    #$3E
        STB    PPRINT+1
        PULS   B,PC             exit

*Subcommand P of I command
*Set printer type - S=serial  P=parallel

SETPRT  LBSR   GETUPS           input a character
        CMPA   #'S'
        BEQ    SETSRL           compare to S & P
        CMPA   #'P'
        BNE    STPTOT           exit if neither
        STA    <PRTFLG          set flag
        LDX    #PPRINT          initialize PIA
        CLR    1,X
        LDA    #$FF             set DDR for output
        STA    ,X
        LDA    #$3E             set up strobe
        STA    1,X
        CLRA
        PSHS   A               adjust stack for output routine
        BRA    PARLL1           exit thru output routine

*initialize for serial printer

SETSRL  CLR    <PRTFLG          set flag
STPTOT  RTS                      ACIA is set up by default

*Handler for Non-Maskable Interrupt

NMITRP  TFR    S,U              copy stack pointer
        LBSR   PRTR1            print register contents
        LDX    #NMIMSG
        LBSR   PRTST            output NMI message
        LBSR   INECHO           get a char
        ANDA   #$DF             force upper case
        CMPA   #'Y'
        LBNE   WARMS0           if Y, return to program
DUMRTI  RTI                       else go to GMXBUG

NMIMSG  FCC    ;NMI: restart (Y/N)? ;
        FCB    4

* Note: DAT is automatically available at power-up at
* $F800.  However this goes away on the first write to
* an odd address in the DAT. Therefore the first write
* to the DAT must be to $F83E-$F83F to set up the monitor
* in task 0. Then the monitor reset routine can finish
* setting up the rest of task 0.

RESETI  LDX    #DATRAM+64      reset DAT - map task 0 to
        LDD    #$1FF           bank 15, segment to block
RES1    STD    ,--X           from the top down
        DECB                   for the top 8K
        CMPX   #DATRAM+56      ($E000-$FFFF)
        BNE    RES1
        SUBD   #$1E0           map the rest of task 0
RES2    STD    ,--X           ($E000-$FFFF) to bank 15
        DECB
        BPL    RES2
        LDX    #COLD
        STX    >TRPVEC          set default ERRTRP value
        JMP    ,X             go to main GMXBUG coldstart

*Jumps to soft interrupt vector addresses

TRPHND  JMP    [TRPVEC]
SW3HND  JMP    [SW3VEC]
SW2HND  JMP    [SW2VEC]
FIRHND  JMP    [FIRVEC]        handlers to use soft vectors
IRQHND  JMP    [IRQVEC]
SWIHND  JMP    [SWIVEC]
NMIHND  JMP    [NMIVEC]

ENDCOD  EQU    *

*        FILL $FF,7
*Absolute interrupt vectors

        ORG    VECTOR

RESERV  FDB    TRPHND          system trap vector (ex-reserved)
SWI3    FDB    SW3HND
SWI2    FDB    SW2HND
FIRQ    FDB    FIRHND          hard interrupt vectors
IRQ     FDB    IRQHND
SWI     FDB    SWIHND
NMI     FDB    NMIHND
RESET   FDB    RESETI

        END
