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

--------------------------------------------------------------------
-- settings

local ID = 0;

local deviceAdress; -- i2c address
local debug = false;

-------------------------------------------------------------------------------
-- i2c basics

function M.readByte ( register )

    --if ( debug ) then print ( "[I2C] readByte: reg=" .. tohex ( register ) ) end

    return string.byte ( M.readBytes ( register, 1 ), 1 );    
    
end

function M.readBytes ( register, len )

    --if ( debug ) then print ( "[I2C] writeBytes: reg=" .. tohex ( register ) .. " len=" .. len ) end

    i2c.start ( ID );
    local ackTransmit = i2c.address ( ID, deviceAdress, i2c.TRANSMITTER );
    --if ( debug ) then print ( "[I2C] readBytes: ack transmit=" .. tostring ( ackTransmit ) ) end
    local n = i2c.write ( ID, register );
    --if ( debug ) then print ( "[I2C} readBytes: n=" .. n ) end
    i2c.stop ( ID );
    
    i2c.start ( ID );
    local ackReceive = i2c.address ( ID, deviceAdress, i2c.RECEIVER );
    --if ( debug ) then print ( "[I2C] readBytes: ack receive=" .. tostring ( ackReceive ) ) end
    local data = i2c.read ( ID, len );
    i2c.stop ( ID );
    
    return data;
    
end

function M.writeByte ( register, byte )

    --if ( debug ) then print ( "[I2C] writeByte: reg=" .. tohex ( register ) .. " byte=" .. tohex ( byte ) ) end
    
    i2c.start ( ID );
    local ackTransmit = i2c.address ( ID, deviceAdress, i2c.TRANSMITTER );
    --if ( debug ) then print ( "[I2C] writeByte: ack transmit=" .. tostring ( ackTransmit ) ) end
    local n1 = i2c.write ( ID, register );
    --if ( debug ) then print ( "[I2C} writeByte: n1=" .. n1 ) end
    local n2 = i2c.write ( ID, byte );
    --if ( debug ) then print ( "[I2C} writeByte: n2=" .. n2 ) end
    i2c.stop ( ID );
    
end

function M.setBit ( reg, pos, value )

    --if ( debug ) then print ( "[I2C] setBit: reg=" .. tohex ( register ) .. " pos=" .. pos .. " value=" .. tohex ( value ) ) end

    if ( value == nil ) then value = 1; end
    local handleBit = value and bit.set or bit.clear;
    local n = M.writeByte ( reg, handleBit ( M.readByte ( reg ), pos ) );
    --if ( debug ) then print ( "[I2C} setBit: n=" .. n ) end

end

function M.setBits ( reg, highest, lowest, value )

--    assert ( reg, "reg is undefined" );
--    assert ( value, "value is undefined" );
--    assert ( 8 >= highest and highest >= 0, "highest bit is outside (highest=" .. highest .. ")" );
--    assert ( 8 >= lowest and lowest >= 0, "lowest bit is outside (lowest=" .. lowest .. ")" );
--    assert ( highest >= lowest, "wrong order (highest=" .. highest .. ", lowest=" .. lowest ..")" );
     
    --if ( debug ) then print ( "[I2C] setBits: reg=" .. tohex ( register ) .. " highest=" .. highest .. " lowest=" .. lowest .. " value=" .. tohex ( value ) ) end

    local old = M.readByte ( reg );

    local mask = 0;
    for i = 0, highest - lowest do
        mask = bit.set ( mask, i );
    end
    
    local new = bit.bor ( bit.band ( old, bit.bxor ( bit.lshift ( mask, lowest ), 0xFF ) ), bit.lshift ( bit.band ( value, mask ), lowest ) );
    
    local n = M.writeByte ( reg, new );
    --if ( debug ) then print ( "[I2C} setBits: n=" .. n ) end

end

function M.readWord ( highByteReg, lowByteReg )

    local highValue = i2ctool.readByte ( highByteReg );
    local lowValue = i2ctool.readByte ( lowByteReg );
    
    return 256*highByteReg + lowByteReg;
    
