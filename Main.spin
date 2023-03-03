{Top Object - Main BME280 sensor method}

CON
  _clkmode = xtal1 + pll16x         'Standard clock mode * crystal frequency = 80 MHz
  _xinfreq = 5_000_000

VAR

OBJ
  clockObj      : "i2cClock"
  CalDataObj    : "BME680CalData"
  bme680Obj     : "BME680"

PUB Main | clk_success, bme680_success, cal_success
  {Call the clock cog start method}
  clk_success := clockObj.Start
  {Call the bme680 cog start method}
  bme680_success := bme680Obj.Start