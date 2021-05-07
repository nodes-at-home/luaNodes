--------------------------------------------------------------------
--
-- nodes@home/luaNodes/mpu5060
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 26.11.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local i2ctool = require ( "i2ctool" );

--------------------------------------------------------------------
-- settings

local DEVICE_ADDRESS = 0x68;

--------------------------------------------------------------------
-- public vars

M.INT_BITS = { "reserved", "reserved", "reserved", "FIFO_OFLOW", "I2C_MST", "reserved", "reserved", "DATA_RDY" };

M.REG = {
--    XG_OFFS_TC       = 0x00,     --[7] PWR_MODE, [6:1] XG_OFFS_TC, [0] OTP_BNK_VLD
--    YG_OFFS_TC       = 0x01,     --[7] PWR_MODE, [6:1] YG_OFFS_TC, [0] OTP_BNK_VLD
--    ZG_OFFS_TC       = 0x02,     --[7] PWR_MODE, [6:1] ZG_OFFS_TC, [0] OTP_BNK_VLD
--    X_FINE_GAIN      = 0x03,     --[7:0] X_FINE_GAIN
--    Y_FINE_GAIN      = 0x04,     --[7:0] Y_FINE_GAIN
--    Z_FINE_GAIN      = 0x05,     --[7:0] Z_FINE_GAIN
--    XA_OFFS_H        = 0x06,                --[15:0] XA_OFFS
--    XA_OFFS_L        = 0x07,
--    YA_OFFS_H        = 0x08,                --[15:0] YA_OFFS
--    YA_OFFS_L        = 0x09,
--    ZA_OFFS_H        = 0x0A,                --[15:0] ZA_OFFS
--    ZA_OFFS_L        = 0x0B,
--    XG_OFFS_H        = 0x13,                --[15:0] XG_OFFS_USR
--    XG_OFFS_L        = 0x14,
--    YG_OFFS_H        = 0x15,                --[15:0] YG_OFFS_USR
--    YG_OFFS_L        = 0x16,
--    ZG_OFFS_H        = 0x17,                --[15:0] ZG_OFFS_USR
--    ZG_OFFS_L        = 0x18,

    SMPLRT_DIV       = 0x19,                -- 25
    CONFIG           = 0x1A,                -- 26
    GYRO_CONFIG      = 0x1B,                -- 27
    ACCEL_CONFIG     = 0x1C,                -- 28
--    FF_THR           = 0x1D,
--    FF_DUR           = 0x1E,
--    MOT_THR          = 0x1F,
--    MOT_DUR          = 0x20,
--    ZRMOT_THR        = 0x21,
--    ZRMOT_DUR        = 0x22,
--    FIFO_EN          = 0x23,
--    I2C_MST_CTRL     = 0x24,
--    I2C_SLV0_ADDR    = 0x25,
--    I2C_SLV0_REG     = 0x26,
--    I2C_SLV0_CTRL    = 0x27,
--    I2C_SLV1_ADDR    = 0x28,
--    I2C_SLV1_REG     = 0x29,
--    I2C_SLV1_CTRL    = 0x2A,
--    I2C_SLV2_ADDR    = 0x2B,
--    I2C_SLV2_REG     = 0x2C,
--    I2C_SLV2_CTRL    = 0x2D,
--    I2C_SLV3_ADDR    = 0x2E,
--    I2C_SLV3_REG     = 0x2F,
--    I2C_SLV3_CTRL    = 0x30,
--    I2C_SLV4_ADDR    = 0x31,
--    I2C_SLV4_REG     = 0x32,
--    I2C_SLV4_DO      = 0x33,
--    I2C_SLV4_CTRL    = 0x34,
--    I2C_SLV4_DI      = 0x35,
--    I2C_MST_STATUS   = 0x36,
    INT_PIN_CFG      = 0x37,                    -- 55
    INT_ENABLE       = 0x38,                    -- 56
--    DMP_INT_STATUS   = 0x39,
    INT_STATUS       = 0x3A,                    -- 58
    ACCEL_XOUT_H     = 0x3B,                    -- 59
--    ACCEL_XOUT_L     = 0x3C,
--    ACCEL_YOUT_H     = 0x3D,
--    ACCEL_YOUT_L     = 0x3E,
--    ACCEL_ZOUT_H     = 0x3F,
--    ACCEL_ZOUT_L     = 0x40,
    TEMP_OUT_H       = 0x41,                    -- 65
--    TEMP_OUT_L       = 0x42,
--    GYRO_XOUT_H      = 0x43,
--    GYRO_XOUT_L      = 0x44,
--    GYRO_YOUT_H      = 0x45,
--    GYRO_YOUT_L      = 0x46,
--    GYRO_ZOUT_H      = 0x47,
--    GYRO_ZOUT_L      = 0x48,
--    EXT_SENS_DATA_00 = 0x49,
--    EXT_SENS_DATA_01 = 0x4A,
--    EXT_SENS_DATA_02 = 0x4B,
--    EXT_SENS_DATA_03 = 0x4C,
--    EXT_SENS_DATA_04 = 0x4D,
--    EXT_SENS_DATA_05 = 0x4E,
--    EXT_SENS_DATA_06 = 0x4F,
--    EXT_SENS_DATA_07 = 0x50,
--    EXT_SENS_DATA_08 = 0x51,
--    EXT_SENS_DATA_09 = 0x52,
--    EXT_SENS_DATA_10 = 0x53,
--    EXT_SENS_DATA_11 = 0x54,
--    EXT_SENS_DATA_12 = 0x55,
--    EXT_SENS_DATA_13 = 0x56,
--    EXT_SENS_DATA_14 = 0x57,
--    EXT_SENS_DATA_15 = 0x58,
--    EXT_SENS_DATA_16 = 0x59,
--    EXT_SENS_DATA_17 = 0x5A,
--    EXT_SENS_DATA_18 = 0x5B,
--    EXT_SENS_DATA_19 = 0x5C,
--    EXT_SENS_DATA_20 = 0x5D,
--    EXT_SENS_DATA_21 = 0x5E,
--    EXT_SENS_DATA_22 = 0x5F,
--    EXT_SENS_DATA_23 = 0x60,
--    MOT_DETECT_STATUS = 0x61,
--    I2C_SLV0_DO      = 0x63,
--    I2C_SLV1_DO      = 0x64,
--    I2C_SLV2_DO      = 0x65,
--    I2C_SLV3_DO      = 0x66,
--    I2C_MST_DELAY_CTRL = 0x67,
--    SIGNAL_PATH_RESET = 0x68,
--    MOT_DETECT_CTRL  = 0x69,
--    USER_CTRL        = 0x6A,
    PWR_MGMT_1       = 0x6B,                -- 107
    PWR_MGMT_2       = 0x6C,                -- 108
--    BANK_SEL         = 0x6D,
--    MEM_START_ADDR   = 0x6E,
--    MEM_R_W          = 0x6F,
--    DMP_CFG_1        = 0x70,
--    DMP_CFG_2        = 0x71,
--    FIFO_COUNTH      = 0x72,
--    FIFO_COUNTL      = 0x73,
--    FIFO_R_W         = 0x74,
    WHO_AM_I         = 0x75,                -- 117
};

