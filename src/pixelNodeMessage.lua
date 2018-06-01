--------------------------------------------------------------------
--
-- nodes@home/luaNodes/pixelNodeMessage
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 10.05.2018

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

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
    
    local detailTopic = topic:sub ( nodeConfig.topic:len () + 1 );

    if ( detailTopic == "/command" or detailTopic:sub ( 1, 8 ) == "/message" ) then
    
        --local ok, json = pcall ( function () return sjson.decode ( payload ) end );
        local ok = true;
        json = sjson.decode ( payload );
        if ( ok ) then
        
            if ( json.display ) then
                if ( json.display.duration ) then
                    --print ( "[APP] duration=" .. json.display.duration ); 
-- !!!!!!!!!!!!!!                   displayCategoryPeriod = json.display.duration;
                end
                if ( json.display.brightness ) then
                    print ( "[APP] brightness=" .. json.display.brightness ); 
                    displayBrightness = json.display.duration;
                    pixel.setBrightness ( displayBrightness );
                end
                if ( json.display.time ) then
                    --print ( "[APP] time=" .. json.display.time );
                    displayEnabled.time = (json.display.time == "on") and nil;
                end
                if ( json.display.date ) then
                    --print ( "[APP] date=" .. json.display.date ); 
                    displayEnabled.date = (json.display.date == "on") and nil;
                end
                if ( json.display.enabled ) then
                    --print ( "[APP] enabled" ); 
                    for i, v in ipairs ( json.display.enabled ) do
                        --print ( "[APP] enabled i=" .. i .. " value=" .. v ); 
                        displayEnabled ["msg" .. i] = (v == "on") and nil;
                    end
                end
            end            
 
            if ( json.messages ) then
                for i, m in ipairs ( json.messages ) do
                    local l = m.line + 1;
                    if ( m.clear ) then
                        displayMessage [l] = nil;
                    elseif ( m.text ) then
                        displayMessage [l] = m.text;
                    end
                    if ( m.enabled ) then
                        displayEnabled ["msg" .. l] = (m.enabled == "on") and nil;
                    end
                end
            end
            
        end
        
        json = nil;
        
    end 

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------