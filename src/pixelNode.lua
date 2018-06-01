--------------------------------------------------------------------
--
-- nodes@home/luaNodes/pixelNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 26.04.2018

local moduleName = ...;
local M = {};
_G [moduleName] = M;

require ( "pixel" );

-------------------------------------------------------------------------------
--  Settings

local csPin = nodeConfig.appCfg.csPin;
local shakePeriod = nodeConfig.timer.shakePeriod;

SNTP = nodeConfig.appCfg.sntpServer or "de.pool.ntp.org" or "192.168.2.1";

displayBrightness = 3;
displayCategory = "time";
displayCategoryPeriod = 15;
displayCategoryPeriodCounter = displayCategoryPeriod;
displayEnabled = {};
displayMessage = {};

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

--function M.start ( client, topic )
--
--    print ( "[APP] start" );
--    
--end

function M.connect ( client, topic )

    print ( "[APP] connect: topic=" .. topic );
    
    pixel.init ( csPin, shakePeriod, displayBrightness );
    
    -- subscibe to .../message/#
    -- subsciption to .../command and .../alert is not necesssary
    
    require ( "pixelNodeConnect" ).connect ( client, topic );
    unrequire ( "pixelNodeConnect" );

end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt 

end

--  all top level attributes are optional
--
--    "display" : {
--        "duration" : nn,
--        "brightness" : nn,
--        "time" : true,
--        "date" : true,
--        "weekday" : true,
--        "enabled" : [ "on", ..., "off" ]     // flags for 20 messages
--    },
--    "messages" : [ // no is 0 .. 9
--        { 
--            "line" : n, 
--            "text" : "string", 
--            "enabled" : "on"
--            "clear" : true              // clear "overwrites" text, clear = false has no effect
--        },      
--    ],
--    "alert" : {
--        "duration" : nn,
--        "text" : "string"
--    }

--    nodes@home/display/pixel/kitchen/command                        payload is json like above described
--    nodes@home/display/pixel/kitchen/alert                          payload is the json like above for alert attribute
--    
--    nodes@home/display/pixel/kitchen/message/temperature/indoor     payload is a json with the temperature and unit
--    nodes@home/display/pixel/kitchen/message/temperature/outdoor    payload is a json with the temperature and unit
--    nodes@home/display/pixel/kitchen/message/temperature/pool       payload is a json with the temperature and unit
--    
--    nodes@home/display/pixel/kitchen/message/forecast               payload is a json like for messages above
--    
--    nodes@home/display/pixel/kitchen/message/calendar/garbage       json
--    nodes@home/display/pixel/kitchen/message/calendar/paper         json
--    nodes@home/display/pixel/kitchen/message/calendar/yellowbag     json
--    nodes@home/display/pixel/kitchen/message/calendar/biowaste      json
--    nodes@home/display/pixel/kitchen/message/calendar               reset
--    
--    nodes@home/display/pixel/kitchen/message/traffic/undine         json
--    nodes@home/display/pixel/kitchen/message/traffic/andreas        json
--    nodes@home/display/pixel/kitchen/message/traffic                reset

function M.message ( client, topic, payload )

    --print ( "[APP] message: topic=" .. topic .. " payload=" .. payload );
    
    print ( "[APP] message: heap=" .. node.heap () );
    
    require ( "pixelNodeMessage" ).message ( client, topic, payload );
    unrequire ( "pixelNodeMessage" );
    
end

--function M.periodic ( client, topic )
--
--    print ( "[APP] periodic call topic=" .. topic );
--    
--end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------