--------------------------------------------------------------------
--
-- nodes@home/luaNodes/buttonNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 27.12.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

-------------------------------------------------------------------------------
--  Settings

local offDelay = nodeConfig.timer.offDelay or 3000;
local deepSleepDelay = nodeConfig.timer.deepSleepDelay;

local retain = 0; -- NO retain!!!

----------------------------------------------------------------------------------------
-- private

local restartConnection = true;

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.connect ( client, topic )

    logger.info ( "connect: topic=" .. topic );

    local rawcode, bootreason = node.bootreason ();
    if ( bootreason == 5 ) then -- 5 = wake from deep sleep
        logger.debug ( "connect: publish button press ON" );
        client:publish ( topic .. "/value/state", "ON", 0, retain, -- qos, NO retain!!!
            function ( client )
                tmr.create ():alarm ( offDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
                    function ()
                        -- publishing OFF is not harmful
                        logger.debug ( "connect: publish button press OFF" );
                        client:publish ( topic .. "/value/state", "OFF", 0, retain, -- qos, NO retain!!!
                            function ( client )
                                require ( "deepsleep").go ( client, deepSleepDelay, 0 ); -- sleep forever
                            end
                        );
                    end
                );
            end
        );
    else
        require ( "deepsleep").go ( client, deepSleepDelay, 0 ); -- sleep forever
    end

end

function M.offline ( client )

    logger.info ( "offline (local)" );

    return restartConnection;

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=" .. payload );

end

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------