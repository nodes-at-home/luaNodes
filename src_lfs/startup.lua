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

--------------------------------------------------------------------
-- vars

--------------------------------------------------------------------
-- application global

function unrequire ( module )

    local m = package.loaded [module];
    if ( m and m.subunrequire ) then m.subunrequire (); end 

    package.loaded [module] = nil
    _G [module] = nil
    
end

function tohex ( byte, len )

    return "0x" .. string.format( "%0" .. (len or 2) .. "X", byte );
    
end

--------------------------------------------------------------------
-- private

local function startApp ()

    print ( "[STARTUP] startApp: " .. nodeConfig.app .. " is starting" );
    -- Connect to the wifi network
    print ( "[STARTUP] startApp: connecting to " .. wifiCredential.ssid );
    wifi.setmode ( wifi.STATION, true ); -- save to flash
    local phymode = nodeConfig.phymode and wifi [nodeConfig.phymode] or wifi.PHYMODE_N;
    wifi.setphymode ( phymode );
    print ( "[STARTUP] startApp: phymode=" .. wifi.getphymode () .. " (1=B,2=G,3=N) country=" .. wifi.getcountry ().country );    
    wifi.nullmodesleep ( false ); 
    print ( "[STARTUP] startApp: nullmodesleep=" .. tostring ( wifi.nullmodesleep () ) );    
    local configok = wifi.sta.config (
        { 
            ssid = wifiCredential.ssid, 
            pwd = wifiCredential.password,
            auto = true,
            save = true 
        }
    );
    print ( "[STARTUP] startApp: wifi config loaded=" .. tostring ( configok ) );    
    --wifi.sta.connect ();
    
    local wificfg = nodeConfig.wifi;
    if ( wificfg ) then
        print ( "[STARTUP] startApp: wifi fix ip=" .. wificfg.ip );
        wifi.sta.setip ( wificfg );
    end
    
    if ( file.exists ( "update.url" ) ) then
        print ( "[STARTUP] startApp: update file found" );
        require ( "update" ).update ();
    else
        if ( nodeConfig.appCfg.disablePrint ) then
            print ( "[STARTUP] startApp: DISABLE PRINT" );
            oldprint = print;
            print = function ( ... ) end
        end
        print ( "[STARTUP] startApp: starting mqttWifi heap=" .. node.heap () );
        require ( "mqttWifi" ).start ();
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

function M.init ( startTelnet)

    print ( "[STARTUP] init: telnet=" .. tostring ( startTelnet ) );

    require ( "espConfig" );
    nodeConfig = espConfig.init ();
    
    if ( nodeConfig == nil ) then
        print ( "[STARTUP] #########" );
        print ( "[STARTUP] NO CONFIG" );
        print ( "[STARTUP] #########" );
        return;
    end
    
    require ( "credential" ); -- is called  from lc file
    wifiCredential = credential.init ( nodeConfig.mode );
    unrequire ( "credential" );
    collectgarbage ();
    
    local lfsTimestamp = node.flashindex ( nil );
    nodeConfig.lfsts = lfsTimestamp;

    if ( nodeConfig.appCfg.useAdc ) then
        if ( adc.force_init_mode ( adc.INIT_ADC ) ) then
            print ( "[STARTUP] init: force_init_adc" );
            node.restart ();
            return; -- don't bother continuing, the restart is scheduled
        end        
    else
        if ( adc.force_init_mode ( adc.INIT_VDD33 ) ) then
            print ( "[STARTUP] init: force_init_vdd33" );
            node.restart ();
            return; -- don't bother continuing, the restart is scheduled
        end
    end
    
    print ( "[STARTUP] init: version=" .. nodeConfig.version );
    print ( "[STARTUP] init: waiting for application start" );

    if ( startTelnet ) then    
        require ( "telnet" ):open ( wifiCredential.ssid, wifiCredential.password, 23, nodeConfig.wifi );
    else
    
        -- boot reason https://nodemcu.readthedocs.io/en/master/en/modules/node/#nodebootreason
        -- 0, power-on
        -- 1, hardware watchdog reset
        -- 2, exception reset
        -- 3, software watchdog reset
        -- 4, software restart
        -- 5, wake from deep sleep
        -- 6, external reset
        local rawcode, bootreason = node.bootreason ();
        print ( "[STARTUP] init: rawcode=" .. rawcode .. " reason=" .. bootreason );
        if ( nodeConfig.appCfg.useQuickStartupAfterDeepSleep and bootreason == 5 ) then
            print ( "[STARTUP] quick start" );
    --        startApp ();
            tmr.alarm ( nodeConfig.timer.startup, 10, tmr.ALARM_SINGLE, startApp )
        else 
            print ( "[STARTUP] classic start" );
            tmr.alarm ( nodeConfig.timer.startup, nodeConfig.timer.startupDelay1, tmr.ALARM_SINGLE, startup )
        end
        
    end
    
end

--------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

--------------------------------------------------------------------