end

function M.writeWord ( highByteReg, lowByteReg, word )

    --if ( debug ) then print ( "[I2C] setWord: highByteReg=" .. tohex ( highByteReg ) .. " lowByteReg=" .. tohex ( lowByteReg ) .. " threshold=" .. threshold ) end

    local highValue = bit.rshift ( bit.band ( word, 0xFF00 ), 8 );
    local lowValue = bit.band ( word, 0x00FF );
    
    local n1 = M.writeByte ( highByteReg, highValue );
    local n2 = M.writeByte ( lowByteReg, lowValue );
    --if ( debug ) then print ( "[I2C} setWord: n1=" .. n1 .. " n2=" .. n2 ) end
    
end

function M.isBit ( reg, pos )
    
    --if ( debug ) then print ( "[I2C] isBit: reg=" .. tohex ( reg ) .. " pos=" .. pos ) end

    return bit.isset ( M.readByte ( reg ), pos )
    
end

-------------------------------------------------------------------------------
-- debug

--function M.registerBits ( value, fields, full )
-- 
--    local line = { "<" };
--    
--    if ( full == nil ) then full = false; end
--
--    if ( full ) then 
--        for i = 7, 0, -1 do
--            table.insert ( line, fields [8-i] );
--            table.insert ( line, ":" );
--            table.insert ( line, bit.isset ( value, i ) and "1" or "0" );
--            if ( i > 0 ) then table.insert ( line, "," ); end
--        end
--    else
--        local first = true;
--        for i = 7, 0, -1 do
--            if ( bit.isset ( value, i ) ) then
--                if ( first ) then 
--                    first = false;
--                else
--                    table.insert ( line, "," );
--                end
--                table.insert ( line, fields [8-i] );
--            end
--        end
--    end
--    
--    table.insert ( line, ">" );
--    
--    return ( table.concat ( line ) );
--    
--end

--function M.dumpRegisters ( regs, addr )
--
--    local function printLine ( addr, name )
--    
--        if ( name ) then
--            --print ( tohex ( addr ) .. ": " .. string.format( "%-20s", name ) .. "-> "  );
--            print ( tohex ( addr ) .. ": " .. string.format( "%-20s", name ) .. "-> " .. tohex ( M.readByte ( addr ) ) );
--        end
--        
--    end
--
--    if ( regs ) then
--        if ( type ( regs ) == "table" ) then
--            if ( addr ) then
--                --print ( "dump register")
--                for reg, _addr in pairs ( regs ) do
--                    if ( _addr == addr ) then
--                        printLine ( addr, tostring ( reg ) );
--                    end
--                end
--            else
--                print ( "dump registers" );
--                for reg, addr in pairs ( regs ) do
--                    printLine ( addr, tostring ( reg ) );
--                end
--            end
--        end
--    end
--    
--end

-------------------------------------------------------------------------------
-- public functions

function M.init ( address, sda, scl, defaults, verbose )

--    assert ( address, "address is undefined" );
--    assert ( sda, "sda is undefined" );
--    assert ( type ( sda ) == "number", "sda isnt number" );
--    assert ( scl, "scl is undefined" );
--    assert ( type ( scl ) == "number", "scl isnt number" );
--    assert ( defaults == nil, "defaults is not nil" );
--    assert ( verbose == nil or type ( verbose ) == "boolean", "verbose isnt boolean" );
    
    debug = verbose or false; 
    --if ( debug ) then print ( "[I2C] init: scl=" .. scl .. " sda=" .. sda  ) end

    deviceAdress = address;

    local speed = i2c.setup ( ID, sda, scl, i2c.SLOW ); -- 100 kHz
    print ( "[I2C] init: speed=" .. speed .. " addr=" .. tohex ( deviceAdress ) );

    if ( defaults and type ( defaults ) == "table" ) then
        for register, value in pairs ( defaults ) do
            M.writeByte ( register, value );
        end
    end
    
    return speed;
    
end

--------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

--------------------------------------------------------------------
