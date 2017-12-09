--------------------------------------------------------------------
--
-- nodes@home/luaNodes/spindleNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 25.11.2017

local moduleName = ...;
local M = {};
_G [moduleName] = M;

require ( "i2ctool" );
require ( "mpu6050" );

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin;
local sclPin = nodeConfig.appCfg.sclPin or 6;   -- white
local sdaPin = nodeConfig.appCfg.sdaPin or 5;   -- yellow
local intPin = nodeConfig.appCfg.intPin or 1;   -- green
local sampleNumber = nodeConfig.appCfg.sampleNumber or 10;

----------------------------------------------------------------------------------------
-- private

local restartConnection = true;
local readByte = i2ctool.readByte;
local writeByte = i2ctool.writeByte;
local setBits = i2ctool.setBits;
local setBit = i2ctool.setBit;

local function goDeepSleep ( client )

    if ( not nodeConfig.appCfg.useOfflineCallback ) then
        restartConnection = false;
        local deepSleepDelay = nodeConfig.timer.deepSleepDelay;
        print ( "[APP] initiate alarm for closing connection in " ..  deepSleepDelay/1000 .. " seconds" );
        -- wait a minute with closing connection
        tmr.alarm ( nodeConfig.timer.deepSleep, deepSleepDelay, tmr.ALARM_SINGLE,  -- timer_id, interval_ms, mode
            function () 
                print ( "[APP] closing connection" );
                client:close ();
                local timeBetweenSensorReadings = nodeConfig.appCfg.timeBetweenSensorReadings;
                print ( "[APP] Going to deep sleep for ".. timeBetweenSensorReadings/1000 .." seconds" );
                node.dsleep ( (timeBetweenSensorReadings - deepSleepDelay) * 1000, 1 ); -- us, RF_CAL after deep sleep
            end
        );
    else
        print ( "[APP] closing connection using offline handler" );
        client:close ();
    end

end

local function publishTemperature ( client, topic, temperature, callback )

    if ( temperature ) then
        print ( "[APP] publishTemperature: t=" .. temperature );
        client:publish ( topic .. "/value/temperature", [[{"value":]] .. temperature .. [[,"unit":"°C"}]], 0, nodeConfig.retain, -- qos, retain
            function ( client )
                callback ( client );
            end
        );
    else
        print ( "[APP] publishTemperature: nothing published" );
        local t = temperature and temperature or "--";
        client:publish ( topic .. "/value/error", "nothing published t=" .. t, 0, nodeConfig.retain, -- qos, retain
            function ( client )
                callback ( client );
            end
        );
    end

end

local function readAndPublishTemperature ( client, topic )

    print ( "[APP] readAndPublishTemperature: topic=" .. topic );

    -- temperature
    if ( dsPin ) then
        local t = require ( "ds18b20" );
        t:readTemp ( 
            function ( sensors )
                for addr, temperature in pairs ( sensors ) do
                    --print ( string.format ( "[APP] readAndPublishTemperature: Sensor %s: %s °C", encoder.toHex ( addr ), temperature ) ); -- readable address with base64 encoding is preferred when encoder module is available
                    publishTemperature ( client, topic, temperature, goDeepSleep );
                    break; -- only first value is published
                end
            end,
            dsPin 
        );
        if t.sens then
          print ( "[APP] readAndPublishTemperature: total number of DS18B20 sensors: " .. table.getn ( t.sens ) );
          for i, s in ipairs ( t.sens ) do
            --print(string.format("  sensor #%d address: %s%s", i, s.addr, s.parasite == 1 and " (parasite)" or ""))
            --print ( string.format ( "[APP] readAndPublishTemperature: sensor #%d address: %s%s", i, encoder.toHex ( s.addr ), s.parasite == 1 and " (parasite)" or "" ) ); -- readable address with base64 encoding is preferred when encoder module is available
          end
        end
    else
        goDeepSleep ( client );
    end

end

