-- junand 21.04.2018

-- Set module name as parameter of require
local modname = ...;
local M = {};
_G[modname] = M;

--------------------------------------------------------------------------------
-- spi pins
--
--  label           esp8266     esp32   remarks
--  clk             5           GPIO14                  black
--  cs              8           GPIO15                  white
--  mosi            7           GPIO13                  grey
--  miso            6           GPIO12   not used
--

--------------------------------------------------------------------------------
-- settings

local csPin;

local numberOfModules = 1; 
local numberOfDisplayColumns = 8 * numberOfModules;
local numberOfBufferColumns = 2 * numberOfDisplayColumns + (numberOfModules == 1 and (128 - numberOfDisplayColumns) or 0);

--print ( "numberOfBufferColumns=" .. numberOfBufferColumns )

--------------------------------------------------------------------------------
-- local variables

pixelBuffer = {};

local shakeFrom;
local shakeTo;
local displayColumn;
local shakeDelta;

local shakeTimer;

--------------------------------------------------------------------------------
-- private functions
--------------------------------------------------------------------------------

local function setCommand ( command, value )

    -- enable sending data
    gpio.write ( csPin, gpio.LOW );
    
    local data = 256 * command + value;
    for i = 1, numberOfModules do
        spi.send ( 1, data );
    end

    -- make the chip latch data into the registers
    gpio.write ( csPin, gpio.HIGH );

end

local function display ( startColumn )

    --print ( "[MAX7219] send: start=" ..  startColumn .. " verticalShift=" .. tostring ( verticalShift ) );
    
    startColumn = startColumn or 1;
    
    for col = 1, 8 do

        -- enable sending data
        gpio.write ( csPin, gpio.LOW );
        
        for m = 1, numberOfModules do
            local c = startColumn + 8 * ( m - 1 ) + col - 1;
            spi.send ( 1, 256 * col + (pixelBuffer [c] or 0x00) );
        end
        
        -- make the chip latch data into the registers
        gpio.write ( csPin, gpio.HIGH );

    end
    
end

local function printChar ( char, startCol )

    --print ( "[MAX7219] printChar: char=" .. tostring ( char ) .. " startCol=" .. tostring ( startCol ) );

    --assert ( startCol, "printChar: at not set" );
    
    local insertCol = startCol;
    local filename = "sprite_" .. char .. ".dat";
    
    if ( startCol > 0 and startCol <= numberOfBufferColumns ) then
        --print ( "[MAX7219] printChar: " .. filename );
        if ( file.exists ( filename ) ) then
            file.open ( filename );
            local s = file.read ();
            file.close ();
            --print ( "[MAX7219] printChar: s=" .. s );
            string.gsub ( s, "(%w+)",
                function ( w ) 
                    if ( insertCol > 0 and insertCol <= numberOfBufferColumns ) then
                        pixelBuffer [insertCol] = 0 + w;
                    end
                    insertCol = insertCol + 1; 
                end 
            );
--            local sprite = require ( filename );
--            unrequire ( filename );
--            for i = 1, #sprite do
--                local col = startCol + i - 1;
--                if ( col > 0 and col <= numberOfBufferColumns ) then
--                    pixelBuffer [col] = sprite [i];
--                end
--            end
--            insertCol = insertCol + #sprite; 
            insertCol = insertCol + M.printEmptyColumn ( insertCol );
        end
    end

    return insertCol - startCol;

end

--------------------------------------------------------------------------------
-- public functions

function M.init ( pin, period, brightness )

    --print ( "[MAX7219] pin=" .. tostring ( pin ) .. " init: period=" .. tostring ( period ) .. " brightness=" .. tostring ( brightness ) );
    
    csPin = pin;
    
    if ( not shakeTimer ) then
        shakeTimer = tmr.create ();
    end
    
    shakeFrom = 1;
    shakeTo = 1;
    displayColumn = 1;
    shakeDelta = 0;

    shakeTimer:alarm ( period, tmr.ALARM_AUTO,
        function ()
            display ( displayColumn );
            displayColumn = displayColumn + shakeDelta;
            if ( displayColumn == shakeFrom or displayColumn == shakeTo ) then
                shakeDelta = -shakeDelta;
            end
        end
    );
    
    spi.setup ( 1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 16, 8 );
    
    --print ( "[MAX7219] init: set gpio mode");
    -- Must NOT be done _before_ spi.setup() because that function configures all HSPI* pins for SPI. Hence,
    -- if you want to use one of the HSPI* pins for slave select spi.setup() would overwrite that.
    gpio.mode ( csPin, gpio.OUTPUT );
    gpio.write ( csPin, gpio.HIGH );

