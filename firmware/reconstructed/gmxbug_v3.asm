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
COLD    EQU    $F82E            GMXBUG cold start
                                
        ORG    $F9FD

HEADER  FCC    /GMXBUG-09  V3.2/,13,10
        FCC    /(C) 1983 Gimix Inc/,13,10,4
HDREND  EQU    *

            * patch to monitor switching routine

        ORG    $FCB3
        STA    TSR+1            write to TSR+1

* Note: DAT is automatically available at power-up at
* $F800.  However this goes away on the first write to
* an odd address in the DAT. Therefore the first write
* to the DAT must be to $F83E-$F83F to set up the monitor
* in task 0. Then the monitor reset routine can finish
* setting up the rest of task 0.


        ORG    $FFB4

RESETI  LDX    #DATRAM+64      reset DAT - map task 0 to
        LDD    #$1FF           bank 15, segment to block
RES1    STD    0,--X           from the top down
        DECB                   for the top 8K
        CMPX   #DATRAM+56      ($E000-$FFFF)
        BNE    RES1
        SUBD   #$1E0           map the rest of task 0
RES2    STD    0,--X           ($E000-$FFFF) to bank 15
        DECB
        BPL    RES2
        LDX    #COLD
        STX    TRPVEC          set default ERRTRP value
        JMP    0,X             go to main GMXBUG coldstart

TRPHND  JMP    [TRPVEC]
SW3HND  JMP    [SW3VEC]
SW2HND  JMP    [SW2VEC]
FIRHND  JMP    [FIRVEC]        handlers to use soft vectors
IRQHND  JMP    [IRQVEC]
SWIHND  JMP    [SWIVEC]
NMIHND  JMP    [NMIVEC]

ENDCOD  EQU    *

        ORG    $FFF0

        FDB    TRPHND          system trap vector (ex-reserved)
        FDB    SW3HND
        FDB    SW2HND
        FDB    FIRHND          hard interrupt vectors
        FDB    IRQHND
        FDB    SWIHND
        FDB    NMIHND
        FDB    RESETI

        END

SYMBOL TABLE:

COLD    F82E    DATRAM  F800    ENDCOD  FFEE    FIRHND  FFDE    FIRVEC  DFC6
HDREND  FA23    HEADER  F9FD    IRQHND  FFE2    IRQVEC  DFC8    NMIHND  FFEA
NMIVEC  E40A    RES1    FFBA    RES2    FFC5    RESETI  FFB4    SW2HND  FFDA
SW2VEC  DFC4    SW3HND  FFD6    SW3VEC  DFC2    SWIHND  FFE6    SWIVEC  DFCA
TRPHND  FFD2    TRPVEC  E460    TSR     E280
