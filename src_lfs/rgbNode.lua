--------------------------------------------------------------------
--
-- nodes@home/luaNodes/rgbNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 26.06.2018

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local ws2812, ws2812_effects, sjson, gpio, pixbuf, tmr = ws2812, ws2812_effects, sjson, gpio, pixbuf, tmr;

-------------------------------------------------------------------------------
-- Settings

local nodeDevice = nodeConfig.appCfg.device or "led";

local state = "OFF";
local red = nodeConfig.appCfg.initialColor and nodeConfig.appCfg.initialColor.red or 0;
local green = nodeConfig.appCfg.initialColor and nodeConfig.appCfg.initialColor.green or 0;
local blue = nodeConfig.appCfg.initialColor and nodeConfig.appCfg.initialColor.blue or 255;
local brightness = nodeConfig.appCfg.initialBrightness or 10;
local effect = nodeConfig.appCfg.initialEffect or "static";
local delay = nodeConfig.appCfg.initialDelay or 1000;
local ledCount = nodeConfig.appCfg.ledCount or 1;
local gndPin = nodeConfig.appCfg.gndPin; -- helper pin for ground
local order = nodeConfig.appCfg.order or "grb";

local ledcolumns = nodeConfig.appCfg.ledcolumns or 16;
local ledcolumn_length = nodeConfig.appCfg.ledcolumn_length or 13;

local effect_timer = tmr.create ();

----------------------------------------------------------------------------------------
-- private

local buffer = pixbuf.newBuffer ( ledCount, 3 ); -- 3 bytes for grb

local index = 1;
local increment = 1;

sunriseGradient = {
    { key =   0, color = { r =   0, g =   0, b =   0 } },
    { key = 128, color = { r = 240, g =   0, b =   0 } },
    { key = 224, color = { r = 240, g = 240, b =   0 } },
    { key = 255, color = { r = 128, g = 128, b = 240 } },
};

