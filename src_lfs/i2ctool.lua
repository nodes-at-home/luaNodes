--------------------------------------------------------------------
--
-- nodes@home/luaNodes/i2ctool
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 05.11.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local device_mt = { -- basics for all i2c devices for __index metatable
    sda = 1,
    scl = 2,
    deviceAddress = 0x00,
    mode = "byte",
    logger = logger,
};

local i2c, bit = i2c, bit;

--------------------------------------------------------------------
-- settings

local ID = 0;

-------------------------------------------------------------------------------
-- i2c basics

function device_mt:readByte ( register )

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" )
    assert ( register, "register is undefined" );

    local logger = self.logger;
    local deviceAddress = self.deviceAddress;

    logger:debug ( "readByte: addr=" .. tohex ( deviceAddress )  .. " register=" .. tohex ( register ) );

    return string.byte ( self:readBytes ( register, 1 ), 1 );

end

function device_mt:readBytes ( register, len )

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" )
    assert ( register, "register is undefined" );
    assert ( len, "len is undefined" );

    local logger = self.logger;
    local deviceAddress = self.deviceAddress;

    logger:debug ( "readBytes: addr=" .. tohex ( deviceAddress ) .. " register=" .. tohex ( register ) .. " len=" .. len );

    i2c.start ( ID );
    local ackTransmit = i2c.address ( ID, deviceAddress, i2c.TRANSMITTER );
    logger:debug ( "readBytes: ack transmit=" .. tostring ( ackTransmit ) );
    local n = i2c.write ( ID, register );
    logger:debug ( "readBytes: n=" .. n );
    --i2c.stop ( ID );

    i2c.start ( ID );
    local ackReceive = i2c.address ( ID, deviceAddress, i2c.RECEIVER );
    logger:debug ( "readBytes: ack receive=" .. tostring ( ackReceive ) )
    local data = i2c.read ( ID, len );
    logger:debug ( "readBytes: #data=" .. string.len ( data ) .. " data=" .. table.concat ( { string.byte ( data, 1, #data ) }, ", " ) );
    i2c.stop ( ID );

    return data;

end

function device_mt:writeByte ( register, byte )

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" )
    assert ( register, "register is undefined" );
    assert ( byte, "byte is undefined" );

    local logger = self.logger;
    local deviceAddress = self.deviceAddress;

    logger:debug ( "writeByte: addr=" .. tohex ( deviceAddress )  .. " register=" .. tohex ( register ) .. " byte=" .. tohex ( byte ) )

    i2c.start ( ID );
    local ackTransmit = i2c.address ( ID, deviceAddress, i2c.TRANSMITTER );
    logger:debug ( "writeByte: ack transmit=" .. tostring ( ackTransmit ) );
    local n1 = i2c.write ( ID, register );
    logger:debug ( "writeByte: n1=" .. n1 );
    local n2 = i2c.write ( ID, byte );
    logger:debug ( "writeByte: n2=" .. n2 );
    i2c.stop ( ID );

end

function device_mt:writeBytes ( register, bytes )

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" )
    assert ( register, "register is undefined" );
    assert ( bytes, "bytes is undefined" );
    assert ( type ( bytes ) == "table", "bytes is not a table" );

    local logger = self.logger;
    local deviceAddress = self.deviceAddress;

    logger:debug ( "writeBytes: addr=" .. tohex ( deviceAddress )  .. " register=" .. tohex ( register ) .. " bytes=" .. table.concat ( bytes, ", " ) );

    i2c.start ( ID );
    local ackTransmit = i2c.address ( ID, deviceAddress, i2c.TRANSMITTER );
    logger:debug ( "writeBytes: ack transmit=" .. tostring ( ackTransmit ) );
    local n1 = i2c.write ( ID, register );
    logger:debug ( "writeBytes: n1=" .. n1 )
    local n2 = i2c.write ( ID, unpack ( bytes ) );
    logger:debug ( "writeBytes: n2=" .. n2 );
    i2c.stop ( ID );

end

function device_mt:setBit ( register, pos, value )

    if ( value == nil ) then value = 1; end

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" )
    assert ( register, "register is undefined" );
    assert ( pos, "pos is undefined" );
    assert ( value, "value is undefined" );

    local logger = self.logger;

    logger:debug ( "setBit: register=" .. tohex ( register ) .. " pos=" .. pos .. " value=" .. tohex ( value ) )

    local handleBit = value and bit.set or bit.clear;
    self:writeByte ( register, handleBit ( self:readByte ( register ), pos ) );

end

function device_mt:setBits ( register, highest, lowest, value )

    if ( value == nil ) then value = 1; end

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" )
    assert ( register, "register is undefined" );
    assert ( value, "value is undefined" );
    assert ( 8 >= highest and highest >= 0, "highest bit is outside (highest=" .. highest .. ")" );
    assert ( 8 >= lowest and lowest >= 0, "lowest bit is outside (lowest=" .. lowest .. ")" );
    assert ( highest >= lowest, "wrong order (highest=" .. highest .. ", lowest=" .. lowest ..")" );

    local logger = self.logger;

    logger:debug ( "setBits: register=" .. tohex ( register ) .. " highest=" .. highest .. " lowest=" .. lowest .. " value=" .. value );

    local old = self:readByte ( register );

    local mask = 0;
    for i = 0, highest - lowest do
        mask = bit.set ( mask, i );
    end

    local new = bit.bor ( bit.band ( old, bit.bxor ( bit.lshift ( mask, lowest ), 0xFF ) ), bit.lshift ( bit.band ( value, mask ), lowest ) );

    self:writeByte ( register, new );

end

function device_mt:readWord ( highByteReg, lowByteReg )

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" );
    assert ( highByteReg, "highByteReg is undefined" );
    assert ( lowByteReg, "lowByteReg is undefined" );

    local logger = self.logger;

    logger:debug ( "readWord: highByteReg=" .. tohex ( highByteReg ) .. " lowByteReg=" .. tohex ( lowByteReg ) );

    local highValue = self:readByte ( highByteReg );
    local lowValue = self:readByte ( lowByteReg );

    return 256 * highValue + lowValue;

end

function device_mt:writeWord ( highByteReg, lowByteReg, word )

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" );
    assert ( highByteReg, "highByteReg is undefined" );
    assert ( lowByteReg, "lowByteReg is undefined" );
    assert ( word, "word is undefined" );

    local logger = self.logger;

    logger:debug ( "writeWord: highByteReg=" .. tohex ( highByteReg ) .. " lowByteReg=" .. tohex ( lowByteReg ) .. " word=" .. word );

    local highValue = bit.rshift ( bit.band ( word, 0xFF00 ), 8 );
    local lowValue = bit.band ( word, 0x00FF );

    self:writeByte ( highByteReg, highValue );
    self:writeByte ( lowByteReg, lowValue );

end

function device_mt:readWordLSB ( register )

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" );
    assert ( register, "register is undefined" );

    local logger = self.logger;

    logger:debug ( "readWordLSB: register=" .. tohex ( register ) );

    local data = self:readBytes ( register, 2 ); -- data is a string of bytes

    return 256 * string.byte ( data, 2 ) + string.byte ( data, 1 );

end

function device_mt:writeWordLSB ( register, word )

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" );
    assert ( register, "register is undefined" );
    assert ( word, "word is undefined" );

    local logger = self.logger;

    logger:debug ( "writeWordLSB: Register=" .. tohex ( register ) .. " word=" .. tohex ( word, 4 ) );

    local highValue = bit.rshift ( bit.band ( word, 0xFF00 ), 8 );
    local lowValue = bit.band ( word, 0x00FF );

    self:writeBytes ( register, { lowValue, highValue } );

end

function device_mt:isBit ( register, pos )

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" );

    local logger = self.logger;

    logger:debug ( "isBit: register=" .. tohex ( register ) .. " pos=" .. pos );

    return bit.isset ( self:readByte ( register ), pos )

end

-------------------------------------------------------------------------------
-- debug

local function registerBits ( value, fields, full )

    local line = { "<" };

    if ( full == nil ) then full = false; end

    if ( full ) then
        for i = 7, 0, -1 do
            table.insert ( line, fields [8-i] );
            table.insert ( line, ":" );
            table.insert ( line, bit.isset ( value, i ) and "1" or "0" );
            if ( i > 0 ) then table.insert ( line, "," ); end
        end
    else
        local first = true;
        for i = 7, 0, -1 do
            if ( bit.isset ( value, i ) ) then
                if ( first ) then
                    first = false;
                else
                    table.insert ( line, "," );
                end
                table.insert ( line, fields [8-i] );
            end
        end
    end

    table.insert ( line, ">" );

    return ( table.concat ( line ) );

end
M.registerBits = registerBits;
device_mt.registerBits = registerBits;

-------------------------------------------------------------------------------
-- init

function device_mt:init ()

    assert ( self, "self is undefined" );
    assert ( getmetatable ( self ) and getmetatable ( self).__index and getmetatable ( self ).__index == device_mt, "no i2c device, __index metatable wrong" );

    local logger = self.logger;
    local deviceAddress = self.deviceAddress;

    local mode = self.mode;
    local defaults = self.DEFAULT;
    local sda = self.sda;
    local scl = self.scl;

    logger:debug ( "init: sda=" .. sda .. " scl=" .. scl .. " mode=" .. mode );

    local speed = i2c.setup ( ID, sda, scl, i2c.SLOW ); -- 100 kHz
    logger:debug ( "init: speed=" .. speed .. " addr=" .. tohex ( deviceAddress ) );

    if ( defaults and type ( defaults ) == "table" ) then
        for register, value in pairs ( defaults ) do
            if ( mode == "byte" ) then
                self:writeByte ( register, value );
            elseif ( mode == "wordlsb" ) then
                self:writeWordLSB ( register, value );
            end
        end
    end

    return speed;

end

--------------------------------------------------------------------
-- factory methode

local function createdevice ( name, address, sda, scl, registers, defaults )

    assert ( name, "name is undefinded" );
    assert ( type ( name ) == "string", "name is not a string" );
    assert ( address, "address is undefinded" );
    assert ( type ( address ) == "number", "address is not a number" );
    assert ( sda, "sda is undefinded" );
    assert ( type ( sda ) == "number", "sda is not a number" );
    assert ( scl, "scl is undefinded" );
    assert ( type ( scl ) == "number", "scl is not a number" );
    assert ( registers, "register is undefinded" );
    assert ( type ( registers ) == "table", "registers is not a table" );
    assert ( defaults, "defaults is undefinded" );
    assert ( type ( defaults ) == "table", "defaults is not a table" );

    if ( _G [name] ) then -- TODO maybe check also for sda and scl
        _G [name].logger:debug ( name .. ": return existing instance" );
        -- return the only one instance (solitare)
        return _G [name];
    end

    local device = { name = name, deviceAddress = address, sda = sda, scl = scl }; -- device object, if i2c communication is not byte based, use specific mode
    setmetatable ( device, { __index = device_mt } );
    _G [name] = device;

    local logger = require ( "syslog" ).logger ( moduleName .. "." .. name );
    device.logger = logger;

    logger:debug ( "createdevice: name=" .. name .. " address=" .. tohex ( address ) .. " sda=" .. sda .. " scl=" .. scl );

    device.REG = registers;     -- { REG1 = 0x00, -- explain bits }

    device.DEFAULT = defaults;  -- { [REG.REG1] = 0x0000, -- explain this config }

    local speed = device:init (); -- 100 kHz
    logger:debug ( "createdevice: speed=" .. speed );

    return device;

end

--------------------------------------------------------------------
-- veml7700

function M.veml7700 ( sda, scl )

    assert ( sda, "sda is undefined" );
    assert ( scl, "scl is undefined" );

    local DEVICE = "veml7700";
    local DEVICE_ADDRESS = 0x10;

    local REG = {

        ALS_CONF            = 0x00, -- [15:13] 0, [12:11] gain, [10] 0, [9:6] integration time, [5:4] persistince protect number, [3:2] 0, [1] interrupt enable, [0] shut down
        ALS_WH              = 0x01, -- high threshold
        ALS_WL              = 0x02, -- low threshold
        POWER_SAVING        = 0x03, -- [15:3] 0, [2:1] power saving mode, [0] enable
        ALS                 = 0x04, -- ambient light sensor data
        WHITE               = 0x05, -- white channel data
        ALS_INT             = 0x06, -- [15] int_th_low, [14] int_th_high, [13:0] reserved
        ID                  = 0x07, -- [15:8] 0xC4 for dev adr 0x10, [7:0] device id 0x81

    };

    local DEFAULT = {

        [REG.ALS_CONF]        = 0x0000, -- 000 0|0 0 00|11 00| 00 0 0  gain 1x,  integration time 800ms,  persistance protect number 1, int disable, power on
        [REG.POWER_SAVING]    = 0x0000, -- 0000 0000 0000 0 11 1    power saving mode 4 enabled

    };

    local device = createdevice ( DEVICE, DEVICE_ADDRESS, sda, scl, REG, DEFAULT );

    local logger = device.logger;

    -- device specific definitions --------------------------------------------------------------

    device.mode = "wordlsb";

    local GAIN = {
        x2      = { conf = 0x0800, factor = 1/1.8435 },
        x1      = { conf = 0x0000, factor = 1/0.92175 },
        x1_4    = { conf = 0x1800, factor = 1/0.5 },
        x1_8    = { conf = 0x1000, factor = 1/0.125 },
    };
    device.GAIN = GAIN;

    local INT_TIME = {
        ms25  = { conf = 0x0300, factor = 10/25 },
        ms50  = { conf = 0x0200, factor = 10/50 },
        ms100 = { conf = 0x0000, factor = 10/100 },
        ms200 = { conf = 0x0040, factor = 10/200 },
        ms400 = { conf = 0x0080, factor = 10/400 },
        ms800 = { conf = 0x00C0, factor = 10/800 },
    }
    device.INT_TIME = INT_TIME;

    local function setEnabled ( enable )

        logger:debug ( "setEnabled: enable=" .. tostring ( enable ) );

        -- Bit 0 is ALS shut down setting
        --      0 = ALS power on
        --      1 = ALS shut down
        local handleBit = enable and bit.clear or bit.set;

        local data = device:readBytes ( REG.ALS_CONF, 2 );
        -- first byte is LSB
        local b = handleBit ( string.byte ( data, 1 ), 0 );
        logger:debug ( "setEnabled: b=" .. tohex ( b ) );
        device:writeBytes ( REG.ALS_CONF, { b, string.byte ( data, 2 ) } );

    end

    local function enable () setEnabled ( true ) end
    device.enable = enable;

    local function disable () setEnabled ( false ) end
    device.disable = disable;

    local alsFactor = GAIN.x1.factor * INT_TIME.ms100.factor; -- default config, change when default is changed

    function device:setConfiguration ( gain, integrationtime )

        disable ();
        self:writeWordLSB ( REG.ALS_CONF, gain.conf + integrationtime.conf ); -- implicite start/enable
        alsFactor = gain.factor * integrationtime.factor;

    end

    function device:readAmbientLight ()

        local raw = self:readWordLSB ( REG.ALS );
        local lux = alsFactor * raw;

        logger:debug ( "readAmbientLight: raw=" .. raw .. " lux=" .. lux );

        return lux, raw;

    end

    return device;

end

--------------------------------------------------------------------
-- apds9960

function M.apds9960 ( sda, scl )

    assert ( sda, "sda is undefined" );
    assert ( scl, "scl is undefined" );

    local DEVICE = "apds9960";
    local DEVICE_ADDRESS = 0x39;

    -- APDS-9960 register addresses                                                         reset value
    -- 0x00 .. 0x7F -> RAM                                                                  0x00
    local REG = {

        ENABLE         = 0x80,     -- rw   enable states and interrupts                0x00
        ATIME          = 0x81,     -- rw   adc integration time                        0xFF
        WTIME          = 0x83,     -- rw   wait time (non-gesture)                     0xFF
        AILTL          = 0x84,     -- rw   als interrupt low threshold low byte        --
        AILTH          = 0x85,     -- rw   als interrupt low threshold high byte       --
        AIHTL          = 0x86,     -- rw   als interrupt high threshold low byte       0x00
        AIHTH          = 0x87,     -- rw   als interrupt high threshold high byte      0x00
        PILT           = 0x89,     -- rw   proximity interrupt low threshold           0x00
        PIHT           = 0x8B,     -- rw   proximity interrupt high threshold          0x00
        PERS           = 0x8C,     -- rw   interrupt persistence filter (non gesture)  0x00
        CONFIG1        = 0x8D,     -- rw   configuration register one                  0x40
        PPULSE         = 0x8E,     -- rw   proximity pulse count and length            0x40
        CONTROL        = 0x8F,     -- rw   gain control                                0x00
        CONFIG2        = 0x90,     -- rw   configuration register two                  0x01
        ID             = 0x92,     -- r    devie id                                    ID
        STATUS         = 0x93,     -- r    device status                               0c00
        CDATAL         = 0x94,
        CDATAH         = 0x95,
        RDATAL         = 0x96,
        RDATAH         = 0x97,
        GDATAL         = 0x98,
        GDATAH         = 0x99,
        BDATAL         = 0x9A,
        BDATAH         = 0x9B,
        PDATA          = 0x9C,
        POFFSET_UR     = 0x9D,
        POFFSET_DL     = 0x9E,
        CONFIG3        = 0x9F,
        GPENTH         = 0xA0,
        GEXTH          = 0xA1,
        GCONF1         = 0xA2,
        GCONF2         = 0xA3,
        GOFFSET_U      = 0xA4,
        GOFFSET_D      = 0xA5,
        GOFFSET_L      = 0xA7,
        GOFFSET_R      = 0xA9,
        GPULSE         = 0xA6,
        GCONF3         = 0xAA,
        GCONF4         = 0xAB,
        GFLVL          = 0xAE,
        GSTATUS        = 0xAF,
        IFORCE         = 0xE4,
        PICLEAR        = 0xE5,
        CICLEAR        = 0xE6,
        AICLEAR        = 0xE7,
        GFIFO_U        = 0xFC,
        GFIFO_D        = 0xFD,
        GFIFO_L        = 0xFE,
        GFIFO_R        = 0xFF,

    };

    local DEFAULT = {

        [REG.ENABLE]       = 0,        -- reset all features and interrupts
        [REG.ATIME]        = 219,      -- ALS integration time, power up default 0xFF, 219 -> 103ms
        [REG.WTIME]        = 0xFF,     -- power up default 0xFF: 2.78ms, wait time between proximity and ALS
        [REG.AILTL]        = 0,        -- ALS interrupt low threshold, low byte
        [REG.AILTH]        = 0,        -- ALS interrupt low threshold, high byte
        [REG.AIHTL]        = 0xFF,     -- ALS interrupt high threshold, low byte
        [REG.AIHTH]        = 0xFF,     -- ALS interrupt high threshold, high byte
        [REG.PILT]         = 0,        -- proximity interrupt low threshold
        [REG.PIHT]         = 20,       -- proximity interrupt high threshold
        [REG.PERS]         = 0x11,     -- any value outside thresholds generates an interrupt
        [REG.CONFIG1]      = 0x60,     -- No 12x wait (WTIME) factor
        [REG.PPULSE]       = 0x87,     -- PPLEN<7:6>=2: 16us, PPULSE<5:0>=7: 8 pulses
        [REG.CONTROL]      = 0x05,     -- led drive 100mA, proximity gain 4x, ALS gain 4x
        [REG.CONFIG2]      = 0x01,     -- No saturation interrupts or LED boost
        [REG.POFFSET_UR]   = 0,
        [REG.POFFSET_DL]   = 0,
        [REG.CONFIG3]      = 0,        -- Enable all photodiodes, no SAI
        [REG.GPENTH]       = 40,       -- Threshold for entering gesture mode
        [REG.GEXTH]        = 30,       -- Threshold for exiting gesture mode
        [REG.GCONF1]       = 0x40,     -- 4 gesture events for interrupt, no diode mask, 1 event for exit
        [REG.GCONF2]       = 0x47,     -- gesture gain 4x, led drive 100mA, gesture wait time 7*2.8ms
        [REG.GOFFSET_U]    = 0,        -- No offset scaling for gesture mode
        [REG.GOFFSET_D]    = 0,        -- No offset scaling for gesture mode
        [REG.GOFFSET_L]    = 0,        -- No offset scaling for gesture mode
        [REG.GOFFSET_R]    = 0,        -- No offset scaling for gesture mode
        [REG.GPULSE]       = 0xC9,     -- 32us, 10 pulses
        [REG.GCONF3]       = 0,        -- sll photodiodes active during gesture
        [REG.GCONF4]       = 0,        -- reset gesture interrupt and gesture mode

    };

    local device = createdevice ( DEVICE, DEVICE_ADDRESS, sda, scl, REG, DEFAULT );

    local logger = device.logger;

    -- device specific definitions --------------------------------------------------------------

    -- device specific data and functions
    -- LED Drive values
    --M.LED_DRIVE_100MA         = 0;
    --M.LED_DRIVE_50MA          = 1;
    --M.LED_DRIVE_25MA          = 2;
    --M.LED_DRIVE_12_5MA        = 3;

    -- Proximity Gain (PGAIN) values
    device.PGAIN_1X                = 0;
    device.PGAIN_2X                = 1;
    device.PGAIN_4X                = 2;
    device.PGAIN_8X                = 3;

    -- ALS Gain (AGAIN) values
    --M.AGAIN_1X                = 0;
    --M.AGAIN_4X                = 1;
    --M.AGAIN_16X               = 2;
    --M.AGAIN_64X               = 3;

    -- Gesture Gain (GGAIN) values
    device.GGAIN_1X                = 0;
    device.GGAIN_2X                = 1;
    device.GGAIN_4X                = 2;
    device.GGAIN_8X                = 3;

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

    local ENABLE_BITS = {"reserved", "GEN", "PIEN", "AIEN", "WEN", "PEN", "AEN", "PON" };
    local STATUS_BITS = { "CPSAT", "PGSAT", "PINT", "AINT", "reserved", "GINT", "PVALID", "AVALID" };
    local GSTATUS_BITS = { "reserved", "reserved", "reserved", "reserved", "reserved", "reserved", "GFOV", "GVALID" };

    function device:registerBits_ENABLE ()

        return registerBits ( device:readByte ( REG.ENABLE ), ENABLE_BITS );

    end

    function device:registerBits_STATUS ()

        return registerBits ( device:readByte ( REG.STATUS ), STATUS_BITS );

    end

    function device.registerBits_GSTATUS ()

        return registerBits ( device:readByte ( REG.GSTATUS ), GSTATUS_BITS );

    end

    function device:dumpRam ()

        local ram = {};

        local MAX_REG = 0x7F;

        for reg = 0x00, MAX_REG do
            ram [reg] = i2c.readByte ( reg );
        end

        logger:info ( "dumpRam: === apds9960 Ram ===" );

        for r = 0x00, MAX_REG, 0x10 do
            local line = { tohex ( r ), ":" };
            for rr = r, r + 0x0F do
                if ( rr % 4 == 0 ) then
                    table.insert ( line, " " );
                end
                table.insert( line, tohex ( ram [rr] ) );
            end
            logger:info ( "dumpRam: " .. table.concat ( line, " " ) );
        end

    end

    return device;

end

--------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

--------------------------------------------------------------------
