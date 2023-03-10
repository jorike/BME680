{BME680 low power pressure, temperature, and humidity sensor
 using the I2C Bus specification.

 Version 1
 ──────────────────────────────────────────┐
│ BME680                                   │
│ Author: James Rike and Jeff Martin                       │
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

  pres_ovf_check = $40000000

VAR
  long parT1, parT2, parT3
  long parP1, parP2, parP3, parP4, parP5, parP6, parP7, parP8, parP9, parP10
  long parH1, parH2, parH3, parH4, parH5, parH6, parH7
  long adc_T, adc_P, adc_H, adc_G
  long t_fine
  long semID
  byte cog

OBJ
  num   :       "Simple_Numbers"
  pst   :       "Parallax Serial Terminal"
  bme680Cal :   "BME680CalData"

PUB Start                       'Cog start method
  Stop
  bme680Cal.Start
  bme680Cal.getCalData(@parT1)
  if not semID := locknew       'Create new lock
    adc_T := semID
    cog := cognew(@_entry, @adc_T) + 1
    PrintData

PUB Stop                        'Cog stop method
    if cog
      lockret(semID)
      cogstop(cog~ - 1)

PRI PrintData  | T, H, P, tf

  pst.Start(115_200)
  pst.char(0)
  pst.str(string("*-----Initializing-----*"))

  repeat
    waitcnt(clkfreq*30+cnt)
    repeat until not lockset(semID)
    pst.char(0)
    pst.str(string("*-------------------*"))
    pst.NewLine
    pst.str(string("Temp: "))
    T := BME680_compensate_T
    pst.str(num.dec(T/100))
    pst.str(string("."))
    pst.str(num.dec(T//100))
    pst.str(string(" C"))
    pst.NewLine
    tf := gettempf(T)
    pst.str(string("      "))
    pst.str(num.dec(tf/100))
    pst.str(string("."))
    pst.str(num.dec(tf//100))
    pst.str(string(" F"))
    pst.NewLine
    pst.str(string("RH:   "))
    H := BME680_compensate_H(T)
    pst.str(num.dec(H/1000))
    pst.str(string("."))
    pst.str(num.decx(H//1000,2))
    pst.str(string(" %"))
    pst.NewLine
    pst.str(string("mBars: "))
    P := BME680_compensate_P
    pst.str(num.dec(P/100))
    pst.str(string("."))
    pst.str(num.dec(P//100))
    pst.str(string(" hPa"))
    pst.NewLine
    lockclr(semID)

PUB setCalData(calAdr)
  longmove(@parT1,calAdr,20)

PRI BME680_compensate_T :t | var1, var2, var3

var1 := (||adc_T ~> 3) - (||parT1 << 1)
var2 := (var1 * ~~parT2) ~> 11
var3 := (((var1 ~> 1) * (var1 ~> 1)) ~> 12) * (~parT3 << 4) ~> 14
t_fine := var2 + var3
t := (t_fine * 5 + 128) ~> 8
return ~~t

PRI bme680_compensate_H(temp_scaled) :h | var1, var2, var3, var4, var5, var6

var1 := (adc_H - (||parH1 * 16)) - (((temp_scaled * ~parH3) / 100) ~> 1)
var2 := (||parH2 * (((temp_scaled * ~parH4) / 100) + (((temp_scaled * ((temp_scaled * ~parH5) / 100)) ~> 6) / 100) + (1 << 14))) ~> 10
var3 := var1 * var2
var4 := ||parH6 << 7
var4 := (var4 + ((temp_scaled * ~parH7) / 100)) ~> 4
var5 := ((var3 ~> 14) * (var3 ~> 14)) ~> 10
var6 := (var4 * var5) ~> 1
h := ||((((var3 + var6) ~> 10) * 1000) ~> 16)

if ||h > 100000                 'Range check of 0% to 100%
  h := 100000
elseif h < 0
  h := 0

return ||h

PRI BME680_compensate_P :p | var1, var2, var3

var1 := (t_fine ~> 1) - 64000
var2 := ((((var1 ~> 2) * (var1 ~> 2)) ~> 11) * ~parP6) ~> 2
var2 := var2 + ((var1 * ~~parP5) << 1)
var2 := (var2 ~> 2) + (~~parP4 << 16)
var1 := (((((var1 ~> 2) * (var1 ~> 2)) ~> 13) * (~parP3 << 5)) ~> 3) + ((~~parP2 * var1) ~> 1)
var1 := var1 ~> 18
var1 := ((32768 + var1) * ||parP1) ~> 15
p := ||(1048576 - adc_P)
p := ||((||p - (var2 ~> 12)) * 3125)

if p => pres_ovf_check
  p := ((||p / ||var1) << 1)
else
  p := ((||p << 1) / ||var1)

var1 := (~~parP9 * (((||p >> 3) * (||p >> 3)) ~> 13)) ~> 12
var2 := ((||p >> 2) * ~~parP8) ~> 13
var3 := ((||p >> 8) * (||p >> 8) * (||p >> 8) * ~parP10) ~> 17
p := (||p + ((var1 + var2 + var3 + (~parP7 << 7)) ~> 4))

return ||p

PRI gettempf(t) | tf

  tf := t * 9 / 5 + 3200

  return tf

' Returns humidity in %RH as unsigned 32 bit integer in Q22.10 format (22 integer and 10 fractional bits).
' Output value of 47445 represents 47445 / 1024 = 46.333 %RH

PRI gethumidity(h) | th

  th := h
  return th

DAT
        org 0
_entry

        rdlong sfreq, #0

{************* Copy shared memory address and get the lock ID ************}

        mov shared_mem, par                     'Retrieve shared memory address
        rdlong lockID, shared_mem               'Get the lock from shared memory

{************************** Configure the sensor *************************}

sample  call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, ctl_hum                        'Register address: $72
        call #data_out
        call #acks

        mov tmp, ctl_hum_data                   'Set osrs_h <2:0> to 001 for 1x sampling
        call #data_out
        call #nackm
        call #stops
        call #Tbuf

        call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, ctl_meas                       'Control measurement configuration register address 0x74
        call #data_out
        call #acks

        mov tmp, ctl_meas_data                  'Set osrs_t to 010 osrs_p to 101 and forced mode off
        call #data_out
        call #acks

        mov tmp, config                         'Device configuration register address 0x75
        call #data_out
        call #acks

        mov tmp, config_data
        call #data_out
        call #nackm
        call #stops
        call #Tbuf

        call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, ctl_gas_wait                   'Control gas_wait_0 configuration register 0x64
        call #data_out
        call #acks

        mov tmp, gas_wait_data                  'Set gas wait to 100ms duration (4 x 25) 0x59
        call #data_out
        call #nackm
        call #stops
        call #Tbuf

        call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, res_heat                       'Control res_heat_0 configuration register 0x5a
        call #data_out
        call #acks

        mov tmp, res_heat_data                  'Write to register address: $5a
        call #data_out
        call #nackm
        call #stops
        call #Tbuf

        call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, cntl_gas_cfg                   'Control gas configuration register 0x70
        call #data_out
        call #acks

        mov tmp, heater_on                      'Heater off for early implementation
        call #data_out
        call #acks

        mov tmp, cntl_gas_cfg1                  'Control gas configuration register 0x71
        call #data_out
        call #acks

        mov tmp, run_gas                        'Run gas bit and nb_conv <3:0>
        call #data_out
        call #acks

        mov tmp, ctl_meas                       'Control measurement configuration register address 0x74
        call #data_out
        call #acks

        mov tmp, ctl_meas_data_on               'Set osrs_t to 010 osrs_p to 101 and forced mode off
        call #data_out
        call #nackm
        call #stops
        call #Tbuf

{*********************** Read the raw sensor data for P, T, and H ********************}

lockit  lockset lockID wr,wc                    'Check the lock & get the lock
   if_c jmp #lockit

        call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, tph_msb                        'Temp msb register address 0x1f for burst read
        call #data_out
        call #acks

        call #startr
        call #devadrr
        call #acks

        call #read_in
        call #ackm
        mov p_data, data_byte                   'Move the contents of register 0x1f MSB of pressure raw data
        shl p_data, #8                          'Make room for the next byte

        call #read_in
        call #ackm
        or p_data, data_byte                    'Move the contents of register 0x20
        shl p_data, #8                          'Make room for the first bit of the next byte

        call #read_in
        call #ackm
        or p_data, data_byte                    'Move the contents of register 0x21
        shr p_data, #4                          '20 bit format

        call #read_in
        call #ackm
        mov t_data, data_byte                   'Move the contents of register 0x22 MSB of temperature raw data
        shl t_data, #8                          'Make room for the next byte

        call #read_in
        call #ackm
        or t_data, data_byte                    'Move the contents of register 0x23
        shl t_data, #8                          'Make room for the first bit of the next byte

        call #read_in
        call #ackm
        or t_data, data_byte                    'Move the contents of register 0x24
        shr t_data, #4                          '20 bit format

        call #read_in
        call #ackm
        mov h_data, data_byte                   'Move the contents of register 0x25 MSB of humidity raw data
        shl h_data, #8                          'Make room for the LSB

        call #read_in
        call #ackm
        or h_data, data_byte                    'Move the contents of register 0x26

        call #read_in                           '0x27 is unused in this burst read
        call #ackm

        call #read_in                           '0x28 is unused in this burst read
        call #ackm

        call #read_in                           '0x29 is unused in this burst read
        call #ackm

        call #read_in
        call #ackm
        mov g_data, data_byte                   'Move the contents of register 0x2a MSB of gas raw data
        shl g_data, #8                          'Make room for the LSB

        call #read_in
        call #ackm
        call #stops
        call #Tbuf
        or g_data, data_byte                    'Move the contents of register 0x2b

        mov shared_mem, par                     'Retrieve shared memory address
        wrlong t_data, shared_mem

        add shared_mem, #4
        wrlong p_data, shared_mem

        add shared_mem, #4
        wrlong h_data, shared_mem

        add shared_mem, #4
        wrlong g_data, shared_mem

        lockclr lockID

        mov time, cnt
        mov delay, sfreq
        add time, delay
        waitcnt time, delay

        jmp #sample

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
ctl_meas      long  %0010_1110                  'Control measurement configuration register address 0x74
ctl_meas_data long  %0010_1010
ctl_meas_data_on long  %1010_1010
config        long  %1010_1110                  'Device configuration register address 0xF5
config_data   long  %0010_0000
ctl_hum       long  %0100_1110                  'Control humidity configuration register 0x72
ctl_hum_data  long  %1000_0000
ctl_gas_wait  long  %0010_0110                  'Control gas wait register 0x64
gas_wait_data long  %1001_1010
cntl_gas_cfg  long  %0000_1110
cntl_gas_cfg1 long  %1000_1110
heater_on     long  %0000_1000
run_gas       long  %0000_0000
tph_msb       long  %1111_1000                  'Temp msb register address 0x1f
res_heat      long  %0101_1010                  'Res heat address 0x5a
res_heat_data long  %1100_0000
data_byte     long  0
lockID        long  0
time          long  0
delay         long  0
Tbuf_mem      long  T_buf
Tsu_mem       long  T_su
ThdSr_mem     long  T_hdSr
ThdSa_mem     long  T_hdSa
TsuDat_mem    long  T_suDat
t_data        long  0
p_data        long  0
h_data        long  0
g_data        long  0
shared_mem    long  0[4]
fit

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}