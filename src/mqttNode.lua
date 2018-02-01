--------------------------------------------------------------------
--
-- nodes@home/luaNodes/mqttNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 15.10.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

appNode = nil;    -- application callbacks
mqttClient = nil;     -- mqtt client

----------------------------------------------------------------------------------------
-- private

local function startMqtt ()
        
    print ( "[WIFI] dnsname=" .. wifi.sta.gethostname () );
    print ( "[WIFI] network=" .. (wifi.sta.getip () and wifi.sta.getip () or "NO_IP") );
    print ( "[WIFI] mac=" .. wifi.sta.getmac () );
    
    -- Setup MQTT client and events
    if ( mqttClient == nil ) then
        local mqttClientName = wifi.sta.gethostname () .. "-" .. nodeConfig.class .. "-" .. nodeConfig.type .. "-" .. nodeConfig.location;
        mqttClient = mqtt.Client ( mqttClientName, nodeConfig.keepAliveTime, "", "" ); -- ..., keep_alive_time, username, password
    end

    print ( "[MQTT] connecting to " .. nodeConfig.mqttBroker );

    -- this is never called, because the last registration wins
    -- mqttClient:on ( "connect", 
        -- function ( client )
            -- print ( "[MQTT] CONNECTED" );
            -- appNode.connect ();
        -- end
    -- );
        
    mqttClient:on ( "message", 
        function ( client, topic, payload )
            print ( "[MQTT] message received topic=" .. topic .." payload=" .. (payload == nil and "***nothing***" or payload) );
            if ( payload ) then
                -- check for update
                if ( topic == nodeConfig.topic .. "/service/update" ) then 
                    require ( "mqttNodeUpdate" ).checkAndStart ( payload );
                    unrequire ( "mqttNodeUpdate" );
                    collectgarbage ();
                elseif ( topic == nodeConfig.topic .. "/service/trace" ) then
                    require ( "trace" );
                    if ( payload == "ON" ) then 
                        trace.on ();
                    else 
                        trace.off ();
                    end
                elseif ( topic == nodeConfig.topic .. "/service/config" ) then
                    require ( "mqttNodeConfig" ).subscribe ( client );
                    unrequire ( "mqttNodeConfig" );
                    collectgarbage ();
                elseif ( topic == "nodes@home/config/" .. node.chipid () .. "/json" ) then
                    require ( "mqttNodeConfig" ).receive ( client, payload );
                    unrequire ( "mqttNodeConfig" );
                    collectgarbage ();
                else
                    appNode.message ( client, topic, payload );
                end
            end
        end
    );
        
    mqttClient:on ( "offline", 
        function ( client )
            print ( "[MQTT] offline" );
            local restartMqtt = appNode.offline ( client );
            if ( restartMqtt ) then
                print ( "[MQTT] restart connection" );
                tmr.alarm ( nodeConfig.timer.wifiLoop, nodeConfig.timer.wifiLoopPeriod, tmr.ALARM_AUTO, wifiLoop ) -- timer_id, interval_ms, mode
            end
        end
    );
    
    while not pcall (
        function ()        
            result = mqttClient:connect( nodeConfig.mqttBroker , 1883, 0, 0, -- broker, port, secure, autoreconnect
                require ( "mqttNodeConnect" ).connect,        
                function ( client, reason ) 
                    print ( "[MQTT] not connected reason=" .. reason );
                end
            )
        end
    )
    do
        print ( "[MQTT] retry connecting" );
    end
    unrequire ( "mqttNodeConnect" );
    collectgarbage ();

    print ( "[MQTT] connect result=" .. tostring ( result ) );
end

local function wifiLoop ()

    -- 0: STA_IDLE,
    -- 1: STA_CONNECTING,
    -- 2: STA_WRONGPWD,
    -- 3: STA_APNOTFOUND,
    -- 4: STA_FAIL,
    -- 5: STA_GOTIP.

    if ( wifi.sta.status () == wifi.STA_GOTIP ) then
    
        -- Stop the loop
        -- tmr.stop ( TIMER_WIFI_LOOP );

        local t = nodeConfig.trace.onStartup;
        print ( "[MQTT] trace.onStartup=" .. tostring ( t ) ); 
        if ( t ~= nil and t ) then
            print ( "[MQTT] start with trace" );
            require ( "trace" ).on ();
            local pollingTimer = tmr.create (); -- interval_ms, mode
            pollingTimer:alarm ( 200, tmr.ALARM_AUTO, 
                function ()
                    if ( not trace.isStarting () ) then
                        pollingTimer:unregister ();
                        startMqtt ();
                    end
                end 
            );
        else
            print ( "[MQTT] start with no trace" );
            startMqtt ();
        end

    else

        print ( "[WIFI] Connecting..." );

    end
    
end

--------------------------------------------------------------------
-- public

function M.start ( app )

    local function noop () return false; end
    
    local function initAppNode ( app )
    
        if ( app.version == nil ) then app.version = "undefined"; end
        if ( app.start == nil ) then app.start = noop; end
        if ( app.connect == nil ) then app.connect = noop; end
        if ( app.offline == nil ) then app.offline = noop; end
        if ( app.message == nil ) then app.message = noop; end
        if ( app.periodic == nil ) then app.periodic = noop; end
        
        appNode = app;
        
    end
    
    if ( app ) then
        initAppNode ( app );
    else
        print ( "[MQTT] no app" );
        initAppNode ( {} );
    end
    
    -- loop to wait up to connected to wifi
    tmr.alarm ( nodeConfig.timer.wifiLoop, nodeConfig.timer.wifiLoopPeriod, tmr.ALARM_AUTO, wifiLoop ); -- timer_id, interval_ms, mode
    
    if ( nodeConfig.timer.periodic ) then
        tmr.alarm ( nodeConfig.timer.periodic, nodeConfig.timer.periodicPeriod, tmr.ALARM_AUTO, -- timer_id, interval_ms, mode
            function ()
                if ( mqttClient ) then 
                    local voltage = -1;
                    if ( nodeConfig.appCfg.useAdc ) then
                        local scale = nodeConfig.appCfg.adcScale or 4200;
                        print ( "[MQTT] adcScale=" .. scale );           
                        voltage = adc.read ( 0 ) / 1023 * scale; -- mV
                    else
                        voltage = adc.readvdd33 ();
                    end
                    print ( "[MQTT] send voltage=" .. voltage );
                    mqttClient:publish ( nodeConfig.topic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], 0, nodeConfig.retain, -- qos, retain                                    
                        function ( client )
                            appNode.periodic ( mqttClient, nodeConfig.topic );
                        end
                    );
                end
            end 
        );
    end
    
end
  
-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------