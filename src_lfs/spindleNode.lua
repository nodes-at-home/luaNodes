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

local logger = require ( "syslog" ).logger ( moduleName );

local i2ctool = require ( "i2ctool" );
local mpu6050 = require ( "mpu6050" );
local ds18b20 = require ( "ds18b20" );

-------------------------------------------------------------------------------
--  Settings

local dsPin = nodeConfig.appCfg.dsPin;
local sclPin = nodeConfig.appCfg.sclPin or 6;   -- white
local sdaPin = nodeConfig.appCfg.sdaPin or 5;   -- yellow
local intPin = nodeConfig.appCfg.intPin or 1;   -- green
local sampleNumber = nodeConfig.appCfg.sampleNumber or 10;

local restartConnection = true;

local readByte = i2ctool.readByte;
local writeByte = i2ctool.writeByte;
local setBits = i2ctool.setBits;
local setBit = i2ctool.setBit;

local deepSleepDelay = nodeConfig.timer.deepSleepDelay;
local timeBetweenSensorReadings = nodeConfig.appCfg.timeBetweenSensorReadings;

local retain = nodeConfig.mqtt.retain;
local qos = nodeConfig.mqtt.qos or 1;

----------------------------------------------------------------------------------------
-- private

local function printSensors ()

    if ( ds18b20.sens ) then
        logger.debug ( "printSensors: number of sensors=" .. #ds18b20.sens );
        for i, s  in ipairs ( ds18b20.sens ) do
            local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( s:byte ( 1, 8 ) );
            local parasitic = s:byte ( 9 ) == 1 and " (parasite)" or "";
            logger.debug ( string.format ( "printSensors: sensor #%d address: %s%s",  i, addr, parasitic ) );
        end
    end

end

local function readAndPublishTemperature ( client, topic )

    logger.info ( "readAndPublishTemperature: topic=" .. topic );

    -- temperature
    ds18b20:read_temp (
        function ( sensorValues )
            printSensors ();
            local i = 0;
            for address, temperature in pairs ( sensorValues ) do
                i = i + 1;
                if ( i == 1 ) then -- only first sensor
                    local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( address:byte ( 1, 8 ) );
                    logger.debug ( ( "readAndPublishTemperature: Sensor %s -> %s°C %s"):format ( addr, temperature, address:byte ( 9 ) == 1 and "(parasite)" or "-" ) );
                    logger.debug ( "readAndPublishTemperature: temperature=" .. temperature );
                    local payload = ('{"value":%f,"unit":"°C"}'):format ( temperature );
                    client:publish ( topic .. "/value/temperature", payload, qos, retain,
                        function ( client )
                            require ( "deepsleep" ).go ( client, deepSleepDelay, timeBetweenSensorReadings );
                        end
                    );
                end
            end

        end,
        dsPin,
        ds18b20.C,          -- °C
        nil,                -- no search
        "save"
    );


end

local function publishAcceleration ( client, topic, samples )

    logger.info ( "publishAcceleration: topic=" .. topic .. " count=" .. #samples );

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
    logger.debug ( "publishAcceleration: json=" .. s );
    client:publish ( topic .. "/value/acceleration", s, qos, retain,
        function ( client )
            readAndPublishTemperature ( client, topic );
        end
    );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger.info ( "start: topic=" .. topic );

    -- initialize acceleration sensor
    mpu6050.init ( sdaPin, sclPin );
    local id = readByte ( mpu6050.REG.WHO_AM_I );
    logger.debug ( "start: chipId=" .. tohex ( id ) );

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
                publishAcceleration ( client, topic, samples );
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

    logger.info ( "connect: topic=" .. topic );

    -- interrupt enable: Data Ready interrupt
    writeByte ( mpu6050.REG.INT_ENABLE, 0x01 );

end

function M.offline ( client )

    logger.info ( "offline:" );

    return restartConnection;

end

function M.message ( client, topic, payload )

    logger.info ( "message: topic=" .. topic .. " payload=" .. payload );

end

-------------------------------------------------------------------------------
-- main

logger.debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------