{I2C Clock object on pin SCL_pin}


CON

  Tlow = 108
  Thigh = 90
  SCL_pin = 17

VAR
  long stack[10]                'Cog stack space
  byte cogclk

OBJ

PUB Start                       'Cog start method
    Stop
    cogclk := cognew(@_entry, @stack) + 1

PUB Stop                        'Cog stop method
    if cogclk
        cogstop(cogclk~ - 1)


DAT
        org 0
_entry


        rdlong sfreq, #0
        mov delay, cnt
        add delay, sfreq
        waitcnt delay, sfreq                    'Start delay of 1s

        or dira, clk_pin                        'Set clock pin to output

i2c_clk or outa, clk_pin
        call#highdlay
        andn outa, clk_pin
        call #lowdlay
        jmp #i2c_clk


highdlay mov time, cnt                          'Get current system clock time
        add time, t_high
        waitcnt time, t_high
highdlay_ret   ret

lowdlay mov time, cnt                           'Get current system clock time
        add time, t_low
        waitcnt time, t_low
lowdlay_ret   ret




clk_pin       long  |<SCL_pin
delay         long  0
t_high        long  Thigh
t_low         long  Tlow
time          long  0
sfreq         long  0
fit