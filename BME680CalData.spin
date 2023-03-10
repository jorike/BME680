{BME680 reset, device id and setting the device calibration data using the I2C Bus specification.

Version 1

┌──────────────────────────────────────────┐
│ BME680                                   │
│ Author: James Rike                       │
│ Copyright (c) 2023 Seapoint Software     │
│ See end of file for terms of use.        │
└──────────────────────────────────────────┘

}


CON
  SDA_pin = 18
  SCL_pin = 17

  T_buf   = 65                  'Minimum of 1.3 usec
  T_su    = 48                  'Minimum of .6 usec
  T_hdSr  = 35                  'Minimum of .6 usec
  T_hdSa  = 25                  'Minimum of .6 usec
  T_suDat = 16                  'Minimum of .6 usec

VAR
  long pT1, pT2, pT3
  long pP1, pP2, pP3, pP4, pP5, pP6, pP7, pP8, pP9, pP10
  long pH1, pH2, pH3, pH4, pH5, pH6, pH7

  byte cogCal


OBJ
  'pst    : "Parallax Serial Terminal"

PUB Start                                               'Cog start method
    Stop
    cogCal := cognew(@_entry, @pT1) + 1
    repeat until long[@pH7] <> 0                        'Wait until calibration cog is finished
    Stop
    'PrintData {Debug}

PUB Stop                        'Cog stop method
    if cogCal
      cogstop(cogCal~ - 1)

PUB getCalData(calAdr)
  longmove(calAdr,@pT1,20)

{PRI PrintData
  pst.Start(115_200)
  pst.char(0)
  pst.str(string("*-----Initializing-----*"))

  repeat
    waitcnt(clkfreq*5+cnt)
    pst.char(0)
    pst.str(string("*-------------------*"))
    pst.NewLine
    pst.hex(pT1,4)
    pst.NewLine
    pst.hex(pT2,4)
    pst.NewLine
    pst.hex(pT3,4)
    pst.NewLine
    pst.hex(pP1,4)
    pst.NewLine
    pst.hex(pP2,4)
    pst.NewLine
    pst.hex(pP3,4)
    pst.NewLine
    pst.hex(pP4,4)
    pst.NewLine
    pst.hex(pP5,4)
    pst.NewLine
    pst.hex(pP6,4)
    pst.NewLine
    pst.hex(pP7,4)
    pst.NewLine
    pst.hex(pP8,4)
    pst.NewLine
    pst.hex(pP9,4)
    pst.NewLine
    pst.hex(pP10,4)
    pst.NewLine
    pst.hex(pH1,4)
    pst.NewLine
    pst.hex(pH2,4)
    pst.NewLine
    pst.hex(pH3,4)
    pst.NewLine
    pst.hex(pH4,4)
    pst.NewLine
    pst.hex(pH5,4)
    pst.NewLine
    pst.hex(pH6,4)
    pst.NewLine
    pst.hex(pH7,4)
}

DAT
        org 0
