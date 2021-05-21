--------------------------------------------------------------------
--
-- nodes@home/luaNodes/touchNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 14.09.2018

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

require ( "util" );

-------------------------------------------------------------------------------
--  Settings

local retain = 0; -- NO retain!!!

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start: topic=" .. topic );

    if ( type ( nodeConfig.appCfg.sensors ) == "table" ) then
        for _, touch in ipairs ( nodeConfig.appCfg.sensors ) do
            gpio.mode ( touch.pin, gpio.INT );
            gpio.trig ( touch.pin, "both",
                function ( level, when, count )
                    logger:debug ( "start: device=" .. touch.device .. " level=" .. level .. " when=" .. when .. " count=" .. count );
                    local t = topic .. "/" .. touch.device .. "/value/state";
                    local v = "ON";
                    if ( level == 0 ) then v = "OFF" end
                    logger:debug ( "start: publish button press " .. v .. " topic=" .. t );
                    client:publish ( t, v, 0, retain, -- qos, NO retain!!!
                        function ( client )
                        end
                    );
                end
            );
        end
    end

end

function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true; -- restart mqtt

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

end

function M.periodic ( client, topic )

    logger:info ( "periodic: topic=" .. topic );

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------