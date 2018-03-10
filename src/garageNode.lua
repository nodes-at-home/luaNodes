--------------------------------------------------------------------
--
-- nodes@home/luaNodes/tempNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 15.10.2016
-- junand 22.11.2017 completely reworked
local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

-- 0: closed
-- 1: in move up
-- 2: in move down
-- 3: stopped from move up
-- 4: stopped from move down
-- 5: fully open

local MOVING_PERSIST = nodeConfig.appCfg.movingPersist or 2;
local POSITION_PERSIST = nodeConfig.appCfg.positionPersist or 2;

local POSITION_CLOSED = 0;
local POSITION_MOVE_UP = 1;
local POSITION_MOVE_DOWN = 2;
local POSITION_STOPPED_FROM_MOVE_UP = 3;
local POSITION_STOPPED_FROM_MOVE_DOWN = 4;
local POSITION_OPEN = 5;
local POSITION_MOVING = 6; -- when the cover is triggered and moved from classic remote

local position = POSITION_OPEN; -- default

local POSITION_TEXT = {
    [POSITION_CLOSED] = "closed",
    [POSITION_MOVE_UP] = "up",
    [POSITION_MOVE_DOWN] = "down",
    [POSITION_STOPPED_FROM_MOVE_UP] = "stopped",
    [POSITION_STOPPED_FROM_MOVE_DOWN] = "stopped",
    [POSITION_OPEN] = "open",
    [POSITION_MOVING] = "moving",
};

local movingPersistCount = 0;
local positionPersistCount = 0;

----------------------------------------------------------------------------------------
-- private

local function getSensorData ( pin )

    print ( "[DHT] pin=" .. pin );

    local status, temperature, humidity, temp_decimial, humi_decimial = dht.read ( pin );
    
    if( status == dht.OK ) then

        print ( "[DHT] Temperature: " .. temperature .. " C" );
        print ( "[DHT] Humidity: " .. humidity .. "%" );
        
    elseif( status == dht.ERROR_CHECKSUM ) then
    
        print ( "[DHT] Checksum error" );
        temperature = nil;
        humidity = nil;
        
    elseif( status == dht.ERROR_TIMEOUT ) then
    
        print ( "[DHT] Time out" );
        temperature = nil;
        humidity = nil;
        
    end
    
    local result = status == dht.OK; 
    
    return result, temperature, humidity;
    
end

local function triggerCover ( count )

    print ( "[APP] triggerCover: count=" .. count );
    
    local delay = nodeConfig.timer.triggerDelay * 1000;

    local delays = {
        [1] = { delay, delay },
        [2] = { delay, delay, delay, delay },
    };

    gpio.serout ( nodeConfig.appCfg.relayPin, 1, delays [count], 1, function () end ); 

end

local function publishState ( client, topic, state, callback )

    print ( "[APP] publishState: topic=" .. topic .. " state=" .. state );

    local s = POSITION_TEXT [state] or "unknown"; 
    print ( "[APP] publishState: state=" .. s );
    client:publish ( topic .. "/value/position", s, 0, nodeConfig.mqtt.retain, callback ); -- qos, retain

end

local function checkSwitches ( client, topic )

    local openSwitch = gpio.read ( nodeConfig.appCfg.openPositionPin );
    local closeSwitch = gpio.read ( nodeConfig.appCfg.closedPositionPin );
    
--    if ( openSwitch ~= closeSwitch ) then
--        print ( "[APP] position=" .. position .." openSwitch=" .. openSwitch .. " closeSwitch=" .. closeSwitch );
--    end
    
    local newPosition = nil; 
    
    if ( openSwitch == 1 and closeSwitch == 1 ) then
        if ( position == POSITION_OPEN or position == POSITION_CLOSED ) then
            if ( movingPersistCount > MOVING_PERSIST ) then
                newPosition = POSITION_MOVING;
                movingPersistCount = 0;
            else
                movingPersistCount = movingPersistCount + 1;
            end
        else
            positionPersistCount = 0;
        end
    elseif ( position ~= POSITION_CLOSED and openSwitch == 1 and closeSwitch == 0 ) then
        if ( positionPersistCount > POSITION_PERSIST ) then
            newPosition = POSITION_CLOSED;
            positionPersistCount = 0;
        else
            positionPersistCount = positionPersistCount + 1;
        end
    elseif ( position ~= POSITION_OPEN and openSwitch == 0 and closeSwitch == 1 ) then
        if ( positionPersistCount > POSITION_PERSIST ) then
            newPosition = POSITION_OPEN;
            positionPersistCount = 0;
        else
            positionPersistCount = positionPersistCount + 1;
        end
    end
    
    if ( newPosition ) then
        print ( "[APP] checkSwitches: position=" .. POSITION_TEXT [position] .. " newPosition=" .. POSITION_TEXT [newPosition] );
        publishState ( client, topic, newPosition );
        position = newPosition;
    end
    
end

--------------------------------------------------------------------
-- public

