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

local node, tmr, file, uart, adc = node, tmr, file, uart, adc;

--------------------------------------------------------------------
-- vars

local startupTimer = tmr.create ();

local logger; -- syslog will be required after config load in init ()
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

    logger:info ( "startApp: " .. nodeConfig.app .. " is starting" );

    if ( file.exists ( "update.url" ) ) then
        logger:debug ( "startApp: update file found" );
        require ( "update" ).start ();
    else
        if ( nodeConfig.appCfg.disablePrint ) then
            logger:debug ( "startApp: DISABLE PRINT" );
            oldprint = print;
            print = function ( ... ) end
        end
        logger:debug ( "startApp: starting mqttWifi heap=" .. node.heap () );
        require ( "mqttWifi" ).start ();
    end

end

local function startup ()

    print ( "==> press ENTER to abort" );

    -- if <CR> is pressed, abort startup
    uart.on ( "data", "\r",
        function ()
            startupTimer:unregister ();   -- disable the start up timer
            uart.on ( "data" );                 -- stop capturing the uart
            logger:debug ( "startup: ABORTED" );
        end,
        0   -- go not into Lua interpreter
    );

    -- startup timer to execute startup function in 5 seconds
    startupTimer:alarm ( nodeConfig.timer.startupDelay2, tmr.ALARM_SINGLE,
        function ()
            -- stop capturing the uart
            uart.on ( "data" );
            startApp ();
        end
    );

end

--------------------------------------------------------------------
-- public

function M.start ( startTelnet)

    print ( "[STARTUP] init: telnet=" .. tostring ( startTelnet ) );

    require ( "espConfig" );
    nodeConfig = espConfig.init ();

    if ( nodeConfig == nil ) then
        print ( "[STARTUP] #########" );
        print ( "[STARTUP] NO CONFIG" );
        print ( "[STARTUP] #########" );
        return;
    end

    logger = require ( "syslog" ).logger ( moduleName );
    logger:notice ( "init: config loaded telnet=" .. tostring ( startTelnet ) );

    --node.setonerror (
    --    function ( s )
    --        print ( "ONERROR => " .. s );
    --        logger:emergency ( "init: ERROR occured ==> " .. s );
    --        syslog.restart ();
    --        logger:alert ( "initnodemcu-tool upload: RESTARTING" ); -- to resolve the restart flag in syslog
    --    end
    --)

    require ( "credential" ); -- is called  from lc file
    wifiCredential = credential.init ( nodeConfig.mode );
    unrequire ( "credential" );
    collectgarbage ();

    local lfsTimestamp = node.LFS.time;
    nodeConfig.lfsts = lfsTimestamp;

    if ( nodeConfig.appCfg.useAdc ) then
        if ( adc.force_init_mode ( adc.INIT_ADC ) ) then
            logger:debug ( "init: force_init_adc" );
            node.restart ();
            return; -- don't bother continuing, the restart is scheduled
        end
    else
        if ( adc.force_init_mode ( adc.INIT_VDD33 ) ) then
            logger:debug ( "init: force_init_vdd33" );
            node.restart ();
            return; -- don't bother continuing, the restart is scheduled
        end
    end

    logger:notice ( "init: version=" .. nodeConfig.version .. " branch=" .. nodeConfig.branch .. " lua=" .. _VERSION );
    logger:debug ( "init: waiting for application start" );

    if ( startTelnet ) then
        require ( "telnet" ):open ( wifiCredential.ssid, wifiCredential.password );
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
        logger:debug ( "init: rawcode=" .. rawcode .. " reason=" .. bootreason );
        if ( nodeConfig.appCfg.useQuickStartupAfterDeepSleep and bootreason == 5 ) then
            logger:notice ( "quick start" );
    --        startApp ();
            startupTimer:alarm ( 10, tmr.ALARM_SINGLE, startApp )
        else
            logger:notice ( "classic start" );
            startupTimer:alarm ( nodeConfig.timer.startupDelay1, tmr.ALARM_SINGLE, startup )
        end

    end

end

--------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName ) -- syslog not yet ready

return M;

--------------------------------------------------------------------
