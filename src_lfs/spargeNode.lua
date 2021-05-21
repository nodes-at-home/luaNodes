--------------------------------------------------------------------
--
-- nodes@home/luaNodes/spargeNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 17.05.2020

local moduleName = ...;
local M = {};
_G [moduleName] = M;

local logger = require ( "syslog" ).logger ( moduleName );

local ds18b20 = require ( "ds18b20" );

-------------------------------------------------------------------------------
--  Settings

local displayHeight = nodeConfig.appCfg.resolution.height;
local displayWidth = nodeConfig.appCfg.resolution.width;

local dsPin = nodeConfig.appCfg.dsPin;
local numSensors = nodeConfig.appCfg.numSensors;

local retain = nodeConfig.mqtt.retain;
local NO_RETAIN = 0;
local qos = nodeConfig.mqtt.qos or 1;

----------------------------------------------------------------------------------------
-- private
--

local GRAD = string.char ( 176 );

local messages = {};
local msgKey = nil;
local msg = nil;

local display;

local function printSensors ()

    if ( ds18b20.sens ) then
        logger:debug ( "printSensors: number of sensors=" .. #ds18b20.sens );
        for i, s  in ipairs ( ds18b20.sens ) do
            local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( s:byte ( 1, 8 ) );
            local parasitic = s:byte ( 9 ) == 1 and " (parasite)" or "";
            logger:debug ( string.format ( "printSensors: sensor #%d address: %s%s",  i, addr, parasitic ) );
        end
    end

end

local function publishValues ( client, topic, temperatures )

    logger:info ( "publishValues: topic= " .. topic .. " count=" .. #temperatures );

    local payload = '{';

    for i = 1, #temperatures do
        payload = ('%s"temperature%d":%.1f,'):format ( payload, i, temperatures [i] );
    end

    payload = payload .. '"unit":"°C"}';

    logger:debug ( "publishValues: payload=" .. payload );

    client:publish ( topic .. "/value/temperature", payload, NO_RETAIN, retain,
        function ( client )
        end
    );

end

local function displayValues ( temperatures )

    logger:info ( "displayValues: count=" .. #temperatures );

    local t1 = ('%.1f'):format ( temperatures [1] ) .. GRAD;
    local t2 = ('%.1f'):format ( temperatures [2] ) .. GRAD;

    display:clearBuffer ();

    display:drawFrame ( 1, 1, 64, 16 );
    display:drawBox ( 64, 1, 64, 16 );

    display:setFont ( u8g2.font_fur20_tf );
    --display:setFont ( u8g2.font_6x10_tf );
    display:setFontPosTop ();
    local y = displayHeight == 32 and 7 or 28;
    local x1 = 1;
    local x2 = 128 - display:getStrWidth ( t2 ) - x1
    display:drawStr ( x1, y, t1 );
    display:drawStr ( x2, y, t2 );

    for i = 1,16 do
        display:drawPixel ( displayWidth - 2, i );
    end

    display:sendBuffer ();

end

local function readAndPublish ( client, topic )

    logger:info ( "readAndPublish: topic=" .. topic );

    if ( dsPin ) then

        local temps = {};

        ds18b20:read_temp (
            function ( sensorValues )
                --printSensors ();
                local i = 0;
                for address, temperature in pairs ( sensorValues ) do
                    i = i + 1;
                    local addr = ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format ( address:byte ( 1, 8 ) );
                    local parasitic = address:byte ( 9 ) == 1 and "(parasite)" or "-";
                    logger:debug ( "readAndPublish: index=" .. i .. " address=" .. addr .. " temperature=" .. temperature .. " parasitic=" .. parasitic );
                    temps [#temps + 1] = temperature;
                    if ( i == numSensors ) then
                        displayValues ( temps );
                        publishValues ( client, topic, temps );
                    end
                end

            end,
            dsPin,
            ds18b20.C,          -- °C
            nil,                -- no search
            "save"
        );

    else

        displayValues ( {66.4, 55.3} );

    end

end

local function i2cInit ( resolution, sdaPin, sclPin )

    i2c.setup( 0, sdaPin, sclPin, i2c.SLOW);
    return u8g2 ["ssd1306_i2c_" .. resolution .. "_noname"] ( 0, 0x3c ); -- slave address

end

local function spiInit ( resolution, csPin, dcPin, resetPin )

    logger:debug ( "spiInit: res=" .. resolution .. " cs=" .. csPin .. " dc=" .. dcPin .. " reset=" .. resetPin );

    spi.setup ( 1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 8 ); -- 1: HSPI, ... 8: databits, 8: clock divider on 80 MHz
    -- we won't be using the HSPI /CS line, so disable it again
    gpio.mode ( csPin, gpio.INPUT, gpio.PULLUP );

    return u8g2 ["ssd1306_" .. resolution .. "_noname"] ( 1, csPin, dcPin, resetPin );

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    logger:info ( "start^: topic=" .. topic );

    local resolution = displayWidth .. "x" .. displayHeight;
    if ( nodeConfig.appCfg.i2c ) then
        local sda = nodeConfig.appCfg.i2c.sdaPin;
        local scl = nodeConfig.appCfg.i2c.sclPin;
        logger:debug ( "start: intialize i2c with sda=" .. sda .. " scl=" .. scl .. " res=" .. resolution );
        display = i2cInit ( resolution, sda, scl );
    elseif ( nodeConfig.appCfg.spi ) then
        local cs = nodeConfig.appCfg.spi.csPin;
        local dc = nodeConfig.appCfg.spi.dcPin;
        local reset = nodeConfig.appCfg.spi.resetPin;
        logger:debug ( "intialize spi with cs=" .. cs .. " dc=" .. dc .. " reset=" .. reset .. " res=" .. resolution );
        display = spiInit ( resolution, cs, dc, reset );
        logger:debug ( "start: display initialized" );
    else
        logger:debug ( "start: no device initialized" );
        return;
    end

end

function M.connect ( client, topic )

    logger:info ( "connect: topic=" .. topic );

    readAndPublish ( client, topic );

end

function M.message ( client, topic, payload )

    logger:info ( "message: topic=" .. topic .. " payload=" .. payload );

end

function M.periodic ( client, topic )

    logger:info ( "periodic: topic=" .. topic );

    readAndPublish ( client, topic );

end

function M.offline ( client )

    logger:info ( "offline:" );

    return true;

end

-------------------------------------------------------------------------------
-- main

logger:debug ( "loaded: " );

return M;

-------------------------------------------------------------------------------