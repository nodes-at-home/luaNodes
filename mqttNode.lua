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

M.appNode = nil;    -- application callbacks
M.client = nil;     -- mqtt client

local retain = espConfig.node.retain;

local wifiLoopTimer = espConfig.node.timer.wifiLoop;
local wifiLoopPeriod = espConfig.node.timer.wifiLoopPeriod;

local periodicTimmer = espConfig.node.timer.periodic;
local periodicPeriod = espConfig.node.timer.periodicPeriod;

local traceSocket;
local traceServerIp = espConfig.node.trace.ip;
local traceServerPort = espConfig.node.trace.port;

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
        print ( "[WIFI] network=" .. wifi.sta.getip () );
        print ( "[WIFI] mac=" .. wifi.sta.getmac () );
    
        -- Setup MQTT client and events
        if ( M.client == nil ) then
            local mqttClientName = wifi.sta.gethostname () .. "-" .. espConfig.node.class .. "-" .. espConfig.node.type .. "-" .. espConfig.node.location;
            M.client = mqtt.Client ( mqttClientName, 120, "", "" ); -- ..., keep_alive_time, username, password
        end

        print ( "[MQTT] connecting to " .. espConfig.node.mqttBroker );

        -- this is never called, because the last registration wins
        -- M.client:on ( "connect", 
            -- function ( client )
                -- print ( "[MQTT] CONNECTED" );
                -- M.appNode.connect ();
            -- end
        -- );
            
        M.client:on ( "message", 
            function ( client, topic, payload )
                print ( "[MQTT] message received topic=" .. topic .." payload=" .. (payload == nil and "***nothing***" or payload) );
                if ( payload ) then
                    -- check for update
                    if ( topic == espConfig.node.topic .. "/service/update" ) then 
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
                                print ( "[UPDATE] update url write success=" .. success );
                                file.close ();
                                if ( success ) then
                                    print ( "[UPDATE] restart for second step" );
                                    node.restart ();
                                end
                            end
                        end
                    elseif ( topic == espConfig.node.topic .. "/service/trace" ) then
                        if ( payload == "ON" ) then
                            if ( not traceSocket ) then
                                traceSocket = net.createConnection ( net.TCP, 0 ); -- no secure
                                print ( "[TRACE] connecting to " .. traceServerIp .. ":" .. traceServerPort );
                                traceSocket:connect ( traceServerPort, traceServerIp );
                                print ( "[TRACE] connection " .. traceSocket:getpeer () );
                                traceSocket:on ( "connection", 
                                    function ( socket, errorCode )
                                        socket:send ( node.chipid () .. "#***" .. node.chipid () .. " is tracing ***\n"  );
                                        -- redirect
                                        node.output ( 
                                            function ( s )
                                                socket:send ( node.chipid () .. "#" .. s .. "\n" );
                                            end,
                                            1               -- additional serial out  
                                        ); 
                                    end 
                                );
                                traceSocket:on ( "disconnection",
                                    function ( socket, errCode )
                                        traceSocket = nil;
                                        node.output ( nil );
                                    end
                                );
                            end  
                        else
                            if ( traceSocket ) then
                                traceSocket:send ( node.chipid () .. "#***" .. node.chipid () .. "tracing ENDS ***\n"  );
                                traceSocket:close ();
                                traceSocket = nil;
                            end
                        end 
                    else
                        M.appNode.message ( client, topic, payload );
                    end
                end
            end
        );
            
        M.client:on ( "offline", 
            function ( client )
                print ( "[MQTT] offline" );
                local restartMqtt = M.appNode.offline ( client );
                if ( restartMqtt ) then
                    print ( "[MQTT] restart connection" );
                    tmr.alarm ( wifiLoopTimer, wifiLoopPeriod, tmr.ALARM_AUTO, function () wifiLoop() end ) -- timer_id, interval_ms, mode
                end
            end
        );
        
        local result = M.client:connect( espConfig.node.mqttBroker , 1883, 0, 0, -- broker, port, secure, autoreconnect
        
            function ( client )
            
                -- Stop the loop only if connected
                tmr.stop ( wifiLoopTimer );

                print ( "[MQTT] connected to MQTT Broker" )
                print ( "[MQTT] node=" .. espConfig.node.topic );
                
                -- subscribe to update topic
                local topic = espConfig.node.topic .. "/service/update";
                print ( "[MQTT] subscribe to topic=" .. topic );
                client:subscribe ( topic, 2, -- ..., qos: receive update only once
                    function ( client )
                        local version = espConfig.node.version;
                        print ( "[MQTT] send <" .. version .. "> to topic=" .. espConfig.node.topic );
                        client:publish ( espConfig.node.topic, version, 0, retain, -- ..., qos, retain
                            function ( client )
                                print ( "[MQTT] send voltage" );
                                client:publish ( espConfig.node.topic .. "/value/voltage", util.createJsonValueMessage ( adc.readvdd33 (), "mV" ), 0, retain, -- qos, retain
                                    function ( client )
                                        M.appNode.connect ( client, espConfig.node.topic );
                                        -- subscribe to all topics based on base topic of the node
                                        local topic = espConfig.node.topic .. "/+";
                                        print ( "[MQTT] subscribe to topic=" .. topic );
                                        client:subscribe ( topic, 0, -- ..., qos
                                            function ( client )
                                                local topic = espConfig.node.topic .. "/service/+";
                                                print ( "[MQTT] subscribe to topic=" .. topic );
                                                client:subscribe ( topic, 0, -- ..., qos
                                                    function ( client )
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
        print ( "[MQTT] connect result=" .. result );
    else
        print ( "[WIFI] Connecting..." );
    end
    
end

local function noop () return false; end

local function initAppNode ( app )

    if ( app.version == nil ) then app.version = "undefined"; end
    if ( app.connect == nil ) then app.connect = noop; end
    if ( app.offline == nil ) then app.offline = noop; end
    if ( app.message == nil ) then app.message = noop; end
    if ( app.periodic == nil ) then app.periodic = noop; end
    
    M.appNode = app;
    
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
    tmr.alarm ( wifiLoopTimer, wifiLoopPeriod, tmr.ALARM_AUTO, function () wifiLoop() end ); -- timer_id, interval_ms, mode
    if ( periodicTimmer ) then
        tmr.alarm ( periodicTimmer, periodicPeriod, tmr.ALARM_AUTO, -- timer_id, interval_ms, mode
            function () 
                print ( "[MQTT] send voltage" );
                M.client:publish ( espConfig.node.topic .. "/value/voltage", util.createJsonValueMessage ( adc.readvdd33 (), "mV" ), 0, retain,  -- qos, retain
                    function ( client )
                        M.appNode.periodic ( M.client, espConfig.node.topic );
                    end
                );
            end 
        );
    end

end
  
-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------