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

local rssiTopic = "nodes@home/rssi/" .. node.chipid ();

local retain = nodeConfig.mqtt.retain;
local qos = nodeConfig.mqtt.qos or 1;

local app = nodeConfig.app;

local appNode = nil;
local mqttClient = nil;

local startTelnet;

local periodicTimer = tmr.create ();
local wifiLoopTimer = tmr.create ();

local isWifiConnected = false;

----------------------------------------------------------------------------------------
-- private

local apmac;

local function connect ( client )

    print ( "[MQTT] connect: baseTopic=" .. baseTopic );
    
    local version = nodeConfig.version;
    print ( "[MQTT] connect: send <" .. version .. "> to topic=" .. baseTopic );
    client:publish ( baseTopic, version, qos, retain,
        function ( client )
            local voltage = -1;
            if ( nodeConfig.appCfg.useAdc ) then
                    local scale = nodeConfig.appCfg.adcScale or 4200;
                    print ( "[MQTT] adcScale=" .. scale );           
                    voltage = adc.read ( 0 ) / 1023 * scale; -- mV
            else
                voltage = adc.readvdd33 ();
            end
            print ( "[MQTT] connect: send voltage=" .. voltage );
            client:publish ( baseTopic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], qos, retain,                                    
                function ( client )
                    local s = app .. "@" .. nodeConfig.location;
                    print ( "[MQTT] connect: send <" ..  s .. "> to " .. configTopic );
                    client:publish ( configTopic, s, qos, retain,
                        function ( client )
                            local str = sjson.encode ( nodeConfig );
                            local topic = configTopic .. "/state";
                            print ( "[MQTT] connect: send config to " .. topic .. " -> " .. str );
                            client:publish ( topic, str, qos, retain,
                                function ( client )
                                    print ( "[MQTT] connect: send mqtt online state to " .. mqttTopic );
                                    client:publish ( mqttTopic, "online", qos, retain,
                                        function ( client )
                                            if ( appNode.start ) then 
                                                appNode.start ( client, baseTopic ); 
                                            end
                                            -- subscribe to service topics
                                            local topic = baseTopic .. "/service/+";
                                            print ( "[MQTT] connect: subscribe to topic=" .. topic );
                                            client:subscribe ( topic, qos,
                                                function ( client )
                                                    -- subscribe to all topics based on base topic of the node
                                                    local topic = baseTopic .. "/+";
                                                    print ( "[MQTT] connect: subscribe to topic=" .. topic );
                                                    client:subscribe ( topic, qos,
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

    print ( "[MQTT] subscribeConfig: topic=" .. configJsonTopic );
    
    client:subscribe ( configJsonTopic, qos,
        function ( client )
            -- reset topic
            local topic = baseTopic .. "/service/config"
            print ( "[MQTT] subscribeConfig: reset topic=" .. topic );
            client:publish ( topic, "", qos, retain,
                function ( client )
                end
            );
        end
    );

end

local function receiveConfig ( client, payload )

    print ( "[MQTT] receiveConfig:" )
    
    local ok, json = pcall ( sjson.decode, payload );
    print ( "json.chipd=" .. json.chipid .. " node.chipid=" .. node.chipid () .. " tostring=" .. tostring ( node.chipid () ) );
    if ( ok and (json.chipid == node.chipid ()) ) then
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
                print ( "[MQTT] aupdate: already updated with " .. payload );
                forceUpdate = false;
             end
        end
    end
    
    -- start update procedure
    if ( forceUpdate ) then
        print ( "[MQTT] update: start heap=" .. node.heap () )
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
                print ( "[MQTT] message: received topic=" .. topic .." payload=" .. tostring ( payload ) );
                if ( payload ) then
                    -- check for update
                    local _, pos = topic:find ( baseTopic );
                    if ( pos ) then
                        local subtopic = topic:sub ( pos + 1 );
                        print ( "[MQTT] message: subtopic=" .. subtopic );
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
                    elseif ( topic == configJsonTopic ) then
                        receiveConfig ( client, payload );
                    end
                end
            end
        );
        
        mqttClient:on ( "offline", 
            function ( client )
                print ( "[MQTT] offline:" );
                periodicTimer:stop (); 
                if ( not startTelnet and appNode.offline and appNode.offline ( client ) ) then
                    print ( "[MQTT] offline: restart connection" );
                    wifiLoopTimer:start ();
                end
            end
        );

    end
    
    mqttClient:lwt ( mqttTopic, "offline", qos, retain );

    local result;
    while not pcall (
        function ()       
            local broker = nodeConfig.mqtt.broker;
            print ( "[MQTT] startMqtt: connect to broker=" .. broker );
            result = mqttClient:connect( broker, 1883, 0, 0, -- broker, port, secure, autoreconnect
                function ( client )
                    periodicTimer:start (); 
                    connect ( client );
                end,        
                function ( client, reason ) 
                    print ( "[MQTT] startMqtt: not connected reason=" .. reason );
                    wifiLoopTimer:start ();
                end
            )
        end
    )
    do
        print ( "[MQTT] retry connecting" );
    end

    print ( "[MQTT] startMqtt: connect result=" .. tostring ( result ) );
    if ( not result ) then
        wifiLoopTimer:start ();
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
    
        wifiLoopTimer:stop ();
        
        print ( "[WIFI] wifiLoop: dnsname=" .. wifi.sta.gethostname () );
        print ( "[WIFI] wifiLoop: network=" .. (wifi.sta.getip () and wifi.sta.getip () or "NO_IP") );
        print ( "[WIFI] wifiLoop: mac=" .. wifi.sta.getmac () );
        local rssi = wifi.sta.getrssi ();
        print ( "[WIFI] wifiLoop: rssi=" .. rssi );
        
        local ssid, pwd, _, mac = wifi.sta.getconfig ( false ); -- old sytle, true: returns table
        print ( "[WIFI] wifiLoop: ssid=" .. tostring ( ssid ) );
        --print ( "[WIFI] wifiLoop: pwd=" .. tostring ( pwd ) );
        print ( "[WIFI] wifiLoop: apmac=" .. tostring ( mac ) );
        
        apmac = mac;
        nodeConfig.wifi.rssi= rssi;
        nodeConfig.wifi.apmac = mac;  
        
        if ( nodeConfig.trace and nodeConfig.trace.onStartup ) then
            print ( "[WIFI] wifiLoop: start with trace" );
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
            print ( "[WIFI] wifiLoop: start with no trace" );
            startMqtt ();
        end

    else

        print ( "[WIFI] wifiLoop: Connecting..." );

    end
    
end

--------------------------------------------------------------------
-- public

function M.start ()

    print ( "[MQTTWIFI] start: app=" .. app  );
    appNode = require ( app );
    
        -- Connect to the wifi network
    print ( "[WIFI] start: connecting to " .. wifiCredential.ssid );
    wifi.setmode ( wifi.STATION, true ); -- save to flash
    local phymode = nodeConfig.phymode and wifi [nodeConfig.phymode] or wifi.PHYMODE_N;
    wifi.setphymode ( phymode );
    print ( "[WIFI] start: phymode=" .. wifi.getphymode () .. " (1=B,2=G,3=N) country=" .. wifi.getcountry ().country );    
    wifi.nullmodesleep ( false ); 
    print ( "[WIFI] start: nullmodesleep=" .. tostring ( wifi.nullmodesleep () ) );    
    local configok = wifi.sta.config (
        { 
            ssid = wifiCredential.ssid, 
            pwd = wifiCredential.password,
            auto = true,
            save = true 
        }
    );
    print ( "[WIFI] start: wifi config loaded=" .. tostring ( configok ) );    
    --wifi.sta.connect ();
    
    local wificfg = nodeConfig.wifi;
    if ( wificfg ) then
        print ( "[STARTUP] start: wifi fix ip=" .. wificfg.ip );
        wifi.sta.setip ( wificfg );
    end
    
    -- loop to wait up to connected to wifi
    wifiLoopTimer:alarm ( nodeConfig.timer.wifiLoopPeriod, tmr.ALARM_AUTO, wifiLoop ); -- timer_id, interval_ms, mode
    
    if ( nodeConfig.timer.periodicPeriod ) then
        periodicTimer:register ( nodeConfig.timer.periodicPeriod, tmr.ALARM_AUTO, -- timer_id, interval_ms, mode
            function ()
                if ( mqttClient ) then 
                    local voltage = -1;
                    if ( nodeConfig.appCfg.useAdc ) then
                        local scale = nodeConfig.appCfg.adcScale or 4200;
                        print ( "[MQTT] start: adcScale=" .. scale );           
                        voltage = adc.read ( 0 ) / 1023 * scale; -- mV
                    else
                        voltage = adc.readvdd33 ();
                    end
                    local rssi = wifi.sta.getrssi ();
                    print ( "[MQTT] start: send voltage=" .. voltage .. " rssi=" .. rssi );
                    mqttClient:publish ( baseTopic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], qos, retain,
                        function ( client )                                    
                            client:publish ( rssiTopic, 
                                [[{"chipid":]] .. node.chipid () .. [[,"topic":"]] .. baseTopic .. [[","apmac":"]] .. apmac .. [[","value":]] .. rssi .. [[, "unit":"dBm"}]], 
                                qos, retain,                                    
                                function ( client )
                                    if ( appNode.periodic ) then
                                        appNode.periodic ( mqttClient, baseTopic );
                                    end
                                end
                            );
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