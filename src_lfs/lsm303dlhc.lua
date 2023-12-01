--------------------------------------------------------------------
--
-- nodes@home/luaNodes/lsm303dlhcm
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 09.04.2023

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local i2ctool = require ( "i2ctool" );

--------------------------------------------------------------------
-- settings

local DEVICE_ADDRESS_ACCELERATION  = 0x18; -- only first 7 Bits relevant! --> 0x32 / 2
local DEVICE_ADDRESS_MAGNETICFIELD = 0x1E; -- only first 7 Bits relevant! --> 0x3C / 2

--------------------------------------------------------------------
-- public vars

-- https://github.com/pololu/lsm303-arduino/blob/master/LSM303.h
M.REG = {
    -- acceleration
--    CTRL_REG1_A       = 0x20, -- [7:4] ODR, [3] LPen, [2] Zen, [1] Yen, [0] Xen, ODR=0000 (default): power down
--    CTRL_REG2_A       = 0x21,
--    CTRL_REG3_A       = 0x22,
--    CTRL_REG4_A       = 0x23,
--    CTRL_REG5_A       = 0x24,
--    CTRL_REG6_A       = 0x25,
--    REFERENCE_A       = 0x26,
--    STATUS_REG_A      = 0x27,
--
--    OUT_X_L_A         = 0x28,
--    OUT_X_H_A         = 0x29,
--    OUT_Y_L_A         = 0x2A,
--    OUT_Y_H_A         = 0x2B,
--    OUT_Z_L_A         = 0x2C,
--    OUT_Z_H_A         = 0x2D,
--
--    FIFO_CTRL_REG_A   = 0x2E,
--    FIFO_SRC_REG_A    = 0x2F,
--
--    INT1_CFG_A        = 0x30,
--    INT1_SRC_A        = 0x31,
--    INT1_THS_A        = 0x32,
--    INT1_DURATION_A   = 0x33,
--    INT2_CFG_A        = 0x34,
--    INT2_SRC_A        = 0x35,
--    INT2_THS_A        = 0x36,
--    INT2_DURATION_A   = 0x37,
--
--    CLICK_CFG_A       = 0x38,
--    CLICK_SRC_A       = 0x39,
--    CLICK_THS_A       = 0x3A,
--    TIME_LIMIT_A      = 0x3B,
--    TIME_LATENCY_A    = 0x3C,
--    TIME_WINDOW_A     = 0x3D,

    -- magnetic fields
    CRA_REG_M         = 0x00, -- [7] TEMP_EN, [6:5] 0, [4:2] DO, [1:0] 0,   DO (data output rate) default = 0x100 = 15Hz
    CRB_REG_M         = 0x01, -- [7:5] GN, [4:0] 0,                         GN (gain configuration)
    MR_REG_M          = 0x02, -- [7:2] 0, [1:0] MD                          MD (mode select)

    OUT_X_H_M         = 0x03,
    OUT_X_L_M         = 0x04,
    OUT_Y_H_M         = 0x05,
    OUT_Y_L_M         = 0x06,
    OUT_Z_H_M         = 0x07,
    OUT_Z_L_M         = 0x08,

    SR_REG_M          = 0x09, -- [1] LOCK, [0] DRDY                         LOCK (data output register lock), DRDY (data ready)
    IRA_REG_M         = 0x0A, -- 0100 1000
    IRB_REG_M         = 0x0B, -- 0011 0100
    IRC_REG_M         = 0x0C, -- 0011 0011

    TEMP_OUT_H_M      = 0x31, -- [7:0] TEMP[11:4]
    TEMP_OUT_L_M      = 0x32, -- [7:4] TEMP[3:0], [3:0] unused

};

--------------------------------------------------------------------
-- private

local DEFAULT = {
    --[M.REG.CRA_REG_M]   = 0x80,         -- 1000 0000 - temp sensor enabled, 0.75 Hz data output rate
    --[M.REG.CRA_REG_M]   = 0x88,         -- 1000 1000 - temp sensor enabled, 3 Hz data output rate
    [M.REG.CRA_REG_M]   = 0x88,         -- 1000 0000 - temp sensor enabled, 0.75 Hz data output rate
    [M.REG.CRB_REG_M]   = 0xE0,         -- 1110 0000 - gain, sensor input field range +-8.1 gauss
    --[M.REG.MR_REG_M]    = 0x00,         -- continous conversion mode
};

--------------------------------------------------------------------
-- public
--
local function getField ( data, index )

    --assert ( data, "data is undefined" );
    --assert ( type ( data ) == "string", "data isnt string" );
    --assert ( index, "index is undefined" );
    --assert ( type ( index ) == "number", "data isnt number" );

    local result = 256 * string.byte ( data,  index ) + string.byte ( data,  index + 1 );

    return result;

end

function M.readTemperature ()

    local temp_data = i2ctool.readBytes ( M.REG.TEMP_OUT_H_M, 2 );
    local t = getField ( temp_data, 1 ) / 16;

    logger:debug ( string.format ( "readTemperature: t=%.1f", t ) );

    return t;

end

function M.readMagneticField ()

  local data = i2ctool.readBytes ( M.REG.OUT_X_H_M, 7 );

  local mx = getField ( data, 1 );
  local my = getField ( data, 3 );
  local mz = getField ( data, 5 );

  logger:debug ( string.format ( "readMagneticField: mx=%d my=%d mz=%d", mx, my, mz ) );

  return mx, my, mz;

end

function M.init ( sda, scl )

    logger:debug ( "init: sda=" .. sda .. " scl=" .. scl )

    local speed = i2ctool.init ( DEVICE_ADDRESS_MAGNETICFIELD, sda, scl, DEFAULT ); -- 100 kHz
    logger:debug ( "init: speed=" .. speed );

end

--------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

--------------------------------------------------------------------
