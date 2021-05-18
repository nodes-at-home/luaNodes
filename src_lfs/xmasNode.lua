--------------------------------------------------------------------
--
-- nodes@home/luaNodes/xmasNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 23.12.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

-------------------------------------------------------------------------------
--  Settings

local nodeDevice = nodeConfig.appCfg.device or "lamp";

local state = "ON";
local red = 140;
local green = 55;
local blue = 170;
local brightness = 30;

----------------------------------------------------------------------------------------
-- private

-- adapted from https://github.com/EmmanuelOga/columns/blob/master/utils/color.lua
--[[
 * Converts an RGB color value to HSV. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSV_color_space.
 * Assumes r, g, and b are contained in the set [0, 255] and
 * returns h, s, and v in the set [0, 1].
 *
 * @param   Number  r       The red color value
 * @param   Number  g       The green color value
 * @param   Number  b       The blue color value
 * @return  Array           The HSV representation
]]
-- original rsgvToHsv

local function rgbToHue ( r, g, b )

    r, g, b = r / 255, g / 255, b / 255;

    local max = r;
    if ( g > max ) then max = g; end
    if ( b > max ) then max = b; end

    local min = r;
    if ( g < min ) then min = g; end
    if ( b < min ) then min = b; end

    local h;

    local d = max - min;

    if ( max == min ) then

        h = 0; -- achromatic

    else

        if ( max == r ) then
            h = (g - b) / d;
            if ( g < b ) then h = h + 6 end
        elseif ( max == g ) then h = (b - r) / d + 2;
        elseif ( max == b ) then h = (r - g) / d + 4;
        end

        h = h / 6;

    end

  h = h * 255;
  local rest = h % 1;
  h = h - rest;

--  logger.debug ( "h=", h );

  return h;

end

-- json message example from home assistant
-- * when switched off only the state value is sent
-- * when switrched on the state and brightness value is sent
-- * when the brightness is adjusted the state and brightness value is sent
-- * when the color is pecked state and color rgb is sent
-- * transition is not used
-- {
--  "state": "ON"
--  "brightness": 255,
--  "color": {
--    "g": 255,
--    "b": 255,
--    "r": 255
--  },
--  "transition": 2,
--}

local function changeState ( client, topic, payload )

    logger.info ( "changeState: to state=" .. payload .. " at " .. topic );

    -- payload ist json
    local ok, json = pcall ( sjson.decode, payload );
    if ( ok and json.state ) then

        logger.debug ( "changeState: state=" .. tostring ( json.state ) );

        -- prepare answer
        state = json.state;
        local jsonState = sjson.encode ( { state = state } );
        if ( state == "ON" ) then
            if ( json.brightness ) then
                logger.debug ( "changeState: brightness=" .. json.brightness );
                brightness = json.brightness;
            end
            if ( json.color ) then
                logger.debug ( "changeState: color=" .. json.color .. " ,r=" .. json.color.r .. " ,g=" .. json.color.g .. " ,b=" .. json.color.b );
                red = json.color.r;
                green = json.color.g;
                blue = json.color.b;
            end
            jsonState = sjson.encode ( { state = state, brightness = brightness, color = { r = red, g = green, b = blue } } );
        end

        -- prepare arduino message
        local arduino = "###";
        if ( state == "ON" ) then
            if ( json.color ) then
                logger.debug ( "changeState: red=" .. red .. " ,green=" .. green .. " ,blue=" .. blue );
                if ( nodeConfig.appCfg.useRGB ) then -- use rgb
                    arduino = arduino .. "M6";
                    arduino = arduino .. "R" .. red;
                    arduino = arduino .. "G" .. green;
                    arduino = arduino .. "B" .. blue;
                else -- use hue
                    arduino = arduino .. "M5H";
                    arduino = arduino .. rgbToHue ( red, green, blue );
                end
            end
            arduino = arduino .. "L" .. brightness;
        elseif ( state == "OFF" ) then
            arduino = arduino .. "L0";
        end
        arduino = arduino .. "\n";

        -- send messages
        client:publish ( topic .. "/state", jsonState, 0, nodeConfig.mqtt.retain, -- qos, retain
            function ()
                uart.write ( 0, arduino );
            end
        );

    end

end


--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    logger.info ( "connect: topic=" .. topic );

    -- initialize uart
--    uart.alt ( nodeConfig.appCfg.uartAlternatePins );
    uart.setup ( 0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0 ); -- last param is echo
    uart.on ( "data", "\n", function ( data ) end, 0 ); -- dont use interpreter!!!
    -- release arduino
    gpio.write ( nodeConfig.appCfg.arduinoResetPin, gpio.HIGH );

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=" .. payload );

    local topicParts = util.splitTopic ( topic );
    local device = topicParts [#topicParts];

    if ( device == nodeDevice ) then
        changeState ( client, topic, payload );
    end

end

function M.offline ( client )

    logger.info ( "offline:" );

    return true; -- restart mqtt connection

end

-------------------------------------------------------------------------------
-- main

gpio.mode ( nodeConfig.appCfg.arduinoResetPin, gpio.OUTPUT );
gpio.write ( nodeConfig.appCfg.arduinoResetPin, gpio.LOW ); -- hold the arduino in reset mode

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------