_entry

        rdlong sfreq, #0

       '****************Soft Reset**************
        call #starts                            'Send START to the sensor (rx), sets clock and data pins low (26 + ticks)
        call #devadrw                           'Write to device address 0x77
        call #acks

        mov tmp, dev_adr_reset                  '0xE0 Reset register address
        call #data_out
        call #acks

        mov tmp, dev_reset                      '0xB6 reset command
        call #data_out
        call #acks
        call #stops
        call #Tbuf

        '****************End of soft reset*****************

        mov time, cnt
        mov delay, sfreq/500
        add time, delay

        '**************Start of read device ID*************

        call #starts                            'Send start
        call #devadrw                           'Write to device address 0x77
        call #acks                              'Bit 9 ACK - End of write

        mov tmp, dev_adr_id                     'Device ID register address 0xD0
        call #data_out                          'Send the address
        call #acks                              'Bit 9 ACK

        call #startr                            'Send start
        call #devadrr                           'Read from device address 0x77
        call #acks                              'Bit 9 ACK

        call #read_in                           'Read the data
        call #nackm                             'NACKM
        call #stops                             'End of transaction
        mov id_data, data_byte                  'Device ID data = 0x61
        call #Tbuf                              'Ensure proper delay between stop and start

        '********************Get calibration data*************
        call #starts                            'Send START
        call #devadrw                           'Write to device address 0x77
        call #acks                              'Bit 9 ACK - End of write

        mov tmp, cal_addr                       'Calibration data starting register address 0x8a
        call #data_out                          'Write the data byte
        call #acks

        call #startr                            'Send repeated START
        call #devadrr                           'READ from device address 0x77
        call #acks                              'Bit 9 ACK

        call #read_in                           'Read the next data byte
        call #ackm
        mov cal_T2, data_byte                   'Move the contents of register 0x8a to cal_T2 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x8b to temp data
        shl tmp, #8
        or cal_T2, tmp                          'Move the upper byte into cal_T2 parameter

        call #read_in
        call #ackm
        mov cal_T3, data_byte                   'Move the contents of register 0x8c to cal_T3 parameter

        call #read_in                           '0x8d is unused in this burst read
        call #ackm

        call #read_in
        call #ackm
        mov cal_P1, data_byte                   'Move the contents of register 0x8e to cal_P1 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x8f to temp data
        shl tmp, #8
        or cal_P1, tmp                          'Move the upper byte into cal_P1 parameter

        call #read_in
        call #ackm
        mov cal_P2, data_byte                   'Move the contents of register 0x90 to cal_P2 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x91 to temp data
        shl tmp, #8
        or cal_P2, tmp                          'Move the upper byte into cal_P2 parameter

        call #read_in
        call #ackm
        mov cal_P3, data_byte                   'Move the contents of register 0x92 to cal_P3 parameter

        call #read_in                           '0x93 is unused in this burst read
        call #ackm

        call #read_in
        call #ackm
        mov cal_P4, data_byte                   'Move the contents of register 0x94 to cal_P4 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x95 to temp data
        shl tmp, #8
        or cal_P4, tmp                          'Move the upper byte into cal_P4 parameter

        call #read_in
        call #ackm
        mov cal_P5, data_byte                   'Move the contents of register 0x96 to cal_P5 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x97 to temp data
        shl tmp, #8
        or cal_P5, tmp                          'Move the upper byte into cal_P5 parameter

        call #read_in
        call #ackm
        mov cal_P7, data_byte                   'Move the contents of register 0x98 to cal_P7 parameter

        call #read_in
        call #ackm
        mov cal_P6, data_byte                   'Move the contents of register 0x99 to cal_P6 parameter

        call #read_in                           '0x9a is unused in this burst read
        call #ackm

        call #read_in                           '0x9b is unused in this burst read
        call #ackm

        call #read_in
        call #ackm
        mov cal_P8, data_byte                   'Move the contents of register 0x9c to cal_P8 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x9d to temp data
        shl tmp, #8
        or cal_P8, tmp                          'Move the upper byte into cal_P8 parameter

        call #read_in
        call #ackm
        mov cal_P9, data_byte                   'Move the contents of register 0x9e to cal_P9 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x9f to temp data
        shl tmp, #8
        or cal_P9, tmp                          'Move the upper byte into cal_P9 parameter

        call #read_in
        call #nackm
        call #stops
        call #Tbuf
        mov cal_P10, data_byte                 'Move the contents of register 0xa0 to temp data

        {*******Get the humidity calibration data starting at $E1******}

        call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, calH_addr                      'Remaining Calibration data for humidity at 0xE1
        call #data_out
        call #acks

        call #startr
        call #devadrr
        call #acks

        call #read_in                           'Read address 0xe1
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0xe1
        shl tmp, #8
        or cal_H2, tmp                          'Move the upper byte into cal_H2 parameter

        call #read_in                           'Read address e2
        call #ackm
        and data_byte, #$F0
        or cal_H2, data_byte                    'Move bits <7:4> into cal_H2 lower byte
        mov cal_H1, data_byte                   'Move bits <7:4> into cal_H1 lower byte

        call #read_in                           'Read address e3
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0xe3 to temp data
        shl tmp, #8
        or cal_H1, tmp                          'Move the upper byte into cal_H1 parameter

        call #read_in                           'Read e4
        call #ackm
        mov cal_H3, data_byte                   'Move contents of register 0xe4 to cal_H3

        call #read_in                           'Read e5
        call #ackm
        mov cal_H4, data_byte                   'Move contents of register 0xe5 to cal_H4

        call #read_in                           'Read e6
        call #ackm
        mov cal_H5, data_byte                   'Move contents of register 0xe6 to cal_H5

        call #read_in                           'Read e7
        call #ackm
        mov cal_H6, data_byte                   'Move contents of register 0xe7 to cal_H6

        call #read_in                           'Read e8
        call #ackm
        mov cal_H7, data_byte                   'Move contents of register 0xe8 to cal_H7

        call #read_in                           'Read e9
        call #ackm
        mov cal_T1, data_byte                   'Move contents of register 0xe9 to cal_T1

        call #read_in                           'Read address 0xea
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0xea to msb
        shl tmp, #8
        or cal_T1, tmp                          'Move the upper byte into cal_T1 parameter

        call #nackm
        call #stops
        call #Tbuf

