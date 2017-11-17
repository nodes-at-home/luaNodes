--------------------------------------------------------------------
--
-- nodes@home/luaNodes/startup
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 22.09.2016
-- 27.09.2016 integrated some code from https://bigdanzblog.wordpress.com/2015/04/24/esp8266-nodemcu-interrupting-init-lua-during-boot/

local moduleName = ...;
local M = {};
_G [moduleName] = M;

require ( "wifi" );

--------------------------------------------------------------------
-- vars

--- WIFI ---
-- wifi.PHYMODE_B 802.11b, More range, Low Transfer rate, More current draw
-- wifi.PHYMODE_G 802.11g, Medium range, Medium transfer rate, Medium current draw
-- wifi.PHYMODE_N 802.11n, Least range, Fast transfer rate, Least current draw 
WIFI_SIGNAL_MODE = wifi.PHYMODE_N;

--------------------------------------------------------------------
-- global

function unrequire ( module )

    local m = package.loaded [module];
    if ( m and m.subunrequire ) then m.subunrequire (); end 

    package.loaded [module] = nil
    _G [module] = nil
    
end

--------------------------------------------------------------------
-- private

local function startApp ()

    print ( "[STARTUP] application " .. nodeConfig.app .. " is starting" );
    -- Connect to the wifi network
    print ( "[WIFI] connecting to " .. wifiCredential.ssid );
    wifi.setmode ( wifi.STATION );
    wifi.setphymode ( WIFI_SIGNAL_MODE );
    wifi.sta.config ( wifiCredential.ssid, wifiCredential.password );
    wifi.sta.connect ();
    local wificfg = nodeConfig.wifi;
    if ( wificfg ) then
        print ( "[WIFI] fix ip=" .. wificfg.ip );
        wifi.sta.setip ( wificfg );
    end
    
    if ( file.exists ( "update.url" ) ) then
        print ( "[STARTUP] update file found" );
        require ( "update" ).update ();
    else
        print ( "[STARTUP] start app=" .. nodeConfig.app  );
        if ( nodeConfig.appCfg.disablePrint ) then
            print ( "[STARTUP] DISABLE PRINT" );
            oldprint = print;
            print = function ( ... ) end
        end
        local app = require ( nodeConfig.app );
        print ( "[STARTUP] starting mqttNode", node.heap () );
        require ( "mqttNode" ).start ( app );
    end

end

local function startup ()

    print ( "[STARTUP] press ENTER to abort" );
    
    -- if <CR> is pressed, abort startup
    uart.on ( "data", "\r", 
        function ()
            tmr.unregister ( nodeConfig.timer.startup );   -- disable the start up timer
            uart.on ( "data" );                 -- stop capturing the uart
            print ( "[STARTUP] aborted" );
        end, 
        0 );

    -- startup timer to execute startup function in 5 seconds
    tmr.alarm ( nodeConfig.timer.startup, nodeConfig.timer.startupDelay2, tmr.ALARM_SINGLE, 
    
        function () 
            -- stop capturing the uart
            uart.on ( "data" );
            startApp ();
        end 

    );

end
    
--------------------------------------------------------------------
-- public

function M.init ()

    require ( "espConfig" );
    nodeConfig = espConfig.init ();
    unrequire ( "espConfig" );
    collectgarbage ();
    
    require ( "credential" );
    wifiCredential = credential.init ( nodeConfig.mode );
    unrequire ( "credential" );
    collectgarbage ();

    if ( nodeConfig.appCfg.useAdc ) then
        if ( adc.force_init_mode ( adc.INIT_ADC ) ) then
            print ( "[STARTUP] force_init_adc" );
            node.restart ();
            return; -- don't bother continuing, the restart is scheduled
        end        
    else
        if ( adc.force_init_mode ( adc.INIT_VDD33 ) ) then
            print ( "[STARTUP] force_init_vdd33" );
            node.restart ();
            return; -- don't bother continuing, the restart is scheduled
        end
    end
    
    print ( "[STARTUP] version=" .. nodeConfig.version );
    print ( "[STARTUP] waiting for application start" );
    
    -- boot reason https://nodemcu.readthedocs.io/en/master/en/modules/node/#nodebootreason
    -- 0, power-on
    -- 1, hardware watchdog reset
    -- 2, exception reset
    -- 3, software watchdog reset
    -- 4, software restart
    -- 5, wake from deep sleep
    -- 6, external reset
    local rawcode, bootreason = node.bootreason ();
    print ( "[STARTUP] boot: rawcode=" .. rawcode .. " ,reason=" .. bootreason );
    if ( nodeConfig.appCfg.useQuickStartupAfterDeepSleep and bootreason == 5 ) then
        print ( "[STARTUP] quick start" );
--        startApp ();
        tmr.alarm ( nodeConfig.timer.startup, 10, tmr.ALARM_SINGLE, startApp )
    else 
        print ( "[STARTUP] classic start" );
        tmr.alarm ( nodeConfig.timer.startup, nodeConfig.timer.startupDelay1, tmr.ALARM_SINGLE, startup )
    end
    
end

--------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

--------------------------------------------------------------------
