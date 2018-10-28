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
        mqttClient = mqtt.Client ( mqttClientName, nodeConfig.mqtt.keepAliveTime, "", "" ); -- ..., keep_alive_time, username, password

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
                    local _, pos = topic:find ( nodeConfig.topic );
                    if ( pos ) then
                        local subtopic = topic:sub ( pos + 1 );
                        print ( "[MQTT] subtopic=" .. subtopic );
                        if ( subtopic == "/service/update" ) then 
                            require ( "mqttNodeUpdate" ).checkAndStart ( payload );
                            unrequire ( "mqttNodeUpdate" );
                            collectgarbage ();
                        elseif ( subtopic == "/service/trace" ) then
                            require ( "trace" );
                            if ( payload == "ON" ) then 
                                trace.on ();
                            else 
                                trace.off ();
                            end
                        elseif ( subtopic == "/service/config" ) then
                            require ( "mqttNodeConfig" ).subscribe ( client );
                            unrequire ( "mqttNodeConfig" );
                            collectgarbage ();
                        elseif ( subtopic == "/service/restart" ) then
                            print ( "[MQTT] RESTARTING")
                            if ( trace ) then 
                                print ( "[MQTT] ... wait ..." );
                                trace.off ( node.restart ); 
                            else
                                node.restart ();
                            end
                        else
                            if ( appNode.message ) then
                                appNode.message ( client, topic, payload );
                            end
                        end
                    elseif ( subtopic == "nodes@home/config/" .. node.chipid () .. "/json" ) then
                        require ( "mqttNodeConfig" ).receive ( client, payload );
                        unrequire ( "mqttNodeConfig" );
                        collectgarbage ();
                    end
                end
            end
        );
        
        mqttClient:on ( "offline", 
            function ( client )
                print ( "[MQTT] offline" );
                if ( appNode.offline and appNode.offline ( client ) ) then
                    print ( "[MQTT] restart connection" );
                    tmr.start ( nodeConfig.timer.wifiLoop ) -- timer_id
                end
            end
        );

    end

    print ( "[MQTT] connecting to " .. nodeConfig.mqtt.broker );
    
    while not pcall (
        function ()        
            result = mqttClient:connect( nodeConfig.mqtt.broker , 1883, 0, 0, -- broker, port, secure, autoreconnect
                function ( client )
                    print ( "[MQTT] connected, require connect module" );
                    require ( "mqttNodeConnect" ).connect ( client );
                    unrequire ( "mqttNodeConnect" );
                end,        
                function ( client, reason ) 
                    print ( "[MQTT] not connected reason=" .. reason );
                    tmr.start ( nodeConfig.timer.wifiLoop );
                end
            )
        end
    )
    do
        print ( "[MQTT] retry connecting" );
    end

    print ( "[MQTT] connect result=" .. tostring ( result ) );
    if ( not result ) then
        tmr.start ( nodeConfig.timer.wifiLoop );
    end
    
end

local function wifiLoop ()

    -- 0: STA_IDLE,
    -- 1: STA_CONNECTING,
    -- 2: STA_WRONGPWD,
    -- 3: STA_APNOTFOUND,
    -- 4: STA_FAIL,
    -- 5: STA_GOTIP.

    if ( wifi.sta.status () == wifi.STA_GOTIP ) then
    
        tmr.stop ( nodeConfig.timer.wifiLoop );
        
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

function M.start ()

    print ( "[MQTT] start app=" .. nodeConfig.app  );
    appNode = require ( nodeConfig.app );
    
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
                    mqttClient:publish ( nodeConfig.topic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], 0, nodeConfig.mqtt.retain, -- qos, retain                                    
                        function ( client )
                            if ( appNode.periodic ) then
                                appNode.periodic ( mqttClient, nodeConfig.topic );
                            end
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