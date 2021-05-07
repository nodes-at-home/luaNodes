--------------------------------------------------------------------
--
-- nodes@home/luaNodes/apds9960
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 22.10.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

--------------------------------------------------------------------
-- settings

local DEVICE_ADDRESS = 0x39;

--------------------------------------------------------------------
-- public vars

--M.ENABLE_BITS = {"reserved", "GEN", "PIEN", "AIEN", "WEN", "PEN", "AEN", "PON" };
--M.STATUS_BITS = { "CPSAT", "PGSAT", "PINT", "AINT", "reserved", "GINT", "PVALID", "AVALID" };

-- APDS-9960 register addresses                                                         reset value
-- 0x00 .. 0x7F -> RAM                                                                  0x00
M.REG = {
    ENABLE         = 0x80;     -- rw   enable states and interrupts                0x00
    ATIME          = 0x81;     -- rw   adc integration time                        0xFF
    WTIME          = 0x83;     -- rw   wait time (non-gesture)                     0xFF
    AILTL          = 0x84;     -- rw   als interrupt low threshold low byte        --
    AILTH          = 0x85;     -- rw   als interrupt low threshold high byte       --
    AIHTL          = 0x86;     -- rw   als interrupt high threshold low byte       0x00
    AIHTH          = 0x87;     -- rw   als interrupt high threshold high byte      0x00
    PILT           = 0x89;     -- rw   proximity interrupt low threshold           0x00
    PIHT           = 0x8B;     -- rw   proximity interrupt high threshold          0x00
    PERS           = 0x8C;     -- rw   interrupt persistence filter (non gesture)  0x00
    CONFIG1        = 0x8D;     -- rw   configuration register one                  0x40
    PPULSE         = 0x8E;     -- rw   proximity pulse count and length            0x40
    CONTROL        = 0x8F;     -- rw   gain control                                0x00
    CONFIG2        = 0x90;     -- rw   configuration register two                  0x01
    ID             = 0x92;     -- r    devie id                                    ID
    STATUS         = 0x93;     -- r    device status                               0c00
    CDATAL         = 0x94;
    CDATAH         = 0x95;
    RDATAL         = 0x96;
    RDATAH         = 0x97;
    GDATAL         = 0x98;
    GDATAH         = 0x99;
    BDATAL         = 0x9A;
    BDATAH         = 0x9B;
    PDATA          = 0x9C;
    POFFSET_UR     = 0x9D;
    POFFSET_DL     = 0x9E;
    CONFIG3        = 0x9F;
    GPENTH         = 0xA0;
    GEXTH          = 0xA1;
    GCONF1         = 0xA2;
    GCONF2         = 0xA3;
    GOFFSET_U      = 0xA4;
    GOFFSET_D      = 0xA5;
    GOFFSET_L      = 0xA7;
    GOFFSET_R      = 0xA9;
    GPULSE         = 0xA6;
    GCONF3         = 0xAA;
    GCONF4         = 0xAB;
    GFLVL          = 0xAE;
    GSTATUS        = 0xAF;
    IFORCE         = 0xE4;
    PICLEAR        = 0xE5;
    CICLEAR        = 0xE6;
    AICLEAR        = 0xE7;
    GFIFO_U        = 0xFC;
    GFIFO_D        = 0xFD;
    GFIFO_L        = 0xFE;
    GFIFO_R        = 0xFF;
};

-- LED Drive values
--M.LED_DRIVE_100MA         = 0;
--M.LED_DRIVE_50MA          = 1;
--M.LED_DRIVE_25MA          = 2;
--M.LED_DRIVE_12_5MA        = 3;

-- Proximity Gain (PGAIN) values
--M.PGAIN_1X                = 0;
--M.PGAIN_2X                = 1;
--M.PGAIN_4X                = 2;
--M.PGAIN_8X                = 3;

-- ALS Gain (AGAIN) values
--M.AGAIN_1X                = 0;
--M.AGAIN_4X                = 1;
--M.AGAIN_16X               = 2;
--M.AGAIN_64X               = 3;

