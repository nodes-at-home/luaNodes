--------------------------------------------------------------------
--
-- nodes@home/luaNodes/tempNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 15.10.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

require ( "util" );
    
-------------------------------------------------------------------------------
--  Settings

local retain = espConfig.node.retain;

local triggerTimer = espConfig.node.timer.trigger;
local triggerDelay = espConfig.node.timer.triggerDelay;

local debounceTimer = espConfig.node.timer.debounce;
local debounceDelay = espConfig.node.timer.debounceDelay;

local stateTimer = espConfig.node.timer.state;
local statePeriod = espConfig.node.timer.statePeriod;

local position = 0; -- 0: closed, 1: in move up, 2: in move down, 3: stopped from move up, 4: stopped from move down, 5: fully open
local action;

local baseTopic = espConfig.node.topic;

local relayPin = espConfig.node.appCfg.relayPin;
local openPositionPin = espConfig.node.appCfg.openPositionPin;
local closedPositionPin = espConfig.node.appCfg.closedPositionPin;
local dhtPin = espConfig.node.appCfg.dhtPin;

----------------------------------------------------------------------------------------
-- private

local function triggerCover ( count )

    print ( "[APP] trigger serout count=", count );
    
    local delay = triggerDelay * 1000;

    local delays = {
        [1] = { delay, delay },
        [2] = { delay, delay, delay, delay },
    };

    gpio.serout ( relayPin, 1, delays [count], 1, function () end ); 

end

local function publishState ( client, baseTopic, state )

    -- 0: closed, 1: in move up, 2: in move down, 3: stopped from move up, 4: stopped from move down, 5: fully open
    local s = state;
    s = state == -1 and "unknown" or s;
    s = state == 0 and "closed" or s;
--    s = state == 1 and "move up" or s;
--    s = state == 2 and "move down" or s;
--    s = (state == 3 or state == 4) and "stopped" or s;
    s = state == 5 and "open" or s;
    print ( "[APP] publish state=", s );
    client:publish ( baseTopic .. "/value/position", s, 0, retain, function () end ); -- qos, retain

end

--------------------------------------------------------------------
-- public

function M.connect ( client, topic )

    print ( "[APP] connected with topic=", topic );
    
    -- register timer function when dorr is moving
    -- 0: closed, 1: in move up, 2: in move down, 3: stopped from move up, 4: stopped from move down, 5: fully open
    tmr.register ( stateTimer, statePeriod, tmr.ALARM_AUTO,  -- timer_id, interval_ms, mode
        function ()
            local openSwitch = gpio.read ( openPositionPin );
            local closeSwitch = gpio.read ( closedPositionPin );
            print ( "[APP] positions: open=", openSwitch, "closeSwitch=", closeSwitch );
            if ( openSwitch == 1 and closeSwitch == 1 ) then
                if ( position == 0 or position == 4 ) then -- just in move
                    position = 1; -- move up
                    print ( "[APP] new position=1 (move up)" );
                elseif ( position == 5 or position == 3 ) then -- just in move
                    position = 2; -- move down
                    print ( "[APP] new position=1 (move down)" );
                end
            elseif ( position == 2 and openSwitch == 1 and closeSwitch == 0 ) then -- just closed
                position = 0;
                tmr.stop ( stateTimer );
                print ( "[APP] new position=0 (closed)" );
            elseif ( position == 1 and openSwitch == 0 and closeSwitch == 1 ) then -- just opened
                position = 5;
                tmr.stop ( stateTimer );
                print ( "[APP] new position=5 (opened)" );
            end
            publishState ( client, baseTopic, position );
        end
    );
    
    -- send temperature and humdidity
    M.periodic ( client, topic );
    
    -- initial door position
    local openSwitch = gpio.read ( openPositionPin );
    local closeSwitch = gpio.read ( closedPositionPin );
    if ( openSwitch == 1 and closeSwitch == 0 ) then
        position = 0;
    elseif ( openSwitch == 0 and closeSwitch == 1 ) then
        position = 5;
    else
        position = 0; -- default is closed
    end    
    publishState ( client, baseTopic, position );
    