local function changeState ( client, topic )

    logger:info ( "changeState: topic=" .. topic );

    -- prepare led
    if ( state == "ON" ) then

        logger:debug ( "changeState: red=" .. red .. " green=" .. green .. " blue=" .. blue .. " brightness=" .. brightness .. " effect=" .. effect );

        ws2812_effects.stop ();
        effect_timer:unregister ();

        if ( effect == "ring" or effect == "ring_up" or effect == "ring_down" or effect == "turn_left" or effect =="turn_right" or effect == "sunrise" ) then

            -- custom effects
            buffer:fill ( 0, 0, 0 ); -- clear buffer
            ws2812.write ( buffer );

            if ( string.sub ( effect, 1, 4 ) == "ring" ) then
                if ( effect == "ring_up" ) then increment = 1;
                elseif ( effect == "ring_down" ) then increment = -1;
                end
                logger:debug ( "changeState: effect=ring ring_index=" .. index .. " increment=" .. increment );
                effect_timer:alarm ( delay, tmr.ALARM_AUTO,
                    function ()
                        -- logger:debug ( "changeState: effect=ring index=" .. index .. " increment=" .. increment );
                        buffer:fill ( 0, 0, 0 ); -- clear buffer
                        for i = 1, ledcolumns do
                            local ii = i % 2 == 1 and index or ledcolumn_length - index + 1;
                            local b = brightness / 255;
                            buffer:set ( ( i - 1 ) * ledcolumn_length + ii, b * green, b * red, b * blue  );
                        end
                        index = index + increment;
                        if ( effect == "ring" and index == ledcolumn_length ) then                 increment = -1;
                        elseif ( effect == "ring_up" and index == ledcolumn_length + 1 ) then      index = 1;
                        elseif ( effect == "ring" and index == 1 ) then                            increment = 1;
                        elseif ( effect == "ring_down" and index == 0 ) then                       index = ledcolumn_length;
                        end
                        ws2812.write ( buffer );
                    end
                );
            elseif ( string.sub ( effect, 1, 4 ) == "turn" ) then
                if ( effect == "turn_right" ) then increment = 1;
                elseif ( effect == "turn_left" ) then increment = -1;
                end
                logger:debug ( "changeState: effect=turn index=" .. index .. " increment=" .. increment );
                effect_timer:alarm ( delay, tmr.ALARM_AUTO,
                    function ()
                        -- logger:debug ( "changeState: effect=turn index=" .. index .. " increment=" .. increment );
                        buffer:fill ( 0, 0, 0 ); -- clear buffer
                        for i = 1, ledcolumn_length do
                            local b = brightness / 255;
                            buffer:set ( ( index - 1 ) * ledcolumn_length + i, b * green, b * red, b * blue  );
                        end
                        index = index + increment;
                        if ( effect == "turn_right" and index == ledcolumns + 1 ) then
                            index = 1;
                        elseif ( effect == "turn_left" and index == 0 ) then
                            index = ledcolumns;
                        end
                        ws2812.write ( buffer );
                    end
                );
            elseif ( effect == "sunrise" ) then
                local maxHeatIndex = sunriseGradient [#sunriseGradient].key;
                effect_timer:alarm ( delay, tmr.ALARM_AUTO,
                    function ()
                        local k1, k2, c1, c2;
                        for i = 1, #sunriseGradient-1 do
                            if ( sunriseGradient [i].key < index and index <= sunriseGradient [i + 1].key ) then
                                k1 = sunriseGradient [i].key;
                                c1 = sunriseGradient [i].color;
                                k2 = sunriseGradient [i + 1].key;
                                c2 = sunriseGradient [i + 1].color;
                                break;
                            end
                        end
                        local dk = k2 - k1;
                        local r = ( c2.r - c1.r ) / dk * ( index - k1 ) + c1.r;
                        local g = ( c2.g - c1.g ) / dk * ( index - k1 ) + c1.g;
                        local b = ( c2.b - c1.b ) / dk * ( index - k1 ) + c1.b;
                        local bb = brightness / 255;
                        -- logger:debug ( "changeState: b=" .. bb .. " index=" .. index .. " c=[" .. r .. "," .. g .. "," .. b .. "] k1=" .. k1 .. " c1=[" .. c1.r .. "," .. c1.g .. "," .. c1.b .. "] k2=" .. k2 .. " c2=[" .. c2.r .. "," .. c2.g .. "," .. c2.b .. "]" );
                        buffer:fill ( bb * g, bb * r, bb * b );
                        ws2812.write ( buffer );
                        index = index + 1;
                        if ( index > maxHeatIndex ) then
                            logger:debug ( "chnageState: index=" .. index .. " -> stop timer" );
                            effect_timer:unregister ();
                        end
                    end
                );
            end

        else

            -- buildin effects
            ws2812_effects.set_brightness ( brightness );
            if ( order == "rgb" ) then
                ws2812_effects.set_color ( red, green, blue );
            else
                ws2812_effects.set_color ( green, red, blue );
            end
            ws2812_effects.set_mode ( effect );
            ws2812_effects.set_delay ( delay );
            ws2812_effects.start ();

        end

    elseif ( state == "OFF" ) then
        effect_timer:unregister ();
        ws2812_effects.stop ();
        ws2812_effects.set_color ( 0, 0, 0 );
        ws2812_effects.set_mode ( "static" );
        ws2812_effects.start ();
    end

    -- send state messages
    local jsonReply = '{"state":"' .. state .. '"}';
    if ( state == "ON" ) then
        jsonReply = '{"state":"' .. state .. '","effect":"' .. effect .. '","brightness":' .. brightness .. ',"color":{"r":' .. red .. ',"g":' .. green .. ',"b":' .. blue .. '}}';
    end
    logger:debug ( "changeState: reply=" ..  jsonReply );
    client:publish ( topic .. "/state", jsonReply, 0, nodeConfig.mqtt.retain, -- qos, retain
        function ()
        end
    );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start: topic=" .. topic );

    -- D4 is the ws2812 signal line pin (UART1)
    ws2812.init ( ws2812.MODE_SINGLE );
    ws2812_effects.init ( buffer );

    -- init the effects module, set color ...
    changeState ( client, topic .. "/" .. nodeDevice );

end

function M.connect ( client, topic )

    logger:info ( "connected: topic=" .. topic );

end

-- json structure
--      {
--          "state": "ON",
--          "brightness": 255,
--          "color": {
--              "r": 255,
--              "g": 180,
--              "b": 200
--          },
--          "effect": "blink",
--          "transition": 2
--}

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

    local _, pos = topic:find ( nodeConfig.topic );
    if ( pos ) then
        local subtopic = topic:sub ( pos + 2 );
        logger:debug ( "message: subtopic=" .. subtopic );
        if ( subtopic == nodeDevice ) then
            -- payload ist json
            local pcallOk, json = pcall ( sjson.decode, payload );
            if ( pcallOk and json.state ) then
                logger:info ( "message: state=" .. tostring ( json.state ) );
                -- prepare answer
                state = json.state;
                if ( state == "ON" ) then
                    if ( json.effect ) then
                        logger:debug ( "message: effect=" .. json.effect );
                        if ( effect ~= json.effect ) then
                            effect = json.effect;
                            index = 1;
                        end
                    end
                    if ( json.brightness ) then
                        logger:debug ( "message: brightness=" .. json.brightness );
                        brightness = json.brightness;
                    end
                    if ( json.color ) then
                        logger:debug ( "message: color: r=" .. json.color.r .. " g=" .. json.color.g .. " b=" .. json.color.b );
                        red = json.color.r;
                        green = json.color.g;
                        blue = json.color.b;
                    end
                    if ( brightness == 0 or ( red == 0 and green == 0 and blue == 0 ) ) then
                        state = "OFF";
                    end
                end
                changeState ( client, topic );
            end
        elseif ( subtopic == "service/set" ) then
            local pcallOk, json = pcall ( sjson.decode, payload );
            if ( pcallOk and json.delay ) then
                logger:debug ( "message: delay=" .. tostring ( json.delay ) );
                delay = json.delay;
                ws2812_effects.set_delay ( delay );
            end
        end
    end

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true; -- restart mqtt connection

end

function M.periodic ( client, topic )

    logger:info ( "periodic: topic=" .. topic );

end

-------------------------------------------------------------------------------
-- main

-- helper GND for ws2812 signal line
if ( gndPin ) then
    gpio.mode ( gndPin, gpio.OUTPUT );
    gpio.write ( gndPin, gpio.LOW );
end

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------