{********************* Move the calibration data to shared memory ***************}

        mov shared_mem, par
        wrlong cal_T1, shared_mem

        add shared_mem, #4
        wrlong cal_T2, shared_mem

        add shared_mem, #4
        wrlong cal_T3, shared_mem

        add shared_mem, #4
        wrlong cal_P1, shared_mem

        add shared_mem, #4
        wrlong cal_P2, shared_mem

        add shared_mem, #4
        wrlong cal_P3, shared_mem

        add shared_mem, #4
        wrlong cal_P4, shared_mem

        add shared_mem, #4
        wrlong cal_P5, shared_mem

        add shared_mem, #4
        wrlong cal_P6, shared_mem

        add shared_mem, #4
        wrlong cal_P7, shared_mem

        add shared_mem, #4
        wrlong cal_P8, shared_mem

        add shared_mem, #4
        wrlong cal_P9, shared_mem

        add shared_mem, #4
        wrlong cal_P10, shared_mem

        add shared_mem, #4
        wrlong cal_H1, shared_mem

        add shared_mem, #4
        wrlong cal_H2, shared_mem

        add shared_mem, #4
        wrlong cal_H3, shared_mem

        add shared_mem, #4
        wrlong cal_H4, shared_mem

        add shared_mem, #4
        wrlong cal_H5, shared_mem

        add shared_mem, #4
        wrlong cal_H6, shared_mem

        add shared_mem, #4
        wrlong cal_H7, shared_mem

        mov time, cnt
        mov delay, sfreq/10
        add time, delay
        waitcnt time, 0

{***************************Data and subroutine section***********************}

starts  or dira, data_pin                       'Set data pin to output
        or outa, data_pin                       'Set SDA HIGH
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        call #ThdSa                             'ThdSta
        andn outa, data_pin                     'Set SDA
        call #ThdSa                             'ThdSta is same value as ThdSa delay
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
starts_ret     ret

startr  or dira, data_pin                       'Set data pin to output
        call #ThdSr                             'ThdSr
        or outa, data_pin                       'Set SDA HIGH
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        call #ThdSr                             'TsuSr
        andn outa, data_pin                     'Set SDA
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
startr_ret     ret

acks    andn dira, data_pin                     'set SDA to input
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        or dira, data_pin                       'Set SDA to output
acks_ret      ret

ackm    or dira, data_pin                       'ACKM - Set SDA to output
        andn outa, data_pin                     'Set SDA LOW
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
ackm_ret      ret

nackm   or dira, data_pin                       'ACKM - Set SDA to output
        or outa, data_pin                       'Set SDA LOW
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'Set SDA LOW
nackm_ret     ret

stops   or dira, data_pin                       'Set data pin to output
        andn outa, data_pin                     'Set SDA LOW
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        call #Tsu                               'TsuSto
        or outa, data_pin                       'Set SDA HIGH - STOP
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'Set SDA LOW
stops_ret     ret

devadrw mov counter, #8                         'Address %1110_1110 for device address 0x77 WRITE
        mov tmp, dev_adr_w                      'Copy the device address to tmp -> MSB first out

dev_w   test tmp, #1 wz                         'Test bit 1 and set wz
  if_nz or outa, data_pin                       'If bit 1 is not zero set data pin high
        call #TsuDat                            'TsuDat
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'Set SDA LOW
        shr tmp, #1                             'Shift tmp address register right 1 bit
        djnz counter, #dev_w                    'Check for end of byte
devadrw_ret    ret

