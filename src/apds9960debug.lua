--------------------------------------------------------------------
--
-- nodes@home/luaNodes/startup
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 23.10.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local apds9960 = require ( "apds9960" );

-------------------------------------------------------------------------------
-- helper

local function tohex ( byte, len )

    return "0x" .. string.format( "%0" .. (len or 2) .. "X", byte );
    
end

-------------------------------------------------------------------------------
-- debug register bits
 
local ENABLE_BITS = {"reserved", "GEN", "PIEN", "AIEN", "WEN", "PEN", "AEN", "PON" };
local STATUS_BITS = { "CPSAT", "PGSAT", "PINT", "AINT", "reserved", "GINT", "PVALID", "AVALID" };

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

function M.registerBitsENABLE ()

    return registerBits ( apds9960.readByte ( apds9960.REG.ENABLE ),ENABLE_BITS );
    
end

function M.registerBitsSTATUS ()

    return registerBits ( apds9960.readByte ( apds9960.REG.STATUS ),ENABLE_BITS );
    
end

-------------------------------------------------------------------------------
-- defines

local APDS9960_REGISTER_NAME = {
    [0x80] = "ENABLE", 
    [0x81] = "ATIME",
    [0x83] = "WTIME",
    [0x84] = "AILTL",
    [0x85] = "AILTH",
    [0x86] = "AIHTL",
    [0x87] = "AIHTH",
    [0x89] = "PILT",
    [0x8B] = "PIHT",
    [0x8C] = "PERS",
    [0x8D] = "CONFIG1",
    [0x8E] = "PPULSE",
    [0x8F] = "CONTROL",
    [0x90] = "CONFIG2",
    [0x92] = "ID",
    [0x93] = "STATUS",
    [0x94] = "CDATAL",
    [0x95] = "CDATAH",
    [0x96] = "RDATAL",
    [0x97] = "RDATAH",
    [0x98] = "GDATAL",
    [0x99] = "GDATAH",
    [0x9A] = "BDATAL",
    [0x9B] = "BDATAH",
    [0x9C] = "PDATA",
    [0x9D] = "POFFSET_UR",
    [0x9E] = "POFFSET_DL",
    [0x9F] = "CONFIG3",
    [0xA0] = "GPENTH",
    [0xA1] = "GEXTH",
    [0xA2] = "GCONF1",
    [0xA3] = "GCONF2",
    [0xA4] = "GOFFSET_U",
    [0xA5] = "GOFFSET_D",
    [0xA7] = "GOFFSET_L",
    [0xA9] = "GOFFSET_R",
    [0xA6] = "GPULSE",
    [0xAA] = "GCONF3",
    [0xAB] = "GCONF4",
    [0xAE] = "GFLVL",
    [0xAF] = "GSTATUS",
--    [0xE4] = "IFORCE",          -- (1)
--    [0xE5] = "PICLEAR",         -- (1)
--    [0xE6] = "CICLEAR",         -- (1)
--    [0xE7] = "AICLEAR",         -- (1)
    [0xFC] = "GFIFO_U",
    [0xFD] = "GFIFO_D",
    [0xFE] = "GFIFO_L",
    [0xFF] = "GFIFO_R",
};

-------------------------------------------------------------------------------
-- public

function M.dumpRam ()

    ram = {};
    
    local maxReg = 0x7F 
    
    for reg = 0x00, maxReg do
        ram [reg] = apds9960.readByte ( reg );
    end

    print ( "dump apds9960 ram")

    for r = 0x00, maxReg, 0x10 do
        local line = { tohex ( r ), ":" }; 
        for rr = r, r + 0x0F do
            if ( rr % 4 == 0 ) then
                table.insert ( line, " " );
            end
            table.insert( line, tohex ( ram [rr] ) );
        end
        print ( table.concat ( line, " " ) );
    end    
    
    ram = nil;

end

function M.dumpRegisters ( regs )

    if ( regs == nil ) then
        print ( "dump apds9960 registers" );
    end
    
    local function printLine ( reg, name )
    
        local name = APDS9960_REGISTER_NAME [reg];
        if ( name ) then
            print ( tohex ( reg ) .. ": " .. string.format( "%-20s", name ) .. "-> " .. tohex ( apds9960.readByte ( reg ) ) );
        end
        
    end

    if ( regs ) then
        if ( type ( regs ) == "table" ) then
            for i, reg in ipairs ( regs ) do
                printLine ( reg );
            end
        else
            printLine ( regs );
        end
    else
        for reg, name in pairs ( APDS9960_REGISTER_NAME ) do
            printLine ( reg );
        end
    end
    
end

--------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

--------------------------------------------------------------------
