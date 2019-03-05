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

local appNode = nil;    -- application callbacks
local mqttClient = nil;     -- mqtt client

----------------------------------------------------------------------------------------
-- private

local function connect ( client )

    print ( "[MQTT] connected to MQTT Broker" )
    print ( "[MQTT] node=" .. nodeConfig.topic );
    
    local version = nodeConfig.version;
    print ( "[MQTT] send <" .. version .. "> to topic=" .. nodeConfig.topic );
    client:publish ( nodeConfig.topic, version, 0, nodeConfig.mqtt.retain, -- ..., qos, retain
        function ( client )
            local voltage = -1;
            if ( nodeConfig.appCfg.useAdc ) then
                    local scale = nodeConfig.appCfg.adcScale or 4200;
                    print ( "[MQTT] adcScale=" .. scale );           
                    voltage = adc.read ( 0 ) / 1023 * scale; -- mV
            else
                voltage = adc.readvdd33 ();
            end
            print ( "[MQTT] send voltage=" .. voltage );
            client:publish ( nodeConfig.topic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], 0, nodeConfig.mqtt.retain, -- qos, retain                                    
                function ( client )
                    local topic = "nodes@home/config/" .. node.chipid ();
                    print ( "[MQTT] send config app " ..  nodeConfig.app .. " to " .. topic );
                    client:publish ( topic, nodeConfig.app .. "@" .. nodeConfig.location, 0, 1, -- ..., qos, retain
                        function ( client )
                            local str = sjson.encode ( nodeConfig );
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
                                                    if ( appNode.connect ) then
                                                        appNode.connect ( client, nodeConfig.topic );
                                                    end
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

end

local function subscribeConfig ( client )

    print ( "[MQTT] subscribeConfig:" )
    
    local topic = "nodes@home/config/" .. node.chipid () .. "/json";
    print ( "[MQTT] subscribeConfig: topic=" .. topic );
    client:subscribe ( topic, 0, -- ..., qos
        function ( client )
            -- reset topic
            local topic = nodeConfig.topic .. "/service/config"
            print ( "[[MQTT] subscribeConfig: topic=" .. topic );
            client:publish ( topic, "", 0, 1, -- ..., qos, retain
                function ( client )
                end
            );
        end
    );

end

local function receiveConfig ( client, payload )

    print ( "[MQTT] receiveConfig:" )
    
    local ok, json = pcall ( sjson.decode, payload );
    if ( ok and json.chipid == node.chipid () ) then
        print ( "[MQTT] receiveConfig: found same chipid " .. node.chipid () );
        if ( file.open ( "espConfig_mqtt.json", "w" ) ) then
            file.write ( payload );
            file.close ();
            print ( "[MQTT] receiveConfig: restarting after config save")
            if ( trace ) then 
                trace.off ( node.restart ); 
            else
                node.restart ();
            end
        end
    end

end

local function update ( payload )

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
    
    -- start update procedure
    if ( forceUpdate ) then
        print ( "[MQTT] update: start heap: " .. node.heap () )
        if ( file.open ( "update.url", "w" ) ) then
            local success = file.write ( payload );
            print ( "[MQTT] update: url write success=" .. tostring ( success ) );
            file.close ();
            if ( success ) then
                print ( "[MQTT] update:  restart for second step" );
                if ( trace ) then 
                    print ( "[MQTT] update: ... wait ..." );
                    trace.off ( node.restart ); 
                else
                    node.restart ();
                end
            end
        end
    end

end

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
                            update ( payload ); 
                        elseif ( subtopic == "/service/trace" ) then
                            require ( "trace" );
                            if ( payload == "ON" ) then 
                                trace.on ();
                            else 
                                trace.off ();
                            end
                        elseif ( subtopic == "/service/config" ) then
                            subscribeConfig ( client );
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
                        receiveConfig ( client, payload );
                    end
                end
            end
        );
        
        mqttClient:on ( "offline", 
            function ( client )
                print ( "[MQTT] offline" );
                tmr.stop ( nodeConfig.timer.periodic ); 
                if ( appNode.offline and appNode.offline ( client ) ) then
                    print ( "[MQTT] restart connection" );
                    tmr.start ( nodeConfig.timer.wifiLoop ) -- timer_id
                end
            end
        );

    end

    local result;
    while not pcall (
        function ()        
            result = mqttClient:connect( nodeConfig.mqtt.broker , 1883, 0, 0, -- broker, port, secure, autoreconnect
                function ( client )
                    tmr.start ( nodeConfig.timer.periodic ); 
                    connect ( client );
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
        
        local t = nodeConfig.trace and nodeConfig.trace.onStartup;
        print ( "[MQTT] trace.onStartup=" .. tostring ( t ) ); 
        if ( t ) then
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
        tmr.register ( nodeConfig.timer.periodic, nodeConfig.timer.periodicPeriod, tmr.ALARM_AUTO, -- timer_id, interval_ms, mode
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