function M.start ( client, topic )

    print ( "[APP] start: topic=" .. topic );
    
    -- initial door position
    local openSwitch = gpio.read ( nodeConfig.appCfg.openPositionPin );
    local closeSwitch = gpio.read ( nodeConfig.appCfg.closedPositionPin );
    if ( openSwitch == 1 and closeSwitch == 0 ) then
        position = POSITION_CLOSED;
    else
        position = POSITION_OPEN; -- default
    end    

    print ( "[APP] start: initial position=" .. POSITION_TEXT [position] );

    -- register timer function when door is moving
    tmr.register ( nodeConfig.timer.state, nodeConfig.timer.statePeriod, tmr.ALARM_AUTO, 
        function ()
            checkSwitches ( client, topic )
        end 
    );

end

function M.connect ( client, topic )

    print ( "[APP] connect: topic=" .. topic );
    
    publishState ( client, nodeConfig.topic, position,
        function ()
            tmr.start ( nodeConfig.timer.state );
        end
    );
    
end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " payload=" .. payload );
    
    local topicParts = require ( "util" ).splitTopic ( topic );
    unrequire ( "util" );
    local command = topicParts [#topicParts];
    
    if ( command == "command" ) then
    
        -- OPEN only possible if door is in motion down (2x triggerCover) or if closed (1x triggerCover)
        -- STOP only possibly if door is in motion
        -- CLOSE only possible if door is in motion up (2x triggerCover) or if opened (1x triggerCover)
        
        local action = payload;
        print ( "[APP] message: action=" .. action .. " position=" .. POSITION_TEXT [position] );
        
        local newPosition = nil;

        if ( position == POSITION_MOVING ) then
            -- only trigger cover and wait for a switch is triggering
            triggerCover ( 1 );
        else        
            if ( action == "OPEN" ) then
                if ( position == POSITION_MOVE_DOWN ) then
                    newPosition = POSITION_MOVE_UP;
                    triggerCover ( 2 );
                elseif ( position == POSITION_CLOSED ) then
                    newPosition = POSITION_MOVE_UP
                    triggerCover ( 1 );
                elseif ( position == POSITION_STOPPED_FROM_MOVE_DOWN ) then
                    newPosition = POSITION_MOVE_UP
                    triggerCover ( 1 );
                else
                    print ( "[APP] message: forbidden action" );
                end
            elseif ( action == "STOP" ) then
                if ( position == POSITION_MOVE_UP ) then
                    newPosition = POSITION_STOPPED_FROM_MOVE_UP;
                    triggerCover ( 1 );
                elseif ( position == POSITION_MOVE_DOWN ) then
                    newPosition = POSITION_STOPPED_FROM_MOVE_DOWN;
                    triggerCover ( 1 );
                else
                    print ( "[APP] message: forbidden action" );
                end
            elseif ( action == "CLOSE" ) then
                if ( position == POSITION_MOVE_UP ) then
                    newPosition = POSITION_MOVE_DOWN;
                    triggerCover ( 2 );
                elseif ( position == POSITION_OPEN ) then
                    newPosition = POSITION_MOVE_DOWN;
                    triggerCover ( 1 );
                elseif ( position == POSITION_STOPPED_FROM_MOVE_UP ) then
                    newPosition = POSITION_MOVE_DOWN;
                    triggerCover ( 1 );
                else
                    print ( "[APP] message: forbidden action" );
                end
            else
                print ( "[APP] message: unknown action=" .. action );
            end
        end
        
        print ( "[APP] message: action=" .. action .. " position=" .. POSITION_TEXT [position] .. 
                " newPosition=" .. (newPosition and POSITION_TEXT [newPosition] or "---") );
        
        if ( newPosition ) then
            publishState ( client, nodeConfig.topic, newPosition );
            position = newPosition;
        end
        
    end

end

function M.offline ( client )

    print ( "[APP] offline" );
    
    tmr.stop ( nodeConfig.timer.state );
    
    return true; -- restart mqtt connection
    
end

function M.periodic ( client, topic )

    print ( "[APP] periodic: topic=" .. topic );
    
    local success, t, h = getSensorData ( nodeConfig.appCfg.dhtPin );
    
    if ( success ) then
        print ( "[APP] periodic: temperature t=" .. t );
        client:publish ( topic .. "/value/temperature", [[{"value":]] .. t .. [[,"unit":"°C"}]], 0, nodeConfig.mqtt.retain, -- qos, retain
            function ( client )
                print ( "[APP] periodic: humidity h=" .. h );
                client:publish ( topic .. "/value/humidity", [[{"value":]] .. h .. [[,"unit":"%"}]], 0, nodeConfig.mqtt.retain, -- qos, retain 
                function () 
                end 
            );
            end
        );
    end
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

gpio.mode ( nodeConfig.appCfg.relayPin, gpio.OUTPUT );
gpio.write ( nodeConfig.appCfg.relayPin, gpio.LOW );

gpio.mode ( nodeConfig.appCfg.openPositionPin, gpio.INPUT, gpio.PULLUP );
gpio.mode ( nodeConfig.appCfg.closedPositionPin, gpio.INPUT, gpio.PULLUP );

return M;

-------------------------------------------------------------------------------