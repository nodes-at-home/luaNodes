--------------------------------------------------------------------
--
-- nodes@home/luaNodes/rainNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 16.04.2021
--
-- https://makersportal.com/blog/2020/5/26/capacitive-soil-moisture-calibration-with-arduino

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

local sclPin = nodeConfig.appCfg.i2c.sclPin or 1;
local sdaPin = nodeConfig.appCfg.i2c.sdaPin or 2;

local tickPin = nodeConfig.appCfg.tickPin or 4;
local rainPerTick = nodeConfig.appCfg.rainPerTick or 1;

local retain = nodeConfig.mqtt.retain;
local NO_RETAIN = 0;
local qos = nodeConfig.mqtt.qos or 1;

local suspendPeriod = nodeConfig.timer.suspendPeriod

----------------------------------------------------------------------------------------
-- private
--

local display;

local rain = 0.0;
local ticks = 0;
local lastTick = 0;

----------------------------------------------------------------------------------------

local function publishRain ( client, topic, rain, ticks )

    --print ( "[APP] publishRain: rain=" .. rain );

    local payload = ('{"rain":%.1f,"unit":"ml","ticks":%d}'):format ( rain, ticks );

    print ( "[APP] publishRain: payload=" .. payload );

    client:publish ( topic .. "/value/rain", payload, qos, retain,
        function ()
        end
    );

end

local function displayValues ( rain, ticks )

    print ( "[APP] displayValues: rain=" .. rain .. " ticks=" .. ticks );

    display:clearBuffer ();

    --display:setFont ( u8g2.font_fur20_tf );
    display:setFont ( u8g2.font_6x10_tf );
    display:setFontPosTop ();
    display:drawStr ( 1,  0, "Rain" );
    display:drawStr ( 1, 12, ('%.1f ml'):format ( rain or 0.0 ) );
    display:drawStr ( 1, 24, ('%d ticks'):format ( ticks or 0 ) );

    display:sendBuffer ();

end

local function tick ( level, when, eventcount )

    --print ( "[APP] level=" .. level .. " when=" .. when ..  " eventcount=" .. eventcount );

    if ( (when - lastTick) > suspendPeriod ) then
        lastTick = when;
        rain = rain + rainPerTick;
        ticks = ticks + 1;
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, baseTopic )

    print ( "[APP] start:" );

    gpio.mode ( tickPin, gpio.INT, gpio.PULLUP );
    gpio.trig ( tickPin, "down", tick );

    i2c.setup ( 0, sdaPin, sclPin, i2c.SLOW );
    display = u8g2 ["ssd1306_i2c_64x48_er"] ( 0, 0x3c ); -- slave address

    displayValues ( rain, ticks);

end

function M.connect ( client, topic )

    print ( "[APP] connect:" );

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=" .. payload );

end

function M.periodic ( client, topic )

    print ( "[APP] periodic: topic=" .. topic );

    --displayValues ( rain, ticks );
    publishRain ( client, topic, rain, ticks );
    rain = 0;
    ticks = 0;

end

function M.offline ( client )

    print ( "[APP] offline:" );

    return true;

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------