--    local MAX7219_REG_DECODEMODE = 0x09;
--    local MAX7219_REG_SHUTDOWN = 0x0C;
--    local MAX7219_REG_SCANLIMIT = 0x0B;
--    local MAX7219_REG_DISPLAYTEST = 0x0F;
--    local MAX7219_REG_INTENSITY = 0x0A;

    --print ( "[MAX7219] init: set registers");
    setCommand ( 0x09, 0x00 );          -- using an led matrix (not digits)
    setCommand ( 0x0C, 0x01 );          -- not in shutdown mode
    setCommand ( 0x0B, 0x07 );          -- all 8 digits
    setCommand ( 0x0F, 0x00 );          -- no display test
    setCommand ( 0x0A, brightness );    -- intensity

    -- empty registers, turn all LEDs off
    M.clear ();
    
end

function M.clear ()

    --print ( "[MAX7219] clear:");
    
    for i = 1, numberOfBufferColumns do
        pixelBuffer [i] = nil;
    end
    display ( 1 );
    
end

function M.setBrightness ( brightness )

    assert ( brightness, "brightness not set" );
    
    if ( brightness >= 0 and brightness < 20 ) then
        setCommand ( 0x0A, brightness );    -- intensity
    end
    
end

function M.printEmptyColumn ( startCol )

    --print ( "[MAX7219] printEmptyColumn: at=" .. at );

    if ( not startCol ) then startCol = 1 end

    if ( startCol > 0 and startCol <= numberOfBufferColumns ) then
        pixelBuffer [startCol] = nil;
    end
    
    return 1;
    
end

function M.printString ( s, startCol )

    --print ( "[MAX7219] printString: s=" ..  s .. " at=" .. tostring ( at ) );

    startCol = startCol or 1;
    local insertCol = startCol;
    local skip = false;
    for i = 1, s:len () do
        if ( skip ) then
            skip = false;
        else
            local c = s:byte ( i );
            local char = tohex ( c );
            if ( c == 0xC3 or c == 0xC2 ) then -- german umlaut and ß and °
                skip = true 
                char = char .. "_" .. tohex ( s:byte ( i + 1 ) );
            end
            insertCol = insertCol + printChar ( char, insertCol or 1 );
        end
    end
    
    M.static ( startCol );
     
    return insertCol - startCol;
            
end

function M.printDateTimeString ( s, insertCol )

    --print ( "[MAX7219] printDateTimeString: s=" ..  s .. " insertCol=" .. tostring ( insertCol ) );
    
    insertCol = insertCol or 1;
    
    for i = 1, s:len () do
        local c = s:sub ( i, i ); 
        if ( c == "1" ) then
            insertCol = insertCol + M.printEmptyColumn ( insertCol );
        end
        if ( c == " " ) then
            insertCol = insertCol + M.printEmptyColumn ( insertCol );
            insertCol = insertCol + M.printEmptyColumn ( insertCol );
            insertCol = insertCol + M.printEmptyColumn ( insertCol );
        else
            insertCol = insertCol + printChar ( tohex ( c:byte ( 1 ) ), insertCol );
        end
    end
    
    local len = insertCol - 1;
    
    if ( len > numberOfDisplayColumns ) then
        M.shake ( 1, len - numberOfDisplayColumns ); -- cut last empty column
    else
        M.static ( 1 );
    end
    
    return len;
    
end

function M.shake ( from, to )

    --print ( "[MAX7219] shake: from=" .. from .. " to=" .. to );
    
--    assert ( type ( from ) == "number", "shake: from is not a number from=" .. from );
--    assert ( type ( to ) == "number", "shake: to is not a number to=" .. to );
--    assert ( from > 0 and from < numberOfBufferColumns, "shake: from is not in range from=" .. from );
--    assert ( to > 0 and to < numberOfBufferColumns, "shake: to is not in range to=" .. to );
    
    if ( from ~= to ) then

        shakeTimer:stop ();
        shakeFrom = from;
        shakeTo = to;
        shakeDelta = from < to and 1 or from > to and -1 or 0;
        displayColumn = from;
        shakeTimer:start ();
        
    end
    
end

function M.static ( at )

    --print ( "[MAX7219] static: at=" .. at );

--    assert ( type ( at ) == "number", "static: at is not a number at=" .. at );
--    assert ( at > 0 and at < numberOfBufferColumns, "static: at is not in range at=" .. at );
    
    shakeTimer:stop ();
    shakeFrom = 1;
    shakeTo = 1;
    shakeDelta = 0;
    displayColumn = at;
    shakeTimer:start ();
    
end

function M.printAndShakeString ( s )

    --print ( "[MAX7219] printAndShakeString: s=" .. s );

    local len = M.printString ( s );
    
    if ( len > numberOfDisplayColumns ) then
        M.shake ( 1, len - numberOfDisplayColumns ); -- cut last empty column
    else
        M.static ( 1 );
    end
    
    return len;
    
end

--------------------------------------------------------------------------------

return M;

--------------------------------------------------------------------------------
