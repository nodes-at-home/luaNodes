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

----------------------------------------------------------------------------------------
-- private

local buffer = ws2812.newBuffer ( ledCount, 3 ); -- 3 bytes for grb

local function changeState ( client, topic )

    print ( "[APP] changeState: topic=" .. topic );

    -- prepare led
    if ( state == "ON" ) then
        print ( "[APP] changeState: red=" .. red .. " green=" .. green .. " blue=" .. blue .. " brightness=" .. brightness .. " effect=" .. effect );
        ws2812_effects.stop ();
        ws2812_effects.set_brightness ( brightness );
        ws2812_effects.set_brightness ( brightness );
        if ( order == "rgb" ) then
            ws2812_effects.set_color ( red, green, blue );
        else
            ws2812_effects.set_color ( green, red, blue );
        end
        ws2812_effects.set_mode ( effect );
        ws2812_effects.set_delay ( delay );
        ws2812_effects.start ();
    elseif ( state == "OFF" ) then
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
    
    -- D4 is the ws2812 signal line pin (UART1)
    ws2812.init ( ws2812.MODE_SINGLE );
    ws2812_effects.init ( buffer );
   
    -- init the effects module, set color ...
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
                    if ( json.effect ) then
                        print ( "[APP] effect=" .. json.effect );
                        effect = json.effect;
                    end
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
        elseif ( subtopic == "service/set" ) then
            local pcallOk, json = pcall ( sjson.decode, payload );
            if ( pcallOk and json.delay ) then
                print ( "[APP] message: delay=" .. tostring ( json.delay ) );
                delay = json.delay;
                ws2812_effects.set_delay ( delay );
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

-- helper GND for ws2812 signal line
if ( gndPin ) then
    gpio.mode ( gndPin, gpio.OUTPUT );
    gpio.write ( gndPin, gpio.LOW );
end

return M;

-------------------------------------------------------------------------------
