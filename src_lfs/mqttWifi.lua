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

local baseTopic = nodeConfig.topic;
local mqttTopic = baseTopic .. "/state/mqtt";

local configTopic = "nodes@home/config/" .. node.chipid ();
local configJsonTopic = configTopic .. "/json";

local retain = nodeConfig.mqtt.retain;

local app = nodeConfig.app;

local appNode = nil;    -- application callbacks
local mqttClient = nil;     -- mqtt client

local startTelnet;

----------------------------------------------------------------------------------------
-- private

local function connect ( client )

    print ( "[MQTTWIFI] connect: baseTopic=" .. baseTopic );
    
    local version = nodeConfig.version;
    print ( "[MQTTWIFI] connect: send <" .. version .. "> to topic=" .. baseTopic );
    client:publish ( baseTopic, version, 0, retain, -- ..., qos, retain
        function ( client )
            local voltage = -1;
            if ( nodeConfig.appCfg.useAdc ) then
                    local scale = nodeConfig.appCfg.adcScale or 4200;
                    print ( "[MQTTWIFI] adcScale=" .. scale );           
                    voltage = adc.read ( 0 ) / 1023 * scale; -- mV
            else
                voltage = adc.readvdd33 ();
            end
            print ( "[MQTTWIFI] connect: send voltage=" .. voltage );
            client:publish ( baseTopic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], 0, retain, -- qos, retain                                    
                function ( client )
                    local s = app .. "@" .. nodeConfig.location;
                    print ( "[MQTTWIFI] connect: send <" ..  s .. "> to " .. configTopic );
                    client:publish ( configTopic, s, 0, retain, -- ..., qos, retain
                        function ( client )
                            local str = sjson.encode ( nodeConfig );
                            local topic = configTopic .. "/state";
                            print ( "[MQTTWIFI] connect: send config to " .. topic .. " -> " .. str );
                            client:publish ( topic, str, 0, retain, -- ..., qos, retain
                                function ( client )
                                    print ( "[MQTTWIFI] connect: send mqtt online state to " .. mqttTopic );
                                    client:publish ( mqttTopic, "online", 0, retain, -- ..., qos, retain
                                        function ( client )
                                            if ( appNode.start ) then 
                                                appNode.start ( client, baseTopic ); 
                                            end
                                            -- subscribe to service topics
                                            local topic = baseTopic .. "/service/+";
                                            print ( "[MQTTWIFI] connect: subscribe to topic=" .. topic );
                                            client:subscribe ( topic, 0, -- ..., qos
                                                function ( client )
                                                    -- subscribe to all topics based on base topic of the node
                                                    local topic = baseTopic .. "/+";
                                                    print ( "[MQTTWIFI] connect: subscribe to topic=" .. topic );
                                                    client:subscribe ( topic, 0, -- ..., qos
                                                        function ( client )
                                                            if ( appNode.connect ) then
                                                                appNode.connect ( client, baseTopic );
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
    );

end

local function subscribeConfig ( client )

    print ( "[MQTTWIFI] subscribeConfig: topic=" .. configJsonTopic );
    
    client:subscribe ( topic, 0, -- ..., qos
        function ( client )
            -- reset topic
            local topic = baseTopic .. "/service/config"
            print ( "[MQTTWIFI] subscribeConfig: reset topic=" .. topic );
            client:publish ( topic, "", 0, retain, -- ..., qos, retain
                function ( client )
                end
            );
        end
    );

end

local function receiveConfig ( client, payload )

    print ( "[MQTTWIFI] receiveConfig:" )
    
    local ok, json = pcall ( sjson.decode, payload );
    if ( ok and json.chipid == node.chipid () ) then
        print ( "[MQTTWIFI] receiveConfig: found same chipid " .. node.chipid () );
        if ( file.open ( "espConfig_mqtt.json", "w" ) ) then
            file.write ( payload );
            file.close ();
            print ( "[MQTTWIFI] receiveConfig: restarting after config save")
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
                print ( "[MQTTWIFI] aupdate: already updated with " .. payload );
                forceUpdate = false;
             end
        end
    end
    
    -- start update procedure
    if ( forceUpdate ) then
        print ( "[MQTTWIFI] update: start heap=" .. node.heap () )
        if ( file.open ( "update.url", "w" ) ) then
            local success = file.write ( payload );
            print ( "[MQTTWIFI] update: url write success=" .. tostring ( success ) );
            file.close ();
            if ( success ) then
                print ( "[MQTTWIFI] update:  restart for second step" );
                if ( trace ) then 
                    print ( "[MQTTWIFI] update: ... wait ..." );
                    trace.off ( node.restart ); 
                else
                    node.restart ();
                end
            end
        end
    end

end

local function startMqtt ()
        
    -- Setup MQTT client and events
    if ( mqttClient == nil ) then

        local mqttClientName = wifi.sta.gethostname () .. "-" .. nodeConfig.class .. "-" .. nodeConfig.type .. "-" .. nodeConfig.location;
        mqttClient = mqtt.Client ( mqttClientName, nodeConfig.mqtt.keepAliveTime, "", "" ); -- ..., keep_alive_time, username, password

        -- this is never called, because the last registration wins
        -- mqttClient:on ( "connect", 
            -- function ( client )
                -- print ( "[MQTTWIFI] CONNECTED" );
                -- appNode.connect ();
            -- end
        -- );
    
        mqttClient:on ( "message", 
            function ( client, topic, payload )
                print ( "[MQTTWIFI] message: received topic=" .. topic .." payload=" .. (payload == nil and "***nothing***" or payload) );
                if ( payload ) then
                    -- check for update
                    local _, pos = topic:find ( baseTopic );
                    if ( pos ) then
                        local subtopic = topic:sub ( pos + 1 );
                        print ( "[MQTTWIFI] message: subtopic=" .. subtopic );
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
                        elseif ( subtopic == "/service/telnet" ) then
                            startTelnet = true;
                            require ( "telnet" ):open ( wifiCredential.ssid, wifiCredential.password );
                        elseif ( subtopic == "/service/restart" ) then
                            print ( "[MQTTWIFI] RESTARTING")
                            if ( trace ) then 
                                print ( "[MQTTWIFI] ... wait ..." );
                                trace.off ( node.restart ); 
                            else
                                node.restart ();
                            end
                        else
                            if ( appNode.message ) then
                                appNode.message ( client, topic, payload );
                            end
                        end
                    elseif ( subtopic == configJsonTopic ) then
                        receiveConfig ( client, payload );
                    end
                end
            end
        );
        
        mqttClient:on ( "offline", 
            function ( client )
                print ( "[MQTTWIFI] offline:" );
                tmr.stop ( nodeConfig.timer.periodic ); 
                if ( not startTelnet and appNode.offline and appNode.offline ( client ) ) then
                    print ( "[MQTTWIFI] offline: restart connection" );
                    tmr.start ( nodeConfig.timer.wifiLoop ) -- timer_id
                end
            end
        );

    end
    
    mqttClient:lwt ( mqttTopic, "offline", 0, retain ); -- qos, retain

    local result;
    while not pcall (
        function ()        
            result = mqttClient:connect( nodeConfig.mqtt.broker , 1883, 0, 0, -- broker, port, secure, autoreconnect
                function ( client )
                    tmr.start ( nodeConfig.timer.periodic ); 
                    connect ( client );
                end,        
                function ( client, reason ) 
                    print ( "[MQTTWIFI] startMqtt: not connected reason=" .. reason );
                    tmr.start ( nodeConfig.timer.wifiLoop );
                end
            )
        end
    )
    do
        print ( "[MQTTWIFI] retry connecting" );
    end

    print ( "[MQTTWIFI] startMqtt: connect result=" .. tostring ( result ) );
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
        
        print ( "[MQTTWIFI] wifiLoop: dnsname=" .. wifi.sta.gethostname () );
        print ( "[MQTTWIFI] wifiLoop: network=" .. (wifi.sta.getip () and wifi.sta.getip () or "NO_IP") );
        print ( "[MQTTWIFI] wifiLoop: mac=" .. wifi.sta.getmac () );

        if ( nodeConfig.trace and nodeConfig.trace.onStartup ) then
            print ( "[MQTTWIFI] wifiLoop: start with trace" );
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
            print ( "[MQTTWIFI] wifiLoop: start with no trace" );
            startMqtt ();
        end

    else

        print ( "[MQTTWIFI] wifiLoop: Connecting..." );

    end
    
end

--------------------------------------------------------------------
-- public

function M.start ()

    print ( "[MQTTWIFI] start: app=" .. app  );
    appNode = require ( app );
    
    -- loop to wait up to connected to wifi
    tmr.alarm ( nodeConfig.timer.wifiLoop, nodeConfig.timer.wifiLoopPeriod, tmr.ALARM_AUTO, wifiLoop ); -- timer_id, interval_ms, mode
    
    if ( nodeConfig.timer.periodic ) then
        tmr.register ( nodeConfig.timer.periodic, nodeConfig.timer.periodicPeriod, tmr.ALARM_AUTO, -- timer_id, interval_ms, mode
            function ()
                if ( mqttClient ) then 
                    local voltage = -1;
                    if ( nodeConfig.appCfg.useAdc ) then
                        local scale = nodeConfig.appCfg.adcScale or 4200;
                        print ( "[MQTTWIFI] start: adcScale=" .. scale );           
                        voltage = adc.read ( 0 ) / 1023 * scale; -- mV
                    else
                        voltage = adc.readvdd33 ();
                    end
                    print ( "[MQTTWIFI] start: send voltage=" .. voltage );
                    mqttClient:publish ( baseTopic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], 0, retain, -- qos, retain                                    
                        function ( client )
                            if ( appNode.periodic ) then
                                appNode.periodic ( mqttClient, baseTopic );
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