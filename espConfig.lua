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

local VERSION = "V0.25"

local PROD_GATEWAY = "192.168.2.1";
local PROD_NETMASK = "255.255.255.0";
local PROD_MQTT_BROKER = "192.168.2.117";
local PROD_TRACE_SERVER_IP = "192.168.2.117";
local PROD_TRACE_SERVER_PORT = "10001";

-- key is node.chipid ()
local NODE_CONFIG_TAB = {

    [1461824] = { 
                    app = "rfNode",
                    class = "switch", type = "rfhub", location = "first",  
                    wifi = { ip = "192.168.2.20", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        rfpin = 7,
                        rfrepeats = 16,
                        rfperiod = 320, -- us
                        ledpin = 4,
                        dhtPin = 6,
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000,
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
                        periodic = 2,
                        periodicPeriod = 15 * 60 * 1000,
                        queue = 3,
                        queuePeriod = 500,
                    },
                },

    [1495931] = { 
                    app = "tempNode",
                    class = "sensor", type = "DHT11", location = "lounge",  
                    wifi = { ip = "192.168.2.21", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        useOfflineCallback = false,
                        dhtPin = 4,
                        timeBetweenSensorReadings = 15 * 60 * 1000, -- ms
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
                },

    [1829768] = { 
                    app = "tempNode",
                    class = "sensor", type = "DHT11", location = "roof",  
                    wifi = { ip = "192.168.2.22", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        useOfflineCallback = false,
                        dhtPin = 4,
                        timeBetweenSensorReadings = 15 * 60 * 1000, -- ms
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
                },

    [2030164] = { 
                    app = "tempNode",
                    class = "sensor", type = "DHT11", location = "terrace",  
                    wifi = { ip = "192.168.2.23", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        useOfflineCallback = false,
                        dhtPin = 4,
                        timeBetweenSensorReadings = 15 * 60 * 1000, -- ms
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
                },
                
    [8391351] = {
                    app = "garageNode",
                    class = "cover", type = "relay", location = "garage",  
                    wifi = { ip = "192.168.2.25", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        relayPin = 1,
                        openPositionPin = 5,
                        closedPositionPin = 6,
                        dhtPin = 4,
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000,
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
                        periodic = 2,
                        periodicPeriod = 15 * 60 * 1000,
                        debounce = 3,
                        debounceDelay = 200,
                        trigger = 4,
                        triggerDelay = 300,
                        state = 5,
                        statePeriod = 1000,
                    },
                },

    [485535] = {
                    app = "sonoffNode",
                    class = "switch", type = "sonoff", location = "utilityroom",  
                    wifi = { ip = "192.168.2.26", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        device = "pump",
                        relayPin = 6,
                        ledPin = 7,
--                        buttonPin = 3,    -- switch event indusing button events
                        extraPin = 5,
                        flashHighPulseLength = 50 * 1000,   -- ms
                        flashLowPulseLength = 200 * 1000,   -- ms
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000,
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
                        periodic = 2,
                        periodicPeriod = 15 * 60 * 1000,
                        debounce = 3,
                        debounceDelay = 500,
                    },
                },
                
    [518010] = {
                    app = "sonoffNode",
                    class = "switch", type = "sonoff", location = "garage",  
                    wifi = { ip = "192.168.2.27", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        relayPin = 6,
                        ledPin = 7,
                        buttonPin = 3,
                        extraPin = 5,
                        flashHighPulseLength = 50 * 1000,   -- ms
                        flashLowPulseLength = 200 * 1000,   -- ms
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000,
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
                        periodic = 2,
                        periodicPeriod = 15 * 60 * 1000,
                        debounce = 3,
                        debounceDelay = 500,
                    },
                },
                
    [982283] = {
                    app = "relayNode", -- no 1
                    class = "switch", type = "relay", location = "terrace",  
                    wifi = { ip = "192.168.2.28", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        buttonPin = 1,
                        ledPin = 2,
                        relayPin1 = 6,
                        relayPin2 = 7,
                        relayPulseLength = 30 * 1000,       -- ms
                        flashHighPulseLength = 50 * 1000,   -- ms
                        flashLowPulseLength = 200 * 1000,   -- ms
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000,
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
                        periodic = 2,
                        periodicPeriod = 15 * 60 * 1000,
                        debounce = 3,
                        debounceDelay = 500,
                    },
                },
                
    [1689710] = {
                    app = "relayNode", -- no 3
                    class = "switch", type = "relay", location = "backyard",  
                    wifi = { ip = "192.168.2.29", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        buttonPin = 1,
                        ledPin = 2,
                        relayPin1 = 6,
                        relayPin2 = 7,
                        relayPulseLength = 30 * 1000,       -- ms
                        flashHighPulseLength = 50 * 1000,   -- ms
                        flashLowPulseLength = 200 * 1000,   -- ms
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000,
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
                        periodic = 2,
                        periodicPeriod = 15 * 60 * 1000,
                        debounce = 3,
                        debounceDelay = 500,
                    },
                },
                
    [8734823] = {
                    app = "relayNode", -- no 2
                    class = "switch", type = "relay", location = "carport",  
                    wifi = { ip = "192.168.2.30", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        buttonPin = 1,
                        ledPin = 2,
                        relayPin1 = 6,
                        relayPin2 = 7,
                        relayPulseLength = 30 * 1000,       -- ms
                        flashHighPulseLength = 50 * 1000,   -- ms
                        flashLowPulseLength = 200 * 1000,   -- ms
--                        device = "plug"
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000,
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
                        periodic = 2,
                        periodicPeriod = 15 * 60 * 1000,
                        debounce = 3,
                        debounceDelay = 500,
                    },
                },
                
    [2677473] = {
                    app = "xmasNode",
                    class = "light", type = "xmastree", location = "dining",  
                    wifi = { ip = "192.168.2.31", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        device = "leds",
                        arduinoResetPin = 6,    -- for future use, resetting the arduino
                        disablePrint = true,
                        useRGB = false,
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000,
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
                        periodic = 2,
                        periodicPeriod = 15 * 60 * 1000,
                    },
                },
                
    [15892791] = { 
                    app = "buttonNode", -- no 1
                    class = "sensor", type = "button", location = "no1",  
                    wifi = { ip = "192.168.2.32", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        useOfflineCallback = false,
                        useQuickStartupAfterDeepSleep = true;
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000, -- us
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
--                        periodic = 2,
--                        periodicPeriod = 15 * 60 * 1000,
                        deepSleep = 3,
                        deepSleepDelay = 1* 1000, -- ms, only if not useOfflineCallback
                    },
                },

    [16061971] = { 
                    app = "buttonNode", -- no 2
                    class = "sensor", type = "button", location = "garage",  
                    wifi = { ip = "192.168.2.33", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        useOfflineCallback = false,
                        useQuickStartupAfterDeepSleep = true;
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000, -- us
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
--                        periodic = 2,
--                        periodicPeriod = 15 * 60 * 1000,
                        deepSleep = 3,
                        deepSleepDelay = 1* 1000, -- ms, only if not useOfflineCallback
                    },
                },

    [35778] = { 
                    app = "buttonNode", -- no 3
                    class = "sensor", type = "button", location = "no3",  
                    wifi = { ip = "192.168.2.34", gateway = PROD_GATEWAY, netmask = PROD_NETMASK }, 
                    appCfg = {
                        useOfflineCallback = false,
                        useQuickStartupAfterDeepSleep = true;
                    },
                    timer = {
                        startup = 0,
                        startupDelay1 = 2 * 1000,
                        startupDelay2 = 5 * 1000, -- us
                        wifiLoop = 1,
                        wifiLoopPeriod = 1 * 1000,
--                        periodic = 2,
--                        periodicPeriod = 15 * 60 * 1000,
                        deepSleep = 3,
                        deepSleepDelay = 1* 1000, -- ms, only if not useOfflineCallback
                    },
                },

    [2028701] = { 
                    app = "tempNode",
                    class = "sensor", type = "DHT22_bmp280", location = "lounge",  
                    -- wifi = { ip = "192.168.2.35", gateway = PROD_GATEWAY, netmask = PROD_NETMASK },
                    mqttBroker = "192.168.137.1",
                    appCfg = {
                        useOfflineCallback = false,
                        dhtPin = 4,
                        bme280SdaPin = 2,         -- green
                        bme280SclPin = 1,         -- yellow
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
                },
                
    [2677460] = {
                    app = "noNode",
                    class = "nonode", type = "test", location = "anywhere",  
                     wifi = { ip = "192.168.2.36", gateway = PROD_GATEWAY, netmask = PROD_NETMASK },
--                    mqttBroker = "192.168.137.1",
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
                },

};

--------------------------------------------------------------------
-- private

--------------------------------------------------------------------
-- public

--------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

M.node = NODE_CONFIG_TAB [node.chipid ()];

-- node base topic
M.node.topic = "nodes@home/" .. M.node.class .. "/" .. M.node.type .. "/" .. M.node.location;
M.node.version = VERSION .. " (" .. M.node.app .. ")";
M.node.retain = 1; -- 0: no retain

M.node.mode = "prod";

if ( not M.node.mqttBroker ) then
    M.node.mqttBroker = PROD_MQTT_BROKER;
end

if ( not M.node.trace ) then
    M.node.trace = {};
end

if ( not M.node.trace.ip ) then
    M.node.trace.ip = PROD_TRACE_SERVER_IP;
end

if ( not M.node.trace.port ) then
    M.node.trace.port = PROD_TRACE_SERVER_PORT;
end

return M;

--------------------------------------------------------------------

