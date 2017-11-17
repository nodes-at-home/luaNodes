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

local VERSION = "V0.45"

local DEFAULT_CONFIG = {
    app = "noNode",
    class = "nonode", 
    type = "<chipid>", 
    location = "anywhere",  
    mode = "prod",
    timer = {
        startup = 0,
        startupDelay1 = 2 * 1000,
        startupDelay2 = 5 * 1000,
        wifiLoop = 1,
        wifiLoopPeriod = 1 * 1000,
        periodic = 2,
        periodicPeriod = 15 * 60 * 1000,
    },
    wifi = {
        gateway = "192.168.2.1",
        netmask = "255.255.255.0",
        ip = "192.168.2.90",
    },
    mqtt = {
        broker = "192.168.2.117",
        retain = 1,
        keepAliveTime = 5 * 60, -- in seconds
    },
    trace = {
        ip = "192.168.2.117",
        port = 10001,
        onUpdate = true
    },
};

--------------------------------------------------------------------
-- private

local function tableMerge ( t1, t2 )

    for k, v in pairs ( t2 ) do
        if type ( v ) == "table" then
            if type (t1 [k] or false) == "table" then
                tableMerge ( t1 [k] or {}, t2 [k] or {})
            else
                t1 [k] = v
            end
        else
            t1 [k] = v
        end
    end

    return t1

end

local function printTable ( t, indent )

    if ( type ( t ) ~= "table" ) then return; end

    local _indent = indent or 0;
    local indentStr = string.rep ( " ", indent or 0 );

    for k, v in pairs ( t ) do
        if ( type ( v ) == "table" ) then
            print ( indentStr .. k .. "={" ); 
            printTable ( v, _indent + 1 );
            print ( indentStr .. "}," ); 
        else
            print ( indentStr .. k .. "=" .. tostring( v ) .. "," );
        end
    end
    
end

local function replaceNil ( t )

    if ( type ( t ) ~= "table" ) then return; end
    
    for k, v in pairs ( t ) do
        if ( type ( v ) == "table" ) then
            replaceNil ( v );
        else
            if ( v and type ( v ) == "string" and v == "nil" ) then
                t [k] = nil;
            end
        end
    end

end

--------------------------------------------------------------------
-- public

-- loading config
-- order: 
--  1) inline default
--  2) file default
--  3) chipid file
--  5) local file 


function M.init ()

    local result = DEFAULT_CONFIG;
--    print ( "[CONFIG] default config" );
--    printTable ( result );

    local files = { "default", tostring ( node.chipid () ), "local" };
    
    for _, f in ipairs ( files ) do
        local loadFile = "espConfig_" .. f .. ".json";
        print ( "[CONFIG] try to load config: " .. loadFile );
        if ( file.exists ( loadFile ) ) then
            if ( file.open ( loadFile, "r" ) ) then
                print ( "[CONFIG] open config file: " .. loadFile );
                local jsonStr = file.read ();
                if ( jsonStr ) then
                    --local json = cjson.decode ( jsonStr );
                    local ok, json = pcall ( function () return cjson.decode ( jsonStr ) end );
                    if ( ok ) then
                        print ( "[CONFIG] config loaded")
                        tableMerge ( result, json );
                        --printTable ( result );
                    end
                end
                file.close ();
            end
        end
    end

    -- inject chipid
    if ( result.type == "<chipid>" ) then result.type = node.chipid (); end
    
    -- node base topic
    result.topic = table.concat ( { "nodes@home/", result.class, "/", result.type, "/", result.location } );
    
    -- result.version = VERSION .. " (" .. result.app .. ")";
    local major, minor, patch = node.info ();
    local sdk = table.concat ( { major, ".", minor, ".", patch } );
    local app = result.app;
    local pos = app:find ( "Node" );
    local nodeName = pos and app:sub ( 1, pos - 1 ) or app;
    result.version = table.concat ( { sdk, "-", nodeName, "-", VERSION } );
    
    -- TODO eliminate this three deprecated fields
    result.mqttBroker = result.mqtt.broker;
    result.retain = result.mqtt.retain;
    result.keepAliveTime = result.mqtt.keepAliveTime;
    
    replaceNil ( result );
    
--    print ( "[CONFIG] final config" );
--    printTable ( result );

    return result;
    
end

--------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

--------------------------------------------------------------------
