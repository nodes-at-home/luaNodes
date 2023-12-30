--------------------------------------------------------------------
--
-- nodes@home/luaNodesEsp32/tftNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 22.03.2019

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  used moduls

local tonumber = tonumber;
local ucg = ucg;
local spi = spi;
local tmr = tmr;
local string = string;
local math = math;
local gpio = gpio;

-------------------------------------------------------------------------------
--  Settings

-- pins can be assigned freely to available GPIOs
local sclkPin = 18;       -- brown
local mosiPin = 23;       -- orange
local misoPin = 19;       -- black

local tftCsPin = 15;      -- yellow
local dcPin = 4;          -- white
local resPin = 2;         -- green

local touchCsPin = 22;    -- yellow
local touchPin = 21;      -- green

local PIXEL_PER_UNIT = 40;
local MARGIN = 3;
local CORNER_RADIUS = 8;

local CTRL_LO_DFR = tonumber ( "0011", 2 );     -- 12 bit, differential mode, pd01 = 11
local CTRL_LO_SER = tonumber ( "0100", 2 );     -- 12 bit, single ended, pd01 = 00
local CTRL_HI_X = tonumber ( "10010000", 2 );   -- start bit, x high
local CTRL_HI_Y = tonumber ( "11010000", 2 );   -- start bit, y high
local ADC_MAX = 0x0fff;  -- 12 bits

----------------------------------------------------------------------------------------
-- private

local disp;
local touchdevice;

local busmaster = spi.master ( spi.HSPI, { sclk = sclkPin, mosi = mosiPin, miso = misoPin }, 1 ); -- no DMA

local touchTimer = tmr.create ();

--------------------------------------------------------------------
-- public
-- mqtt callbacks

-- font_7x13B_tr
-- font_helvB08_hr
-- font_helvB10_hr
-- font_helvB12_hr
-- font_helvB18_hr
-- font_ncenB24_tr
-- font_ncenR12_tr
-- font_ncenR14_hr

local function drawButton ( label, col, row, width, height )

    local x = (col - 1) * PIXEL_PER_UNIT + MARGIN;
    local y = (row - 1) * PIXEL_PER_UNIT + MARGIN;
    local w = width * PIXEL_PER_UNIT - 2 * MARGIN;
    local h = height * PIXEL_PER_UNIT - 2 * MARGIN;
    
    disp:setColor ( 0, 0, 255 );
    disp:drawRBox ( x, y, w, h, CORNER_RADIUS ); 
    
    disp:setColor ( 255, 255, 255 );
    disp:drawRFrame ( x, y, w, h, CORNER_RADIUS ); 
    disp:drawRFrame ( x+1, y+1, w-2, h-2, CORNER_RADIUS-2 );
    
    local l = disp:getStrWidth ( label );
    local a = disp:getFontAscent ();
    local d = disp:getFontDescent (); -- this value is negativ
    
    disp:drawString ( x + (w - l)/2, y + (h - a + d)/2 + a, 0, label );
     
end

local function _readLoop ( ctrl, samples )

    local prev = 0xffff;
    local cur = 0xffff;
    local i = 1;
    
    repeat
        -- local recv = touchdevice:transfer ( { txdata = string.char ( ctrl ), rxlen = 2 } );
        -- local b1 = string.byte ( recv, 1 );
        -- local b2 = string.byte ( recv, 2 );
        local recv1 = touchdevice:transfer ( string.char ( 0 ) );
        local recv2 = touchdevice:transfer ( string.char ( ctrl ) );
        local b1 = string.byte ( recv1, 1 );
        local b2 = string.byte ( recv2, 1 );
        --local recv = touchdevice:transfer ( string.char ( ctrl ) );
        prev = cur;
        cur = b1 * 16 + math.floor ( b2 / 16 );
        --print ( "i=" .. i .. " len=" .. string.len ( recv1 ) .. " b1=" .. tohex( b1 ) .. " b2=" .. tohex ( b2 ) .. " cur=" .. tohex ( cur, 4 ) );
        i = i + 1; 
    until prev == cur or i > samples
    
    return cur;
    
end

local function isTouched ( timer )

    local touched = gpio.read ( touchPin ) == 0;
    if ( touched ) then
        gpio.write( touchCsPin, 0 );
        touchdevice:transfer ( string.char ( CTRL_HI_X + CTRL_LO_DFR ) );
        local x = _readLoop ( CTRL_HI_X + CTRL_LO_DFR, 255 );
        local y = _readLoop ( CTRL_HI_Y + CTRL_LO_DFR, 255 );
        touchdevice:transfer ( string.char ( 0 ) );
        touchdevice:transfer ( string.char ( CTRL_HI_Y + CTRL_LO_SER ) );
        touchdevice:transfer ( string.char ( 0 ) );
        touchdevice:transfer ( string.char ( 0 ) );
        gpio.write( touchCsPin, 1 );
        print ( "x=" .. x .. " y=" .. y );
    end
    
end

function M.start ( client, topic )

    print ( "[APP] start: topic=" .. topic );

    -- display must be initialized first!    
    disp = ucg.ili9341_18x240x320_hw_spi ( busmaster, tftCsPin, dcPin, resPin );
    
    gpio.config ( { gpio = touchCsPin, dir = gpio.OUT } );
    gpio.write( touchCsPin, 1 );
    touchdevice = busmaster:device ( { mode = 0, freq = 100000 } ); -- 2MHz = 16 x fSAMPLE (125kHz)
    
    disp:begin ( ucg.FONT_MODE_TRANSPARENT );
    disp:clearScreen ();
    
    disp:setFont ( ucg.font_ncenR12_tr );
    
    --disp:setRotate90 ();
    disp:setRotate270 ();
    
    drawButton ( "2x1", 1, 1, 2, 1 );
    drawButton ( "2x1", 4, 1, 2, 1 );
    
    drawButton ( "2x2", 2, 3, 2, 2 );
    drawButton ( "2x2", 4, 3, 2, 2 );
    
    touchTimer:register ( 100, tmr.ALARM_AUTO, isTouched );
    
end

function M.connect ( client, topic )

    print ( "[APP] connected: topic=" .. topic );
    
    touchTimer:start ();
    
    
end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " payload=" .. payload );
    
end

function M.offline ( client )

    print ( "[APP] offline" );
    
    touchTimer.stop ();
    
    return true; -- restart mqtt connection
    
end

function M.periodic ( client, topic )
	
    print ( "[APP] periodic: topic=" .. topic );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------
