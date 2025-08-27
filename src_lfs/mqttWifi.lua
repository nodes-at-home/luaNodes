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

local logger = require ( "syslog" ).logger ( moduleName );

local tmr, node, adc, wifi, sjson, file, syslog, mqtt = tmr, node, adc, wifi, sjson, file, syslog, mqtt;

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

----------------------------------------------------------------------------------------
-- private

local function connect ( client )

    logger:info ( "connect: baseTopic=" .. baseTopic );

    local version = nodeConfig.version;
    logger:debug ( "connect: send <" .. version .. "> to topic=" .. baseTopic );
    client:publish ( baseTopic, version, qos, retain,
        function ( client )
            local voltage = -1;
            local rssi = 0;
            if ( not is_ESP32 ) then
                if ( nodeConfig.appCfg.useAdc ) then
                        local scale = nodeConfig.appCfg.adcScale or 4200;
                        logger:debug ( "adcScale=" .. scale );
                        voltage = adc.read ( 0 ) / 1023 * scale; -- mV
                else
                    voltage = adc.readvdd33 ();
                end
                rssi = wifi.sta.getrssi ();
            end
            logger:debug ( "connect: send voltage=" .. voltage .. " rssi=" .. rssi );
            client:publish ( baseTopic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], qos, retain,
                function ( client )
                    client:publish ( rssiTopic,
                        [[{"chipid":]] .. node.chipid () .. [[,"topic":"]] .. baseTopic .. [[","apmac":"]] .. nodeConfig.wifi.apmac .. [[","value":]] .. rssi .. [[, "unit":"dBm"}]],
                        qos, retain,
                        function ( client )
                            local s = app .. "@" .. nodeConfig.location;
                            logger:debug ( "connect: send <" ..  s .. "> to " .. configTopic );
                            client:publish ( configTopic, s, qos, retain,
                                function ( client )
                                    local str = sjson.encode ( nodeConfig );
                                    local topic = configTopic .. "/state";
                                    logger:debug ( "connect: send config to " .. topic .. " -> " .. str );
                                    client:publish ( topic, str, qos, retain,
                                        function ( client )
                                            logger:debug ( "connect: send mqtt online state to " .. mqttTopic );
                                            client:publish ( mqttTopic, "online", qos, retain,
                                                function ( client )
                                                    if ( appNode.start ) then
                                                        appNode.start ( client, baseTopic );
                                                    end
                                                    -- TODO use table to subscibe
                                                    -- subscribe to service topics
                                                    local topic = baseTopic .. "/service/+";
                                                    logger:debug ( "connect: subscribe to topic=" .. topic );
                                                    client:subscribe ( topic, qos,
                                                        function ( client )
                                                            -- subscribe to all topics based on base topic of the node
                                                            local topic = baseTopic .. "/+";
                                                            logger:debug ( "connect: subscribe to topic=" .. topic );
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
    );

end

local function subscribeConfig ( client )

    logger:info ( "subscribeConfig: topic=" .. configJsonTopic );

    client:subscribe ( configJsonTopic, qos,
        function ( client )
            -- reset topic
            local topic = baseTopic .. "/service/config"
            logger:debug ( "subscribeConfig: reset topic=" .. topic );
            client:publish ( topic, "", qos, retain,
                function ( client )
                end
            );
        end
    );

end

local function receiveConfig ( client, payload )

    logger:info ( "receiveConfig:" )

    -- TODO check for file vs. io

    local ok, json = pcall ( sjson.decode, payload );
    logger:debug ( "receiveConfig: json.chipd=" .. json.chipid .. " node.chipid=" .. node.chipid () .. " tostring=" .. tostring ( node.chipid () ) );
    if ( ok and (json.chipid == node.chipid ()) ) then
        logger:debug ( "receiveConfig: found same chipid " .. node.chipid () );
        if ( file.open ( "espConfig_mqtt.json", "w" ) ) then
            file.write ( payload );
            file.close ();
            syslog.restart ();
            logger:alert ( "receiveConfig: RESTARTING" ); -- to resolve the restart flag in syslog
        end
    end

end

local function update ( payload )

    -- TODO check for file vs. io

    -- and there was no update with this url before
    local forceUpdate = true;
    if ( file.exists ( "old_update.url" ) ) then
        if ( file.open ( "old_update.url" ) ) then
            local url = file.readline ();
            file.close ();
            if ( url and url == payload ) then
                logger:notice ( "update: already updated with " .. payload );
                forceUpdate = false;
             end
        end
    end

    -- start update procedure
    if ( forceUpdate ) then
        logger:debug ( "update: start heap=" .. node.heap () )
        if ( file.open ( "update.url", "w" ) ) then
            local success = file.write ( payload );
            logger:debug ( "update: url write success=" .. tostring ( success ) );
            file.close ();
            if ( success ) then
                logger:notice ( "update:  restart for second step url="  .. payload );
                syslog.restart ();
                logger:alert ( "update: RESTARTING" ); -- to resolve the restart flag in syslog
            end
        end
    end

end

local function startMqtt ()

    logger:info ( "startMqtt:" );

    -- Setup MQTT client and events
    if ( mqttClient == nil ) then

        local mqttClientName = node.chipid () .. "-" .. nodeConfig.class .. "-" .. nodeConfig.type .. "-" .. nodeConfig.location;
        mqttClient = mqtt.Client ( mqttClientName, nodeConfig.mqtt.keepAliveTime ); -- ..., keep_alive_time, username, password, cleansession (default)

        mqttClient:on ( "connect",
            function ( client )
                logger:debug ( "startMqtt.connected: CONNECTED" );
                periodicTimer:start ();
                connect ( client );
            end
        );

        mqttClient:on ( "message",
            function ( client, topic, payload )
                logger:info ( "startMqtt.message: received topic=" .. topic .." payload=" .. tostring ( payload ) );
                if ( payload ) then
                    -- check for update
                    local _, pos = topic:find ( baseTopic );
                    if ( pos ) then
                        local subtopic = topic:sub ( pos + 1 );
                        logger:debug ( "startMqtt.message: subtopic=" .. subtopic );
                        if ( subtopic == "/service/update" ) then
                            update ( payload );
                        elseif ( subtopic == "/service/sysloglevel" ) then
                            syslog.setLevel ( payload );
                        elseif ( subtopic == "/service/config" ) then
                            subscribeConfig ( client );
                        elseif ( subtopic == "/service/telnet" ) then
                            startTelnet = true;
                            require ( "telnet" ):open ( wifiCredential.ssid, wifiCredential.password );
                        elseif ( subtopic == "/service/restart" ) then
                            syslog.restart ();
                            logger:alert ( "startMqtt.message: RESTARTING" ); -- to resolve the restart flag in syslog
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
                logger:warning ( "startMqtt.offline:" );
                periodicTimer:stop ();
                syslog.setOffline ();
                if ( not startTelnet and appNode.offline and appNode.offline ( client ) ) then
                    logger:notice ( "startMqtt.offline: restart connection" );
                    -- wifiLoopTimer:start ();
                    -- TODO check for (direct) reboot
                    -- node.restart ()
                end
            end
        );

    end

    mqttClient:lwt ( mqttTopic, "offline", qos, retain );

    while not pcall (
        function ()
            local broker = nodeConfig.mqtt.broker;
            logger:notice ( "startMqtt: connect to broker=" .. broker );
            mqttClient:connect( broker, 1883 );

            --     -- aliases with the "connfail" callback available through :on()
            --     function ( client, reason )
            --         logger:notice ( "startMqtt: not connected reason=" .. reason );
            --     end
            -- )
        end
    )
    do
        logger:warning ( "startMqtt: retry connecting" );
    end

end

--------------------------------------------------------------------
-- public

function M.start ()

    logger:info ( "start: app=" .. app  );
    appNode = require ( app );

    -- Connect to the wifi network
    logger:notice ( "start: configuring wifi" );

    if ( is_ESP32 ) then
        wifi.start ();
    end

    local wifi_set_mode = is_ESP32 and wifi.mode or wifi.setmode;
    wifi_set_mode ( wifi.STATION, true ); -- save to flash

    if ( not is_ESP32 ) then
        local phymode = nodeConfig.phymode and wifi [nodeConfig.phymode] or wifi.PHYMODE_N;
        wifi.setphymode ( phymode );
        logger:debug ( "start: phymode=" .. wifi.getphymode () .. " (1=B,2=G,3=N) country=" .. wifi.getcountry ().country );
        wifi.nullmodesleep ( false );
        logger:debug ( "start: nullmodesleep=" .. tostring ( wifi.nullmodesleep () ) );
    end

    local configok = wifi.sta.config (
        {
            ssid = wifiCredential.ssid,
            pwd = wifiCredential.password,
            auto = false,   -- don't connect automatically, esp32 does not support auto connect
            save = true     -- save to flash
        }
    );
    logger:debug ( "start: wifi config loaded=" .. tostring ( configok ) );
    
    local wificfg = nodeConfig.wifi;
    if ( wificfg and wificfg.up ) then
        logger:debug ( "start: wifi fix ip=" .. wificfg.ip );
        wifi.sta.setip ( wificfg );
    end

    logger:debug ( "start: register wifi callbacks" );

    local function wifi_start_cb ( event, info )
        logger:debug ( "start.wifi_start_cb: event=" .. event );
    end

    local ssid, bssid;

    local function wifi_connected_cb ( event, info )
        ssid = tostring ( info.ssid and info.ssid or info.SSID );
        bssid = tostring ( info.bssid and info.bssid or info.BSSID );
        logger:debug ( "start.wifi_connected_cb: event=" .. event .. " ssid=" .. ssid .. " bssid=" .. bssid .. " channel=" .. tostring ( channel ) );
    end

    -- WIFI_REASON_UNSPECIFIED                        = 1,     /**< Unspecified reason */
    -- WIFI_REASON_AUTH_EXPIRE                        = 2,     /**< Authentication expired */
    -- WIFI_REASON_AUTH_LEAVE                         = 3,     /**< Deauthentication due to leaving */
    -- WIFI_REASON_ASSOC_EXPIRE                       = 4,     /**< Association expired */
    -- WIFI_REASON_ASSOC_TOOMANY                      = 5,     /**< Too many associated stations */
    -- WIFI_REASON_NOT_AUTHED                         = 6,     /**< Not authenticated */
    -- WIFI_REASON_NOT_ASSOCED                        = 7,     /**< Not associated */
    -- WIFI_REASON_ASSOC_LEAVE                        = 8,     /**< Deassociated due to leaving */
    -- WIFI_REASON_ASSOC_NOT_AUTHED                   = 9,     /**< Association but not authenticated */
    -- WIFI_REASON_DISASSOC_PWRCAP_BAD                = 10,    /**< Disassociated due to poor power capability */
    -- WIFI_REASON_DISASSOC_SUPCHAN_BAD               = 11,    /**< Disassociated due to unsupported channel */
    -- WIFI_REASON_BSS_TRANSITION_DISASSOC            = 12,    /**< Disassociated due to BSS transition */
    -- WIFI_REASON_IE_INVALID                         = 13,    /**< Invalid Information Element (IE) */
    -- WIFI_REASON_MIC_FAILURE                        = 14,    /**< MIC failure */
    -- WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT             = 15,    /**< 4-way handshake timeout */
    -- WIFI_REASON_GROUP_KEY_UPDATE_TIMEOUT           = 16,    /**< Group key update timeout */
    -- WIFI_REASON_IE_IN_4WAY_DIFFERS                 = 17,    /**< IE differs in 4-way handshake */
    -- WIFI_REASON_GROUP_CIPHER_INVALID               = 18,    /**< Invalid group cipher */
    -- WIFI_REASON_PAIRWISE_CIPHER_INVALID            = 19,    /**< Invalid pairwise cipher */
    -- WIFI_REASON_AKMP_INVALID                       = 20,    /**< Invalid AKMP */
    -- WIFI_REASON_UNSUPP_RSN_IE_VERSION              = 21,    /**< Unsupported RSN IE version */
    -- WIFI_REASON_INVALID_RSN_IE_CAP                 = 22,    /**< Invalid RSN IE capabilities */
    -- WIFI_REASON_802_1X_AUTH_FAILED                 = 23,    /**< 802.1X authentication failed */
    -- WIFI_REASON_CIPHER_SUITE_REJECTED              = 24,    /**< Cipher suite rejected */
    -- WIFI_REASON_TDLS_PEER_UNREACHABLE              = 25,    /**< TDLS peer unreachable */
    -- WIFI_REASON_TDLS_UNSPECIFIED                   = 26,    /**< TDLS unspecified */
    -- WIFI_REASON_SSP_REQUESTED_DISASSOC             = 27,    /**< SSP requested disassociation */
    -- WIFI_REASON_NO_SSP_ROAMING_AGREEMENT           = 28,    /**< No SSP roaming agreement */
    -- WIFI_REASON_BAD_CIPHER_OR_AKM                  = 29,    /**< Bad cipher or AKM */
    -- WIFI_REASON_NOT_AUTHORIZED_THIS_LOCATION       = 30,    /**< Not authorized in this location */
    -- WIFI_REASON_SERVICE_CHANGE_PERCLUDES_TS        = 31,    /**< Service change precludes TS */
    -- WIFI_REASON_UNSPECIFIED_QOS                    = 32,    /**< Unspecified QoS reason */
    -- WIFI_REASON_NOT_ENOUGH_BANDWIDTH               = 33,    /**< Not enough bandwidth */
    -- WIFI_REASON_MISSING_ACKS                       = 34,    /**< Missing ACKs */
    -- WIFI_REASON_EXCEEDED_TXOP                      = 35,    /**< Exceeded TXOP */
    -- WIFI_REASON_STA_LEAVING                        = 36,    /**< Station leaving */
    -- WIFI_REASON_END_BA                             = 37,    /**< End of Block Ack (BA) */
    -- WIFI_REASON_UNKNOWN_BA                         = 38,    /**< Unknown Block Ack (BA) */
    -- WIFI_REASON_TIMEOUT                            = 39,    /**< Timeout */
    -- WIFI_REASON_PEER_INITIATED                     = 46,    /**< Peer initiated disassociation */
    -- WIFI_REASON_AP_INITIATED                       = 47,    /**< AP initiated disassociation */
    -- WIFI_REASON_INVALID_FT_ACTION_FRAME_COUNT      = 48,    /**< Invalid FT action frame count */
    -- WIFI_REASON_INVALID_PMKID                      = 49,    /**< Invalid PMKID */
    -- WIFI_REASON_INVALID_MDE                        = 50,    /**< Invalid MDE */
    -- WIFI_REASON_INVALID_FTE                        = 51,    /**< Invalid FTE */
    -- WIFI_REASON_TRANSMISSION_LINK_ESTABLISH_FAILED = 67,    /**< Transmission link establishment failed */
    -- WIFI_REASON_ALTERATIVE_CHANNEL_OCCUPIED        = 68,    /**< Alternative channel occupied */

    -- WIFI_REASON_BEACON_TIMEOUT                     = 200,    /**< Beacon timeout */
    -- WIFI_REASON_NO_AP_FOUND                        = 201,    /**< No AP found */
    -- WIFI_REASON_AUTH_FAIL                          = 202,    /**< Authentication failed */
    -- WIFI_REASON_ASSOC_FAIL                         = 203,    /**< Association failed */
    -- WIFI_REASON_HANDSHAKE_TIMEOUT                  = 204,    /**< Handshake timeout */
    -- WIFI_REASON_CONNECTION_FAIL                    = 205,    /**< Connection failed */
    -- WIFI_REASON_AP_TSF_RESET                       = 206,    /**< AP TSF reset */
    -- WIFI_REASON_ROAMING                            = 207,    /**< Roaming */
    -- WIFI_REASON_ASSOC_COMEBACK_TIME_TOO_LONG       = 208,    /**< Association comeback time too long */
    -- WIFI_REASON_SA_QUERY_TIMEOUT                   = 209,    /**< SA query timeout */
    -- WIFI_REASON_NO_AP_FOUND_W_COMPATIBLE_SECURITY  = 210,    /**< No AP found with compatible security */
    -- WIFI_REASON_NO_AP_FOUND_IN_AUTHMODE_THRESHOLD  = 211,    /**< No AP found in auth mode threshold */
    -- WIFI_REASON_NO_AP_FOUND_IN_RSSI_THRESHOLD      = 212,    /**< No AP found in RSSI threshold */

    local function wifi_disconnected_cb ( event, info )
        local ssid = tostring ( info.ssid and info.ssid or info.SSID );
        local bssid = tostring ( info.bssid and info.bssid or info.BSSID );
        logger:debug ( "start.wifi_disconnected_cb: event=" .. event .. " ssid=" .. ssid .. " bssid=" .. bssid .. " reason=" .. info.reason );
    end

    local function wifi_gotip_cb ( event, info )

        local ip = tostring ( info.ip and info.ip or info.IP );
        local gw = tostring ( info.gw and info.gw or info.gateway );
        logger:debug ( "start.wifi_gotip_cb: event=" .. event .. " ip=" .. ip .. " netmask=" .. tostring ( info.netmask ) .. " gateway=" .. gw );

        syslog.startOnline (); -- starts only (checked in syslog module), when initial configured mode is "online"

        local dnsname = wifi.sta.gethostname and wifi.sta.gethostname () or "-";
        logger:debug ( "start.wifi_gotip_cb: dnsname=" .. dnsname );
        
        local mac = wifi.sta.getmac and wifi.sta.getmac () or "-";
        logger:debug ( "start.wifi_gotip_cb: mac=" .. mac );
        
        local rssi = wifi.sta.getrssi and wifi.sta.getrssi () or "-";
        logger:debug ( "start.wifi_gotip_cb: rssi=" .. rssi );

        local apmac = bssid;
        if ( nodeConfig.wifi == nil ) then
            nodeConfig.wifi = {};
        end
        if ( not nodeConfig.wifi.ip ) then
            nodeConfig.wifi.ip = ip;
        end
        -- if ( not is_ESP32 ) then
        --     local ssid, pwd, _, apmac = wifi.sta.getconfig ( false ); -- old sytle, true: returns table
        --     logger:debug ( "start.wifi_gotip_cb: ssid=" .. tostring ( ssid ) );
        -- end
        nodeConfig.wifi.rssi= rssi;
        nodeConfig.wifi.apmac = apmac;
        nodeConfig.wifi.mac= mac;
        nodeConfig.wifi.dnsname = dnsname;

        logger:notice ( "start.wifi_gotip_cb: ssid=" .. tostring ( ssid ) .. " apmac=" .. tostring ( apmac ) );

        startMqtt ();

    end

    if ( is_ESP32) then
        wifi.sta.on ( "start", wifi_start_cb );                 -- info: -
        wifi.sta.on ( "connected", wifi_connected_cb );         -- info: ssid, bssid, channel, auth
        wifi.sta.on ( "disconnected", wifi_disconnected_cb );   -- info: ssid, bssid, reason
        wifi.sta.on ( "got_ip", wifi_gotip_cb );                -- info: ip, netmask, gw
    else
        -- on esp8266 there is no "start" event
        wifi.eventmon.register ( wifi.eventmon.STA_CONNECTED, function ( info ) wifi_connected_cb ( "connected", info ); end );         -- info: SSID, BSSID, channel
        wifi.eventmon.register ( wifi.eventmon.STA_DISCONNECTED, function ( info ) wifi_disconnected_cb ( "disconnected", info ); end );   -- info: SSID, BSSID, reason
        wifi.eventmon.register ( wifi.eventmon.STA_GOT_IP, function ( info ) wifi_gotip_cb ( "got_ip", info ); end );                -- info: IP, netmask, gateway
    end

    logger:info ( "start: wifi connecting to " .. wifiCredential.ssid );
    wifi.sta.connect ();

    if ( nodeConfig.timer.periodicPeriod ) then
        periodicTimer:register ( nodeConfig.timer.periodicPeriod, tmr.ALARM_AUTO, -- timer_id, interval_ms, mode
            function ()
                if ( mqttClient ) then
                    local voltage = -1;
                    local rssi = 0;
                    if ( not is_ESP32 ) then
                        if ( nodeConfig.appCfg.useAdc ) then
                            local scale = nodeConfig.appCfg.adcScale or 4200;
                            logger:debug ( "periodic: adcScale=" .. scale );
                            voltage = adc.read ( 0 ) / 1023 * scale; -- mV
                        else
                            voltage = adc.readvdd33 ();
                        end
                        rssi = wifi.sta.getrssi ();
                    end
                    logger:notice ( "periodic: send voltage=" .. voltage .. " rssi=" .. rssi );
                    mqttClient:publish ( baseTopic .. "/value/voltage", [[{"value":]] .. voltage .. [[, "unit":"mV"}]], qos, retain,
                        function ( client )
                            client:publish ( rssiTopic,
                                [[{"chipid":]] .. node.chipid () .. [[,"topic":"]] .. baseTopic .. [[","apmac":"]] .. nodeConfig.wifi.apmac .. [[","value":]] .. rssi .. [[, "unit":"dBm"}]],
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

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------