devadrr mov counter, #8                         'Address %1110_1111 for device address 0x77 READ
        mov tmp, dev_adr_r                      'Copy the device address

devadr  test tmp, #1 wz
  if_nz or outa, data_pin                       'Send device address
        call #TsuDat                            'TsuDat
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'set SDA low
        shr tmp, #1                             'Shift tmp address register right 1 bit
        djnz counter, #devadr                   'Check for end of byte
devadrr_ret   ret

read_in mov data_byte, #0                       'Initialize the data destination byte
        mov counter, #8                         'Byte length
        andn dira, data_pin                     'Set data_pin to input

read    waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        mov tmp, ina                            'Read SDA pin
        test tmp, data_pin wz                   'Test bit read
  if_nz add data_byte, #1                       'Set bit
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        cmp counter, #1 wz                      'Check for end of byte
  if_nz shl data_byte, #1                       'Shift left if not end of byte
        djnz counter, #read                     'Loop back for next bit read or return
read_in_ret   ret

data_out mov counter, #8                        'Set bit counter to byte size

datadrw test tmp, #1 wz                         'Test bit 1 and set wz
  if_nz or outa, data_pin                       'If bit 0 = 1 set Data Pin HIGH
        shr tmp, #1                             'Shift tmp address register right 1 bit
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'Set data pin LOW
        djnz counter, #datadrw                  'Check for end of byte
data_out_ret   ret

Tsu     mov time, cnt                           'Get current system clock time
        add time, Tsu_mem                       'Add 48 ticks to current time
        waitcnt time, Tsu_mem                   'Wait 48 clock ticks
Tsu_ret   ret

ThdSr   mov time, cnt                           'Get current system clock time (This delay is used for TsuSta)
        add time, ThdSr_mem                     'Add n ticks to current time
        waitcnt time, ThdSr_mem                 'Wait n clock ticks (See CON seetings for tick count)
ThdSr_ret ret

ThdSa   mov time, cnt                           'Get current system clock time (This delay is used for TsuSta)
        add time, ThdSa_mem                     'Add n ticks to current time
        waitcnt time, ThdSa_mem                 'Wait n clock ticks (See CON seetings for tick count)
ThdSa_ret ret

Tbuf    mov time, cnt                           'Get current system clock time
        add time, Tbuf_mem                      'Add 104 ticks to current time + 4 buffer
        waitcnt time, Tbuf_mem                  'Wait 104 clock ticks + 4 buffer
Tbuf_ret   ret

TsuDat  mov time, cnt                           'Get current system clock time
        add time, TsuDat_mem                    'Add 10 ticks to current time
        waitcnt time, TsuDat_mem                'Wait 10 clock ticks
TsuDat_ret ret

clk_pin       long  |<SCL_pin
data_pin      long  |<SDA_pin
sfreq         long  0
tmp           long  0
counter       long  0
dev_adr_reset long  %0000_0111                  '0xe0 reset address
dev_reset     long  %0110_1101                  '0xb6 reset command
dev_adr_w     long  %0111_0111                  '0x77 with r/w bit = 0 (write)
dev_adr_r     long  %1111_0111                  '0x77 with r/w bit = 1 (read)
dev_adr_id    long  %0000_1011                  '0xd0 id address
cal_addr      long  %0101_0001                  'Calibration data starting register address 0x8a
calH_addr     long  %1000_0111                  'Calibration data for the remaining humidity 0xE1
cid           long  0
id_data       long  0
data_byte     long  0
time          long  0
delay         long  0
Tbuf_mem      long  T_buf
Tsu_mem       long  T_su
ThdSr_mem     long  T_hdSr
ThdSa_mem     long  T_hdSa
TsuDat_mem    long  T_suDat
cal_T1       long  0
cal_T2       long  0
cal_T3       long  0
cal_P1       long  0
cal_P2       long  0
cal_P3       long  0
cal_P4       long  0
cal_P5       long  0
cal_P6       long  0
cal_P7       long  0
cal_P8       long  0
cal_P9       long  0
cal_P10      long  0
cal_H1       long  0
cal_H2       long  0
cal_H3       long  0
cal_H4       long  0
cal_H5       long  0
cal_H6       long  0
cal_H7       long  0
shared_mem   long  0[20]
fit