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

require ( "util" );
                
-------------------------------------------------------------------------------
--  Settings

appNode = nil;    -- application callbacks
mqttClient = nil;     -- mqtt client

----------------------------------------------------------------------------------------
-- private

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
                        -- and there was no update with this url before
                        local forceUpdate = true;
                        if ( file.exists ( "old_update.url" ) ) then
                            if ( file.open ( "old_update.url" ) ) then
                                local url = file.readline ();
                                file.close ();
                                if ( url and url == payload ) then
                                    print ( "[UPDATE] already updated with " .. payload );
                                    forceUpdate = false;
                                 end
                            end
                        end
                        if ( forceUpdate ) then
                            -- start update procedure
                            print ( "[UPDATE] start heap: " .. node.heap () )
                            if ( file.open ( "update.url", "w" ) ) then
                                local success = file.write ( payload );
                                print ( "[UPDATE] update url write success=" .. tostring ( success ) );
                                file.close ();
                                if ( success ) then
                                    print ( "[UPDATE] restart for second step" );
                                    if ( trace ) then 
                                        print ( "[UPDATE] ... wait ..." );
                                        trace.off ( node.restart ); 
                                    else
                                        node.restart ();
                                    end
                                end
                            end
                        end
                    elseif ( topic == nodeConfig.topic .. "/service/trace" ) then
                        require ( "trace" );
                        if ( payload == "ON" ) then 
                            trace.on ();
                        else 
                            trace.off ();
                        end
                    elseif ( topic == nodeConfig.topic .. "/service/config" ) then
                        print ( "[CONFIG] topic=" .. topic .. " payload=" .. payload );
                        local topic = "nodes@home/config/" .. node.chipid ();
                        print ( "[CONFIG] subscribe to topic=" .. topic );
                        client:subscribe ( topic, 0, -- ..., qos
                            function ( client )
                                -- reset topic
                                local topic = nodeConfig.topic .. "/service/config"
                                print ( "[CONFIG] unsubscribe to topic=" .. topic );
                                client:publish ( topic, "", 0, 1, -- ..., qos, retain
                                    function ( client )
                                    end
                                );
                            end
                        );
                    elseif ( topic == "nodes@home/config/" .. node.chipid () .. "/json" ) then
                        print ( "[CONFIG] topic=" .. topic .. " payload=" .. payload );
                        local json = cjson.decode ( payload );
                        if ( json.chipid == node.chipid () ) then
                            print ( "[CONFIG] found same chipid " .. node.chipid () );
                            if ( file.open ( "espConfig_local.json", "w" ) ) then
                                file.write ( payload );
                                print ( "[CONFIG] restarting after config save")
                                if ( trace ) then 
                                    trace.off ( node.restart ); 
                                else
                                    node.restart ();
                                end
                            end
                        end
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
        
        local result = mqttClient:connect( nodeConfig.mqttBroker , 1883, 0, 0, -- broker, port, secure, autoreconnect
        
            function ( client )
            
                -- Stop the loop only if connected
                tmr.stop ( nodeConfig.timer.wifiLoop );

                print ( "[MQTT] connected to MQTT Broker" )
                print ( "[MQTT] node=" .. nodeConfig.topic );
                
                local version = nodeConfig.version;
                print ( "[MQTT] send <" .. version .. "> to topic=" .. nodeConfig.topic );
                client:publish ( nodeConfig.topic, version, 0, nodeConfig.retain, -- ..., qos, retain
                    function ( client )
                        print ( "[MQTT] send voltage" );
                        client:publish ( nodeConfig.topic .. "/value/voltage", util.createJsonValueMessage ( adc.readvdd33 (), "mV" ), 0, nodeConfig.retain, -- qos, retain
                            function ( client )
                                local topic = "nodes@home/config/" .. node.chipid ();
                                print ( "[MQTT] send config app " ..  nodeConfig.app .. " to " .. topic );
                                client:publish ( topic, nodeConfig.app .. "@" .. nodeConfig.location, 0, 1, -- ..., qos, retain
                                    function ( client )
                                        local str = cjson.encode ( nodeConfig );
                                        local topic = "nodes@home/config/" .. node.chipid () .. "/state";
                                        print ( "[MQTT] send config to " .. topic .. str );
                                        client:publish ( topic, str, 0, 1, -- ..., qos, retain
                                            function ( client )
                                                if ( appNode.start ) then 
                                                    appNode.start ( client, nodeConfig.topic ); 
                                                end
                                                -- subscribe to service topics
                                                local topic = nodeConfig.topic .. "/service/+";
                                                print ( "[MQTT] subscribe to topic=" .. topic );
                                                client:subscribe ( topic, 0, -- ..., qos
                                                    function ( client )
                                                        -- subscribe to all topics based on base topic of the node
                                                        local topic = nodeConfig.topic .. "/+";
                                                        print ( "[MQTT] subscribe to topic=" .. topic );
                                                        client:subscribe ( topic, 0, -- ..., qos
                                                            function ( client )
                                                                appNode.connect ( client, nodeConfig.topic );
                                                            end
                                                        );
                                                    end
                                                );
                                            end
                                        );
                                    end
                                );
                            end
                        );
                    end
                );
                
            end,

            function ( client, reason ) 
                print ( "[MQTT] not connected reason=" .. reason );
            end
        
        );
        print ( "[MQTT] connect result=" .. tostring ( result ) );
    else
        print ( "[WIFI] Connecting..." );
    end
    
end

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

--------------------------------------------------------------------
-- public

function M.start ( app )

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
                print ( "[MQTT] send voltage" );
                mqttClient:publish ( nodeConfig.topic .. "/value/voltage", util.createJsonValueMessage ( adc.readvdd33 (), "mV" ), 0, nodeConfig.retain,  -- qos, retain
                    function ( client )
                        appNode.periodic ( mqttClient, nodeConfig.topic );
                    end
                );
            end 
        );
    end
    
    package.loaded [moduleName] = nil;

end
  
-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------