-- Gesture Gain (GGAIN) values
--M.GGAIN_1X                = 0;
--M.GGAIN_2X                = 1;
--M.GGAIN_4X                = 2;
--M.GGAIN_8X                = 3;

-- LED Boost values
--M.LED_BOOST_100           = 0;
--M.LED_BOOST_150           = 1;
--M.LED_BOOST_200           = 2;
--M.LED_BOOST_300           = 3;

-- Gesture wait time values
--M.GWTIME_0MS              = 0;
--M.GWTIME_2_8MS            = 1;
--M.GWTIME_5_6MS            = 2;
--M.GWTIME_8_4MS            = 3;
--M.GWTIME_14_0MS           = 4;
--M.GWTIME_22_4MS           = 5;
--M.GWTIME_30_8MS           = 6;
--M.GWTIME_39_2MS           = 7;

--------------------------------------------------------------------
-- private

local DEFAULT = {
    [M.REG.ENABLE]       = 0,        -- reset all features and interrupts
    [M.REG.ATIME]        = 219,      -- ALS integration time, power up default 0xFF, 219 -> 103ms
    [M.REG.WTIME]        = 0xFF,      -- power up default 0xFF: 2.78ms, wait time between proximity and ALS
    [M.REG.AILTL]        = 0,        -- ALS interrupt low threshold, low byte
    [M.REG.AILTH]        = 0,        -- ALS interrupt low threshold, high byte
    [M.REG.AIHTL]        = 0xFF,     -- ALS interrupt high threshold, low byte
    [M.REG.AIHTH]        = 0xFF,     -- ALS interrupt high threshold, high byte
    [M.REG.PILT]         = 0,        -- proximity interrupt low threshold
    [M.REG.PIHT]         = 20,       -- proximity interrupt high threshold
    [M.REG.PERS]         = 0x11,     -- any value outside thresholds generates an interrupt
    [M.REG.CONFIG1]      = 0x60,     -- No 12x wait (WTIME) factor
    [M.REG.PPULSE]       = 0x87,     -- PPLEN<7:6>=2: 16us, PPULSE<5:0>=7: 8 pulses
    [M.REG.CONTROL]      = 0x05,     -- led drive 100mA, proximity gain 4x, ALS gain 4x
    [M.REG.CONFIG2]      = 0x01,     -- No saturation interrupts or LED boost
    [M.REG.POFFSET_UR]   = 0,
    [M.REG.POFFSET_DL]   = 0,
    [M.REG.CONFIG3]      = 0,        -- Enable all photodiodes, no SAI
    [M.REG.GPENTH]       = 40,       -- Threshold for entering gesture mode
    [M.REG.GEXTH]        = 30,       -- Threshold for exiting gesture mode
    [M.REG.GCONF1]       = 0x40,     -- 4 gesture events for interrupt, no diode mask, 1 event for exit
    [M.REG.GCONF2]       = 0x47,     -- gesture gain 4x, led drive 100mA, gesture wait time 7*2.8ms
    [M.REG.GOFFSET_U]    = 0,        -- No offset scaling for gesture mode
    [M.REG.GOFFSET_D]    = 0,        -- No offset scaling for gesture mode
    [M.REG.GOFFSET_L]    = 0,        -- No offset scaling for gesture mode
    [M.REG.GOFFSET_R]    = 0,        -- No offset scaling for gesture mode
    [M.REG.GPULSE]       = 0xC9,     -- 32us, 10 pulses
    [M.REG.GCONF3]       = 0,        -- sll photodiodes active during gesture
    [M.REG.GCONF4]       = 0,        -- reset gesture interrupt and gesture mode
};

-------------------------------------------------------------------------------
-- public functions

function M.init ( sda, scl )

    logger.debug ( "init: sda=" .. sda .. " scl=" .. scl .. " verbose=" .. tostring ( verbose ) )

    local speed = i2ctool.init ( DEVICE_ADDRESS, sda, scl, DEFAULT, verbose ); -- 100 kHz
    logger.debug ( "init: speed=" .. speed );

end

--------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

--------------------------------------------------------------------
