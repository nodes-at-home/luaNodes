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

local logger = require ( "syslog" ).logger ( moduleName );

local tmr, node, i2c, u8g2, gpio = tmr, node, i2c, u8g2, gpio;

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

local suspendTimer = tmr.create ();
local suspend = false;

----------------------------------------------------------------------------------------

local function publishRain ( client, topic, rain, ticks )

    logger:info ( "publishRain: topic=" .. topic .. " rain=" .. rain .. " ticks=" .. ticks );

    local payload = ('{"rain":%.1f,"unit":"ml","ticks":%d}'):format ( rain, ticks );

    logger:debug ( "publishRain: payload=" .. payload );

    client:publish ( topic .. "/value/rain", payload, qos, retain,
        function ()
        end
    );

end

local function displayValues ( rain, ticks )

    logger:info ( "displayValues: rain=" .. rain .. " ticks=" .. ticks );

    display:clearBuffer ();

    --display:setFont ( u8g2.font_fur20_tf );
    display:setFont ( u8g2.font_6x10_tf );
    display:setFontPosTop ();
    display:drawStr ( 1,  0, "Rain" );
    display:drawStr ( 1, 12, ('%.2f mm'):format ( rain or 0.0 ) );
    display:drawStr ( 1, 24, ('%d ticks'):format ( ticks or 0 ) );

    display:sendBuffer ();

end

local function tick ( level, when, eventcount )

    logger:debug ( "tick: level=" .. level .. " when=" .. when ..  " eventcount=" .. eventcount .. " suspend=" .. tostring ( suspend ) );

    if ( not suspend ) then
        suspend = true;
        suspendTimer:start ();
        rain = rain + rainPerTick;
        ticks = ticks + 1;
        node.task.post ( function () displayValues ( rain, ticks ) end );
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start: topic=" .. topic );

    suspendTimer:register ( suspendPeriod, tmr.ALARM_SEMI,
        function ()
            logger:debug ( "start: set suspend flag to false" );
            suspend = false;
        end
    );

    gpio.mode ( tickPin, gpio.INT, gpio.PULLUP );
    gpio.trig ( tickPin, "down", tick );

    i2c.setup ( 0, sdaPin, sclPin, i2c.SLOW );
    display = u8g2 ["ssd1306_i2c_64x48_er"] ( 0, 0x3c ); -- slave address

    displayValues ( rain, ticks);

end

function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

end

function M.periodic ( client, topic )

    logger:notice ( "periodic: topic=" .. topic .. " rain=" .. rain .. " ticks=" .. ticks );

    publishRain ( client, topic, rain, ticks );
    rain = 0;
    ticks = 0;
    displayValues ( rain, ticks );

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true;

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------