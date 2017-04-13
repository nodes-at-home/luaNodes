--------------------------------------------------------------------
--
-- nodes@home/luaNodes/espNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 14.10.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

--------------------------------------------------------------------
-- vars

local VERSION = "V0.33"

local PROD_GATEWAY = "192.168.2.1";
local PROD_NETMASK = "255.255.255.0";
local PROD_MQTT_BROKER = "192.168.2.117";
local PROD_TRACE_SERVER_IP = "192.168.2.117";
local PROD_TRACE_SERVER_PORT = "10001";

--------------------------------------------------------------------
-- private

local DEFAULT_CONFIG = {
    app = "noNode",
    class = "nonode", type = "<chipid>", location = "anywhere",  
--    wifi = { ip = "192.168.2.90", gateway = PROD_GATEWAY, netmask = PROD_NETMASK },
--    mqttBroker = "192.168.137.1",
--    mode = "surface",
    appCfg = {
        useOfflineCallback = false,
        timeBetweenSensorReadings = 15 * 60 * 1000, -- ms
        timeBetweenSensorReadings = 1 * 60 * 1000, -- ms
    },
    timer = {
        startup = 0,
        startupDelay1 = 2 * 1000,
        startupDelay2 = 5 * 1000,
        wifiLoop = 1,
        wifiLoopPeriod = 1 * 1000,
        periodic = 2,
        periodicPeriod = 15 * 60 * 1000,
        deepSleep = 3,
        deepSleepDelay = 60 * 1000, -- ms, only if not useOfflineCallback
    },
};

--------------------------------------------------------------------
-- public

function M.init ()

    local result = DEFAULT_CONFIG;

    local fileName = "espConfig_local.json";
    if ( not file.exists ( fileName ) ) then
        fileName = "espConfig_" .. node.chipid () .. ".json";
        if ( not file.exists ( fileName ) ) then
            fileName = "espConfig_default.json";
        end
    end
        
    if ( file.open ( fileName, "r" ) ) then
        print ( "[CONFIG] open config file: " .. fileName );
        local jsonStr = file.read ();
        result = cjson.decode ( jsonStr );
    end
    
    -- inject chipid
    if ( result.type == "<chipid>" ) then result.type = node.chipid (); end
    
    -- node base topic
    result.topic = "nodes@home/" .. result.class .. "/" .. result.type .. "/" .. result.location;
    result.version = VERSION .. " (" .. result.app .. ")";
    result.retain = 1; -- 0: no retain
    result.keepAliveTime = 5 * 60;
    
    -- wifi
    if ( not result.mode ) then result.mode = "prod"; end
    
    -- mqtt broker
    if ( not result.mqttBroker ) then result.mqttBroker = PROD_MQTT_BROKER; end
    
    -- tcp trace
    if ( not result.trace ) then result.trace = {}; end
    if ( not result.trace.ip ) then result.trace.ip = PROD_TRACE_SERVER_IP; end
    if ( not result.trace.port ) then result.trace.port = PROD_TRACE_SERVER_PORT; end
    
    package.loaded [moduleName] = nil;
    
    return result;
    
end

--------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

--------------------------------------------------------------------