end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=", topic, " payload=", payload );
    
    local topicParts = util.splitTopic ( topic );
    local command = topicParts [#topicParts];
    
    -- 0: closed, 1: in move up, 2: in move down, 3: stopped from move up, 4: stopped from move down, 5: fully open
    if ( command == "command" ) then
        -- OPEN only possible if door is in motion down (position == 2, 2x triggerCover) or if closed (position == 0, 1x triggerCover)
        -- STOP only possibly if door is in motion (position == 1 or 2)
        -- CLOSE only possible if door is in motion up (position == 1, 2x triggerCover) or if opened (position == 3, 1x triggerCover)
        action = payload;
        if ( action == "OPEN" ) then
            if ( position == 2 ) then -- move down
                triggerCover ( 2 );
                position = 1; -- move up
                print ( "[APP] new position=1 (move up)" );
                publishState ( client, baseTopic, position );
            elseif ( position == 0 or position == 4 ) then -- closed or stopped from move down
                print ( "move door action=", action, "position=", position );
                triggerCover ( 1 );
                tmr.start ( stateTimer );
            else
                print ( "[APP] forbidden action=", action, "for position=", position );
            end
        elseif ( action == "STOP" ) then
            if ( position == 1 ) then -- move up
                print ( "stop door action=", action, "position=", position );
                triggerCover ( 1 );
                tmr.stop ( stateTimer );
                position = 3; -- stopped from move up
                print ( "[APP] new position=3 (stopped from move up)" );
                publishState ( client, baseTopic, position );
            elseif ( position == 2 ) then -- move down
                print ( "stop door action=", action, "position=", position );
                triggerCover ( 1 );
                tmr.stop ( stateTimer );
                position = 4; -- stopped from move down
                print ( "[APP] new position=4 (stopped from move down)" );
                publishState ( client, baseTopic, position );
            else
                print ( "[APP] forbidden action=", action, "for position=", position );
            end
        elseif ( action == "CLOSE" ) then
            if ( position == 1 ) then -- move up
                print ( "move door action=", action, "position=", position );
                triggerCover ( 2 );
                position = 2; -- move down
                print ( "[APP] new position=2 (move down)" );
                publishState ( client, baseTopic, position );
            elseif ( position == 5 or position == 3 ) then -- open or stopped from move up
                print ( "move door action=", action, "position=", position );
                triggerCover ( 1 );
                tmr.start ( stateTimer );
            else
                print ( "[APP] forbidden action=", action, "for position=", position );
            end
        else
            print ( "[APP] unknown action=", action );
        end
    end

end

function M.offline ( client )

    print ( "[APP] offline" );
    
    return true; -- restart mqtt connection
    
end

function M.periodic ( client, baseTopic )

    print ( "[APP] periodic call topic=", baseTopic );
    
    local success, t, h = util.getSensorData ( espConfig.node.appCfg.dhtPin );
    
    if ( success ) then
        print ( "[APP] publish temperature t=", t );
        client:publish ( baseTopic .. "/value/temperature", util.createJsonValueMessage ( t, "C" ), 0, retain, -- qos, retain
            function ( client )
                print ( "[APP] publish humidity h=", h );
                client:publish ( baseTopic .. "/value/humidity", util.createJsonValueMessage ( h, "%" ), 0, retain, function () end ); -- qos, retain
            end
        );
    end
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded", moduleName )

gpio.mode ( relayPin, gpio.OUTPUT );
gpio.write ( relayPin, gpio.LOW );

gpio.mode ( openPositionPin, gpio.INPUT, gpio.PULLUP );
gpio.mode ( closedPositionPin, gpio.INPUT, gpio.PULLUP );

return M;

-------------------------------------------------------------------------------