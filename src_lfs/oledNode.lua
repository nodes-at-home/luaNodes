--------------------------------------------------------------------
--
-- nodes@home/luaNodes/poolNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 23.06.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

require ( "util" );

-------------------------------------------------------------------------------
--  Settings



----------------------------------------------------------------------------------------
-- private
--

local messages = {};
local msgKey = nil;
local msg = nil;

local function displayLoop ()

    msgKey, msg = next ( messages, msgKey );
    if ( not msgKey ) then -- rollover
        msgKey, msg = next ( messages, nil );
    end

    if ( msg == nil ) then msg = " "; end

    local title = type ( msg ) == "string" and nil or msg.title;
    local text = type ( msg ) == "string" and msg or msg.text;

    local function drawPages ()

        if ( title ) then
            display:setFont ( u8g.font_9x18 );
            display:setFontPosTop ();
            display:drawStr ( 0, 0, title );
        end

        display:setFont ( u8g.font_fur20 );
        display:setFontPosTop ();
        local y = nodeConfig.appCfg.resolution.height == 32 and 7 or 28;
        display:drawStr ( (128 - display:getStrWidth ( text ) ) / 2, y, text );

        if ( display:nextPage () ) then
            node.task.post ( drawPages );
        end

    end

    display:firstPage ();
    node.task.post ( drawPages );

end

local function i2cInit ( resolution, sdaPin, sclPin )

    i2c.setup( 0, sdaPin, sclPin, i2c.SLOW);
    return u8g ["ssd1306_" .. resolution .. "_i2c"] ( 0x3c ); -- slave address

end

local function spiInit ( resolution, csPin, dcPin, resetPin )

    spi.setup ( 1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 8); -- 1: HSPI, ... 8: databits, 8: clock divider on 80 MHz
    -- we won't be using the HSPI /CS line, so disable it again
    gpio.mode ( csPin, gpio.INPUT, gpio.PULLUP );

    -- disp = u8g.ssd1306_128x64_hw_spi(cs, dc, res)
    return u8g ["ssd1306_" .. resolution .. "_hw_spi"] ( csPin, dcPin, resetPin );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start: topic=" .. topic );

    local resolution = nodeConfig.appCfg.resolution.width .. "x" .. nodeConfig.appCfg.resolution.height;
    if ( nodeConfig.appCfg.i2c ) then
        local sda = nodeConfig.appCfg.i2c.sdaPin;
        local scl = nodeConfig.appCfg.i2c.sclPin;
        logger:debug ( "start: intialize i2c with sda=" .. sda .. " scl=" .. scl .. " res=" .. resolution );
        display = i2cInit ( resolution, sda, scl );
    elseif ( nodeConfig.appCfg.spi ) then
        local cs = nodeConfig.appCfg.spi.csPin;
        local dc = nodeConfig.appCfg.spi.dcPin;
        local reset = nodeConfig.appCfg.spi.resetPin;
        logger:debug ( "start: intialize spi with cs=" .. cs .. " dc=" .. dc .. " reset=" .. reset .. " res=" .. resolution );
        display = spiInit ( resolution, cs, dc, reset );
    else
        logger:debug ( "start: no device initialized" );
        return;
    end

    display:begin ();

    -- start display timer
    tmr.alarm ( nodeConfig.timer.displayLoop, nodeConfig.timer.displayLoopPeriod, tmr.ALARM_AUTO, displayLoop ) -- timer_id, interval_ms, mode

end

function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

    -- subscribe to message topic
    local t = topic .. "/message/+";
    logger:debug ( "connect: subscribe to topic=" .. t );
    client:subscribe ( t, 0, -- ..., qos
        function ( client )
        end
    );

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

    -- special treatment for UTF-8 CHAR '°'
    local i1, i2 = payload:find ( string.char ( 0xC2 ) );
    if ( i1  ) then
        payload = payload:sub ( 1, i1 - 1 ) .. payload:sub ( i2 + 1 );
    end

    local topicParts = util.splitTopic ( topic );
    local subtopic = topicParts [#topicParts - 1];

    if ( subtopic == "message" ) then
        local k = topicParts [#topicParts];
        if ( payload == "-" ) then
            -- delete key from messages
            messages [k] = nil;
        else
            -- insert message
            local ok, json = pcall ( sjson.decode, payload );
            if ( ok ) then
                messages [k] = json;
            else
                messages [k] = payload;
            end
        end
    end

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