--------------------------------------------------------------------
--
-- nodes@home/luaNodes/deepsleep
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 12.01.2018

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

function M.go ( client, delay, duration )

    logger.info ( "go: initiate alarm for closing connection in " ..  delay/1000 .. " seconds" );

    -- wait with closing connection
    tmr.create ():alarm ( delay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
        function ()
            logger.debug ( "go: closing mqtt connection" );
            client:close ();
            logger.debug ( "go: closing wifi connection" );
            wifi.eventmon.register ( wifi.eventmon.STA_DISCONNECTED,
                function ( event )
                    logger.debug ( "go: Going to deep sleep for ".. duration/1000 .." seconds" );
                    if duration > 0 then duration = (duration - delay) * 1000 end
                    node.dsleep ( duration ); -- us, 1 -> RF_CAL after deep sleep 2-> no RF Call, sleep immediately
                end
            );
            wifi.sta.disconnect ();
        end
    );

end

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------