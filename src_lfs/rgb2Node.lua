    --------------------------------------------------------------------
--
-- nodes@home/luaNodes/rgb2Node
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 10.02.2021

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
-- Settings

local nodeDevice = nodeConfig.appCfg.device or "led";

local state = "OFF";

local red = nodeConfig.appCfg.initialColor and nodeConfig.appCfg.initialColor.red or 10;
local green = nodeConfig.appCfg.initialColor and nodeConfig.appCfg.initialColor.green or 10;
local blue = nodeConfig.appCfg.initialColor and nodeConfig.appCfg.initialColor.blue or 10;

local brightness = nodeConfig.appCfg.initialBrightness or 10;

local redPin = nodeConfig.appCfg.pin and nodeConfig.appCfg.pin.red;
local greenPin = nodeConfig.appCfg.pin and nodeConfig.appCfg.pin.green;
local bluePin = nodeConfig.appCfg.pin and nodeConfig.appCfg.pin.blue;

----------------------------------------------------------------------------------------
-- private

local function initPwm ( pin )

    gpio.mode ( pin, gpio.OUTPUT );
    gpio.write ( pin, gpio.LOW );
    pwm.setup ( pin, 500, 0 ); -- pwm frequency, duty cycle
    pwm.stop ( pin );

end

local function setLedPwm ( pin, brightness )

    print ( "[APP] set pwm pin=" .. pin .. " brightness=" .. brightness );

    if ( brightness > 0 ) then
        -- in ha the slider is from 0 to 255
        pwm.setduty ( pin, brightness );
        pwm.start ( pin );
    else
        pwm.stop ( pin );
    end

end

local function changeState ( client, topic )

    print ( "[APP] changeState: topic=" .. topic );

    -- prepare led
    if ( state == "ON" ) then
        print ( "[APP] changeState: red=" .. red .. " green=" .. green .. " blue=" .. blue .. " brightness=" .. brightness );
        local p = 4 * brightness / 255;
        setLedPwm ( redPin, p * red );
        setLedPwm ( greenPin, p * green );
        setLedPwm ( bluePin, p * blue );
    elseif ( state == "OFF" ) then
        setLedPwm ( redPin, 0 );
        setLedPwm ( greenPin, 0 );
        setLedPwm ( bluePin, 0 );
    end

    -- send state messages
    local jsonReply = '{"state":"' .. state .. '"}';
    if ( state == "ON" ) then
        jsonReply = '{"state":"' .. state .. '","brightness":' .. brightness .. ',"color":{"r":' .. red .. ',"g":' .. green .. ',"b":' .. blue .. '}}';
    end
    print ( "[APP] changeState: reply=" ..  jsonReply );
    client:publish ( topic .. "/state", jsonReply, 0, nodeConfig.mqtt.retain, -- qos, retain
        function ()
        end
    );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start: topic=" .. topic );

    -- set color ...
    changeState ( client, topic .. "/" .. nodeDevice );

end

function M.connect ( client, topic )

    print ( "[APP] connected: topic=" .. topic );

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

    print ( "[APP] message: topic=" .. topic .. " payload=" .. payload );

    local _, pos = topic:find ( nodeConfig.topic );
    if ( pos ) then
        local subtopic = topic:sub ( pos + 2 );
        print ( "[MQTT] subtopic=" .. subtopic );
        if ( subtopic == nodeDevice ) then
            -- payload ist json
            local pcallOk, json = pcall ( sjson.decode, payload );
            if ( pcallOk and json.state ) then
                print ( "[APP] changeState: state=" .. tostring ( json.state ) );
                -- prepare answer
                state = json.state;
                if ( state == "ON" ) then
                    if ( json.brightness ) then
                        print ( "[APP] brightness=" .. json.brightness );
                        brightness = json.brightness;
                    end
                    if ( json.color ) then
                        print ( "[APP] color: r=" .. json.color.r .. " g=" .. json.color.g .. " b=" .. json.color.b );
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
        end
    end

end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt connection

end

function M.periodic ( client, topic )

    print ( "[APP] periodic: topic=" .. topic );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

initPwm ( redPin );
initPwm ( greenPin );
initPwm ( bluePin );

return M;

-------------------------------------------------------------------------------