--------------------------------------------------------------------
-- private

--local DEFAULT = {
--    --[M.REG.ENABLE]       = 0,        -- reset all features and interrupts
--};

--------------------------------------------------------------------
-- public
--
function M.readAcceleration ()

    local function getField ( data, index )
--        assert ( data, "data is undefined" );
--        assert ( type ( data ) == "string", "data isnt string" );
--        assert ( index, "index is undefined" );
--        assert ( type ( index ) == "number", "data isnt number" );
        local result = 256 * string.byte ( data,  index ) + string.byte ( data,  index + 1 );
        if ( result > 0x7FFF ) then result = result - 0x10000 end
        return result;
    end

    local data = i2ctool.readBytes ( 59, 8 );

    local ax = getField ( data, 1 );
    local ay = getField ( data, 3 );
    local az = getField ( data, 5 );
    --logger.debug ( string.format ( "readAcceleration: Ax=%5d Ay=%5d Az=%5d", ax, ay, az ) );

    local t = getField ( data, 7 );
    local temp = 36.53 + t / 340;
    --logger.debug ( string.format ( "readAcceleration: temp=%.1f", temp ) );

    return ax, ay, az, temp;

end

function M.init ( sda, scl )

    logger.debug ( "init: sda=" .. sda .. " scl=" .. scl )

    local speed = i2ctool.init ( DEVICE_ADDRESS, sda, scl, nil ); -- 100 kHz
    logger.debug ( "init: speed=" .. speed );

--    for register, value in pairs ( DEFAULT ) do
--        M.writeByte ( register, value );
--    end

end

--------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

--------------------------------------------------------------------