local function publishAcceleration ( client, topic, samples, callback )

    print ( "[APP] publishAcceleration" );
    
    local json = {"["};
    local first = true;
    for i = 1, #samples do
        local sample = samples [i];
        local s = string.format ( '%s{"a":{"x":%d,"y":%d,"z":%d},"t":%.2f}', first and "" or ",", sample.ax, sample.ay, sample.az, sample.t );
        first = false;
        table.insert ( json, s );
    end
    table.insert ( json, "]" );
    local s = table.concat ( json );
    print ( "[APP] publishAcceleration: json=" .. s );
    client:publish ( topic .. "/value/acceleration", s, 0, nodeConfig.retain, -- qos, retain
        function ( client )
            callback ( client, topic );
        end
    );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start: topic=" .. topic );
    
    -- initialize acceleration sensor
    mpu6050.init ( sdaPin, sclPin );
    local id = readByte ( mpu6050.REG.WHO_AM_I );
    print ( "[APP] start: chipId=" .. tohex ( id ) );

    -- power managemnt 1
    --  7: reset, 6: sleep, 5: cycle, see reg 108 for wake up frequency, 3: temperature disabled
    --  [2:0]: clock source, 0: internal 8MHz oscillator, 1: X gyroscope
    -- 0x00: no sleep, internal 8MHz oscillator
    -- 0x01: no sleep, x gyroscope as clock source
    -- 0x21: no sleep, cycle, x gyroscope as clock source
    writeByte ( mpu6050.REG.PWR_MGMT_1, 0x01 );
    
    -- power management 2
    --  [7:6]: wake up frequency, 0: 1.25Hz, 1: 5Hz, 2: 20Hz, 3: 40Hz
    --  5: standby accelerometer x axis, 4: y axis, 3: z axis
    --  2: standby gyroscope x axis, when in standby and clock surce, then the internal clock ist selected
    --  1: standby gyroscope y axis, 0: standby gyroscope z axis
    -- 0x07: 1.25Hz sample rate and all gyroscopes in standby
    -- 0x47: 5Hz sample rate and all gyroscopes in standby
    -- 0x43: 5Hz sample rate and only x gyroscope working
    -- 0x03: 1.25Hz sample rate and only x gyroscope working
    writeByte ( mpu6050.REG.PWR_MGMT_2, 0x03 ); 
    
    -- sample rate divider
    --  gyroscope output rate ( ( 1 + SMPLRT_DIV )
    --  where gyroscope output rate is 8kHz if DLPF is disabled (DLPF_CFG = 0 or 7) and 1kHz when DLPF is enabled (reg 26)
    --  accelerometer output rate is 1kHz
    -- 0x00: 8 or 1kHz, depending on DLPF
    -- n: Gyroscope Output Rate / (1 + SMPLRT_DIV) = 40Hz, where output rate is 8kHz
    writeByte ( mpu6050.REG.SMPLRT_DIV, 199 );
    
    -- configuration
    --  [5:3]: external frame sync
    --  [2:0]: DLPF  
    -- 0x06: bandwith 5Hz, delay 19ms
    writeByte ( mpu6050.REG.CONFIG, 0x06 ); 

    setBits ( mpu6050.REG.GYRO_CONFIG, 4, 3, 0 );       -- gyroscope configuration, 0: +-250°/s     
    setBits ( mpu6050.REG.ACCEL_CONFIG, 4, 3, 0 )       -- accelorometer configuration, 0: +-2g
    
    local sampleCount = 1;
    local samples = {};

    -- read accelerations by interrupt
    gpio.mode ( intPin, gpio.INT );
    gpio.trig ( intPin, "down",
        function ( level, when )
            local ax, ay, az, t = mpu6050.readAcceleration ();
            table.insert ( samples, { ax = ax, ay = ay, az = az, t = t } )
            sampleCount = sampleCount + 1;
            if ( sampleCount >= sampleNumber ) then
                writeByte ( mpu6050.REG.INT_ENABLE, 0x00 ); -- stop interrupt
                publishAcceleration ( client, topic, samples, readAndPublishTemperature );
                setBit ( mpu6050.REG.PWR_MGMT_1, 6, 1 ); -- sleep 
                unrequire ( "mpu6050" );
                unrequire ( "i2ctool" );
                samples = nil;
            else
            end
        end
    );
    
end

function M.connect ( client, topic )

    print ( "[APP] connect: topic=" .. topic );
    
    -- interrupt enable: Data Ready interrupt
    writeByte ( mpu6050.REG.INT_ENABLE, 0x01 );

end

local function offline ( client )

    print ( "[APP] offline" );

    local timeBetweenSensorReadings = nodeConfig.appCfg.timeBetweenSensorReadings;
    print ( "[APP] Going to deep sleep for ".. timeBetweenSensorReadings/1000 .." seconds" );
    node.dsleep ( timeBetweenSensorReadings * 1000, 1 ); -- us, RF_CAL after deep sleep
    
    return restartConnection; -- restart mqtt connection
    
end

function M.offline ( client )

    print ( "[APP] offline (local)" );

    return restartConnection; 

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " ,payload=", payload );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

if ( nodeConfig.appCfg.useOfflineCallback ) then
    M.offline = offline;
end

return M;

-------------------------------------------------------------------------------