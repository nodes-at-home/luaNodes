--------------------------------------------------------------------
--
-- nodes@home/luaNodes/electricNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 12.04.2018

local moduleName = ...;
local M = {};
_G [moduleName] = M;

-------------------------------------------------------------------------------
--  Settings

local irLedPin = nodeConfig.appCfg.irLedPin;
local threshold = nodeConfig.appCfg.threshold;
local irPeriod = nodeConfig.timer.irPeriod;
local irDelay = nodeConfig.timer.irDelay;

local retain = nodeConfig.mqtt.retain;

local REVOLUTION_PER_kWh = 75;

----------------------------------------------------------------------------------------
-- private

local loopTimer = tmr.create ();
local shortTimer = tmr.create ();

lastLevel = "high";
lastTimestamp = nil;
counter = 0;
    
--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start" );
    
    gpio.mode ( irLedPin, gpio.OUTPUT );
    gpio.write ( irLedPin, gpio.LOW );
    
end

function M.connect ( client, topic )

    print ( "[APP] connect" );
    
    loopTimer:alarm ( irPeriod, tmr.ALARM_AUTO, 
        function ()
            local voltageIrOff = 0;
            local voltageIrOn = 0;
            shortTimer:alarm ( irDelay, tmr.ALARM_SINGLE,
                function ()
                    voltageIrOff = adc.read ( 0 );
                    gpio.write ( irLedPin, gpio.HIGH );
                    shortTimer:alarm ( irDelay, tmr.ALARM_SINGLE,
                        function ()
                            voltageIrOn = adc.read ( 0 );
                            gpio.write ( irLedPin, gpio.LOW );
                            local voltage = voltageIrOn - voltageIrOff;
                            local level = voltage > threshold and "high" or "low";
                            print ( "[APP] voltages last=" .. lastLevel .. " level=" .. level .. " diff=" .. voltage .. " irOff" .. voltageIrOff .. " irOn=" .. voltageIrOn );
                            if ( level ~= lastLevel ) then
                                lastLevel = level;
                                if ( level == "low" ) then
                                    local timestamp = tmr.now (); -- µs
                                    counter = counter + 1000 / REVOLUTION_PER_kWh; -- Wh
                                    print ( "[APP] voltages last=" .. lastLevel .. " level=" .. level .. " diff=" .. voltage .. " irOff" .. voltageIrOff .. " irOn=" .. voltageIrOn );
                                    print ( "[APP] counter" .. counter .. "Wh" );
                                    local payload = string.format ( '{"electricity":%f,"unit":"Wh"}', counter );
                                    client:publish ( topic .. "/value/counter", payload, 0, retain, -- qos, retain
                                        function ( client )
                                            if (  lastTimestamp ) then
                                                local dt = timestamp - lastTimestamp;
                                                if dt < 0 then dt = dt + 2147483647 end;
                                                dt = dt / 1000000; -- sec
                                                local power = 1000 / REVOLUTION_PER_kWh * 3600 / dt; -- Watt
                                                print ( "[APP] power=" .. power .. "W" .. " dt=" .. dt .. "s" );
                                                    local payload = string.format ( '{"power":%f,"unit":"W"}', power );
                                                    client:publish ( topic .. "/value/power", payload, 0, retain, -- qos, retain
                                                        function ( client )
                                                        end
                                                    );
                                            end
                                            lastTimestamp = timestamp;
                                        end
                                    );
                                end
                            end
                        end
                    );
                end
            );
        end
    );

end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt 

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " payload=" .. payload );
    
    if ( topic == nodeConfig.topic .. "/service/set" ) then
        local pcallOk, json = pcall ( function () return sjson.decode ( payload ) end );
        print ( "[APP] pcall: pcallOk=" .. tostring ( pcallOk ) .. " result=" .. tostring ( json ) );
        if ( pcallOk ) then
            print ( "[APP] message: oldCounter=" .. counter/1000 .. " newCounter=" .. json.counter );
            counter = 1000 * json.counter; -- kWh -> Wh
        end
    end 
    
end

function M.periodic ( client, topic )

    print ( "[APP] periodic call topic=" .. topic );
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------