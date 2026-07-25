#!/bin/bash
#
#ASS=`which lwasm`
ASS=./lwasm
#DIR="/home/rob/Projects/mc-6502_mini/"
PWD=`pwd`
echo $ASS

NAME=gmxbug_v2.2f
$ASS --list-nofiles --abs -9l $NAME.asm --output=$NAME.bin --list=$NAME.lst

NAME=gmxbug_v3.2
$ASS --list-nofiles --abs -9l $NAME.asm --output=$NAME.bin --list=$NAME.lst

NAME=autoboot_v1.5
$ASS --list-nofiles --abs -9l $NAME.asm --output=$NAME.bin --list=$NAME.lst

NAME=IOPGMX
$ASS --list-nofiles --abs -9l $NAME.asm --output=$NAME.bin --list=$NAME.lst

NAME=IOPDRV
$ASS --list-nofiles --abs -9l $NAME.asm --output=$NAME.bin --list=$NAME.lst


# just for comparison
#${ASS}   ${NAME2}.asm -l > ${NAME2}.lst
#srec_cat ${NAME2}.s19 -motorola -fill 0xff 0x0000 0x7fff -o ${NAME2}.bin -binary # filled with FFs

#rm ${NAME}.o
#srec_cat ${NAME}.bin -binary -offset 0x7800 -output ${NAME}.hex -Intel -address_length=2 
#srec_cat ${NAME}.s19 -motorola -offset -0x4800 -fill 0xff 0x0000 0x37ff -o ${NAME}.bin -binary # strip off the beginning

#cp -u ${NAME}.bin ../

#Compare
#xxd IMO100.bin > main.hex
#xxd main_reassembled.bin > main_reassembled.hex
#diff main.hex main_reassembled.hex
DEST=GIMIX_SPPT.bin
dd if=autoboot_v1.5.bin of=$DEST bs=1 count=$((0x260))
cat Unknown.bin >> $DEST
cat IOPGMX.bin >> $DEST
cat IOPDRV.bin >> $DEST
cat gmxbug_v3.2.bin >> $DEST