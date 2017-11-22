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

-------------------------------------------------------------------------------
--  Settings

----------------------------------------------------------------------------------------
-- private

local restartConnection = true;

--------------------------------------------------------------------
-- public
-- mqtt callbacks

local function goDeepSleep ( client, baseTopic )

    if ( not useOfflineCallback ) then
        restartConnection = false;
        print ( "[APP] initiate alarm for closing connection in " ..  nodeConfig.timer.deepSleepDelay/1000 .. " seconds" );
        -- wait a minute with closing connection
        tmr.alarm ( nodeConfig.timer.deepSleep, nodeConfig.timer.deepSleepDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
            function () 
                -- publishing OFF is not harmful
                print ( "[APP] publish button press OFF" );
                client:publish ( baseTopic .. "/value/state", "OFF", 0, 0, -- qos, NO retain!!!
                    function ( client )
                        print ( "[APP] closing connection" );
                        client:close ();
                        print ( "[APP] Going to deep sleep forever" );
                        node.dsleep ( 0, 1 ); -- sleep forever, with RF_CAL
                    end
                );
            end
        );
    else
        print ( "[APP] closing connection using offline handler" );
        -- TODO falls das wieder benutzt wird, dann hier noch publish etc. einbauen
        client:close ();
    end

end

function M.connect ( client, baseTopic )

    print ( "[APP] connect" );
    
    local rawcode, bootreason = node.bootreason ();
    if ( bootreason == 5 ) then -- 5 = wake from deep sleep
        print ( "[APP] publish button press ON" );
        client:publish ( baseTopic .. "/value/state", "ON", 0, 0, -- qos, NO retain!!!
            function ( client )
                goDeepSleep ( client, baseTopic );
            end
        );
    else
        goDeepSleep( client, baseTopic );
    end

end

local function offline ( client )

    print ( "[APP] offline" );

    print ( "[APP] Going to deep sleep forever" );
    node.dsleep ( 0, 1 ); -- sleep forever, with RF_CAL
    
    return restartConnection; -- dont restart mqtt connection
    
end

function M.offline ( client )

    print ( "[APP] offline (local)" );

    return restartConnection; 

end

local function message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=" .. payload );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

if ( nodeConfig.appCfg.useOfflineCallback ) then
    M.offline = offline;
end

return M;

-------------------------------------------------------------------------------