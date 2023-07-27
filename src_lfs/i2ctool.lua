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

local i2c, bit = i2c, bit;

--------------------------------------------------------------------
-- settings

local ID = 0;

local deviceAdress; -- i2c address: first 7 bits are the device address, last bit marks read/write mode, coding is done by i2c.adderss

-------------------------------------------------------------------------------
-- i2c basics

function M.readByte ( register )

    logger:debug ( "readByte: addr=" .. tohex ( deviceAdress )  .. " reg=" .. tohex ( register ) )

    return string.byte ( M.readBytes ( register, 1 ), 1 );

end

function M.readBytes ( register, len )

    logger:debug ( "readBytes: addr=" .. tohex ( deviceAdress ) .. " reg=" .. tohex ( register ) .. " len=" .. len )

    i2c.start ( ID );
    local ackTransmit = i2c.address ( ID, deviceAdress, i2c.TRANSMITTER );
    logger:debug ( "readBytes: ack transmit=" .. tostring ( ackTransmit ) .. " addr=" .. tohex ( deviceAdress ) );
    local n = i2c.write ( ID, register );
    logger:debug ( "readBytes: n=" .. n )
    i2c.stop ( ID );

    i2c.start ( ID );
    local ackReceive = i2c.address ( ID, deviceAdress, i2c.RECEIVER );
    logger:debug ( "readBytes: ack receive=" .. tostring ( ackReceive ) )
    local data = i2c.read ( ID, len );
    i2c.stop ( ID );

    return data;

end

function M.writeByte ( register, byte )

    logger:debug ( "writeByte: addr=" .. tohex ( deviceAdress )  .. " reg=" .. tohex ( register ) .. " byte=" .. tohex ( byte ) )

    i2c.start ( ID );
    local ackTransmit = i2c.address ( ID, deviceAdress, i2c.TRANSMITTER );
    logger:debug ( "writeByte: ack transmit=" .. tostring ( ackTransmit ) )
    local n1 = i2c.write ( ID, register );
    logger:debug ( "writeByte: n1=" .. n1 )
    local n2 = i2c.write ( ID, byte );
    logger:debug ( "writeByte: n2=" .. n2 )
    i2c.stop ( ID );

end

function M.setBit ( reg, pos, value )

    --logger:debug ( "setBit: reg=" .. tohex ( register ) .. " pos=" .. pos .. " value=" .. tohex ( value ) )

    if ( value == nil ) then value = 1; end
    local handleBit = value and bit.set or bit.clear;
    local n = M.writeByte ( reg, handleBit ( M.readByte ( reg ), pos ) );
    --logger:debug ( "setBit: n=" .. n )

end

function M.setBits ( reg, highest, lowest, value )

--    assert ( reg, "reg is undefined" );
--    assert ( value, "value is undefined" );
--    assert ( 8 >= highest and highest >= 0, "highest bit is outside (highest=" .. highest .. ")" );
--    assert ( 8 >= lowest and lowest >= 0, "lowest bit is outside (lowest=" .. lowest .. ")" );
--    assert ( highest >= lowest, "wrong order (highest=" .. highest .. ", lowest=" .. lowest ..")" );

    --logger:debug ( "setBits: reg=" .. tohex ( register ) .. " highest=" .. highest .. " lowest=" .. lowest .. " value=" .. tohex ( value ) )

    local old = M.readByte ( reg );

    local mask = 0;
    for i = 0, highest - lowest do
        mask = bit.set ( mask, i );
    end

    local new = bit.bor ( bit.band ( old, bit.bxor ( bit.lshift ( mask, lowest ), 0xFF ) ), bit.lshift ( bit.band ( value, mask ), lowest ) );

    local n = M.writeByte ( reg, new );
    --logger:debug ( "setBits: n=" .. n )

end

function M.readWord ( highByteReg, lowByteReg )

    --logger:debug ( "setWord: highByteReg=" .. tohex ( highByteReg ) .. " lowByteReg=" .. tohex ( lowByteReg ) .. " threshold=" .. threshold )

    local highValue = M.readByte ( highByteReg );
    local lowValue = M.readByte ( lowByteReg );

    return 256 * highValue + lowValue;

end

function M.writeWord ( highByteReg, lowByteReg, word )

    --logger:debug ( "setWord: highByteReg=" .. tohex ( highByteReg ) .. " lowByteReg=" .. tohex ( lowByteReg ) .. " threshold=" .. threshold )

    local highValue = bit.rshift ( bit.band ( word, 0xFF00 ), 8 );
    local lowValue = bit.band ( word, 0x00FF );

    local n1 = M.writeByte ( highByteReg, highValue );
    local n2 = M.writeByte ( lowByteReg, lowValue );
    --logger:debug ( "setWord: n1=" .. n1 .. " n2=" .. n2 )

end

function M.isBit ( reg, pos )

    --logger:debug ( "isBit: reg=" .. tohex ( reg ) .. " pos=" .. pos )

    return bit.isset ( M.readByte ( reg ), pos )

end

-------------------------------------------------------------------------------
-- debug

function M.registerBits ( value, fields, full )

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

function M.dumpRegisters ( regs, addr )

    local function printLine ( addr, name )

        if ( name ) then
            logger:debug ( "printLine: " .. tohex ( addr ) .. ": " .. string.format( "%-20s", name ) .. "-> " .. tohex ( M.readByte ( addr ) ) );
        end

    end

    if ( regs ) then
        if ( type ( regs ) == "table" ) then
            if ( addr ) then
                logger:debug ( "dumpRegisters: by address=" .. tohex ( addr ) );
                for reg, _addr in pairs ( regs ) do
                    if ( _addr == addr ) then
                        printLine ( addr, tostring ( reg ) );
                    end
                end
            else
                logger:debug ( "dumpRegisters: all" );
                for reg, addr in pairs ( regs ) do
                    printLine ( addr, tostring ( reg ) );
                end
            end
        end
    end

end

-------------------------------------------------------------------------------
-- public functions

function M.init ( address, sda, scl, defaults )

    --assert ( address, "address is undefined" );
    --assert ( sda, "sda is undefined" );
    --assert ( type ( sda ) == "number", "sda isnt number" );
    --assert ( scl, "scl is undefined" );
    --assert ( type ( scl ) == "number", "scl isnt number" );
    --assert ( defaults == nil, "defaults is not nil" );
    --assert ( verbose == nil or type ( verbose ) == "boolean", "verbose isnt boolean" );

    logger:debug ( "init: sda=" .. sda .. " scl=" .. scl  )

    deviceAdress = address;

    local speed = i2c.setup ( ID, sda, scl, i2c.SLOW ); -- 100 kHz
    logger:debug ( "init: speed=" .. speed .. " addr=" .. tohex ( deviceAdress ) );

    if ( defaults and type ( defaults ) == "table" ) then
        for register, value in pairs ( defaults ) do
            M.writeByte ( register, value );
        end
    end

    return speed;

end

--------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

--------------------------------------------------------------------
