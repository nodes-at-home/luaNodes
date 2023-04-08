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

local logger = require ( "syslog" ).logger ( moduleName );

local tmr, gpio = tmr, gpio;

-------------------------------------------------------------------------------
--  Settings

local irLedPin = nodeConfig.appCfg.irLedPin;

local irPeriod = nodeConfig.timer.irPeriod;
local irDelay = nodeConfig.timer.irDelay;

local voltageThreshold = nodeConfig.appCfg.threshold.voltage;
local latencyThreshold = nodeConfig.appCfg.threshold.latency;

local retain = nodeConfig.mqtt.retain;

----------------------------------------------------------------------------------------
-- private

local loopTimer = tmr.create ();
local shortTimer = tmr.create ();

local lastEvent = "high";
local level = "high";
local lastLevel = "high";
local lastTimestamp = nil;

local lowCounter;
local highCounter;

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start: topic=" .. topic );

    gpio.mode ( irLedPin, gpio.OUTPUT );
    gpio.write ( irLedPin, gpio.LOW );

end

function M.connect ( client, topic )

    logger:debug ( "connect: topic=" .. topic );

    loopTimer:alarm ( irPeriod, tmr.ALARM_AUTO,
        function ()
            shortTimer:alarm ( irDelay, tmr.ALARM_SINGLE,
                function ()
                    local voltageIrOff = adc.read ( 0 );
                    gpio.write ( irLedPin, gpio.HIGH );
                    shortTimer:alarm ( irDelay, tmr.ALARM_SINGLE,
                        function ()

                            -- measure ir level
                            local voltageIrOn = adc.read ( 0 );
                            gpio.write ( irLedPin, gpio.LOW );
                            local voltage = voltageIrOn - voltageIrOff;
                            local event = voltage > voltageThreshold and "high" or "low";
                            logger:debug ( "connect: voltages irOff=" .. voltageIrOff .. " irOn=" .. voltageIrOn .. " diff=" .. voltage .. " event=" .. event .. " lastevent=" .. lastEvent .. " level=" .. level .. " lastLevel=" .. lastLevel .. " highcounter=" .. tostring ( highCounter ) .. " lowCounter=" .. tostring ( lowCounter ) );

                            -- count events for level change
                            if ( lastEvent == event ) then
                                if ( event == "low" ) then
                                    if ( lowCounter ) then
                                        lowCounter = lowCounter + 1;
                                        if ( lowCounter >= latencyThreshold ) then
                                            lowCounter = nil;
                                            level = "low";
                                        end
                                    end
                                elseif ( event == "high" ) then
                                    if ( highCounter ) then
                                        highCounter = highCounter + 1;
                                        if ( highCounter >= latencyThreshold ) then
                                            highCounter =  nil;
                                            level = "high";
                                        end
                                    end
                                end
                            else
                                if ( event == "low" ) then
                                    if ( level == "high" ) then
                                        lowCounter = 1;
                                    else
                                        lowCounter = nil;
                                    end
                                    highCounter = nil;
                                elseif ( event == "high" ) then
                                    if ( level == "low" ) then
                                        highCounter = 1;
                                    else
                                        highCounter = nil;
                                    end
                                    lowCounter = nil;
                                end
                            end
                            lastEvent = event;
                            logger:debug ( "connect:  level=" .. level .. " lastLevel=" .. lastLevel .. " highcounter=" .. tostring ( highCounter ) .. " lowCounter=" .. tostring ( lowCounter ) );

                            -- check level for next tick
                            if ( lastLevel ~= level and level == "low" ) then
                                local timestamp = tmr.now (); -- µs
                                if (  lastTimestamp ) then
                                    local dt = timestamp - lastTimestamp;
                                    if dt < 0 then dt = dt + 2147483647 end;
                                    dt = dt / 1000000; -- sec
                                    local payload = string.format ( '{"dt":%f,"threshold":%d,"latency":%d}', dt, voltageThreshold, latencyThreshold );
                                    logger:info ( "connect: payload=" .. payload );
                                    client:publish ( topic .. "/value/tick", payload, 0, retain, -- qos, retain
                                        function ( client )
                                        end
                                    );
                                end
                                lastTimestamp = timestamp;
                            end
                            lastLevel = level;

                        end
                    );
                end
            );
        end
    );

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true; -- restart mqtt

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

    if ( topic == nodeConfig.topic .. "/service/threshold" ) then
        voltageThreshold = tonumber ( payload ) or nodeConfig.appCfg.threshold.voltage;
    elseif ( topic == nodeConfig.topic .. "/service/counter" ) then
        latencyThreshold = tonumber ( payload ) or nodeConfig.appCfg.threshold.latency;
    end

end

function M.periodic ( client, topic )

    logger:info ( "periodic: topic=" .. topic );

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------