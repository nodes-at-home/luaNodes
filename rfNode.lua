--------------------------------------------------------------------
--
-- nodes@home/luaNodes/rfNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 03.10.2016

local moduleName = ...;
local M = {};
_G [moduleName] = M;

require  ( "util" );

-------------------------------------------------------------------------------
--  Settings

local isSending = false;

----------------------------------------------------------------------------------------
-- private

local function appendTable ( t1, t2 )

    for i = 1, #t2 do
        t1 [#t1+1] = t2 [i]
    end

    return t1

end

local function sendCode ( code, pin, repeats, period )

    print ( "[RF] repeats=", repeats, "period=", period, "code=", code );

    local codeBase4 = 0;
    for i = 1, 12 do
        local mod = code % 3;
        code = (code - mod) / 3;
        codeBase4 = bit.lshift ( codeBase4, 2 );
        codeBase4 = bit.bor ( codeBase4, mod );
    end
    print ( "[RF] codeBase4=", codeBase4 );

    --      (1) put delayTimes for all trits into one array and then fire en asyncronous serout
    --      (2) resuse table from (1)
    --      (3) if so, we can use repeat from serout

    local tritDelayTimes = {
        [0] = {1*period, 3*period, 1*period, 3*period},
        [1] = {3*period, 1*period, 3*period, 1*period};
        [2] = {1*period, 3*period, 3*period, 1*period};
    };

    local syncDelayTimes = {1*period, 31*period};

    local data = codeBase4;
    local delayTimes = {};
    for i = 1, 12 do
        local trit = bit.band ( data, 2 ); -- B11
        appendTable ( delayTimes, tritDelayTimes [trit] );
        data = bit.arshift ( data, 2 ); -- next trit
    end
    
    -- print period sequence for conversion to rpi-rf
    -- 13 is '0'
    -- 31 is '1'
--    local t = {};
--    for i = 1, #delayTimes do
--        table.insert ( t, delayTimes [i] / period );
--    end
--    print ( "sequence=", table.concat ( t ) );
    
    appendTable ( delayTimes , syncDelayTimes );
    
    -- asynchron
    gpio.serout ( pin, 1, delayTimes, repeats, function () isSending = false; end );

end

local function dequeueCommand ()

    if ( #M.queue > 0 and not isSending ) then
        isSending = true;
        local code = table.remove ( M.queue, 1 );
        print ( "[RF] loop: code=", code );
        sendCode ( code, espConfig.node.appCfg.rfpin, espConfig.node.appCfg.rfrepeats, espConfig.node.appCfg.rfperiod );
    end

end

local function queueCommand ( device, state )

    -- print ( "[RF] device=", device, " state=", state );

    local codes = {

            -- Fernbedienung 1 - Kueche
            -- DIP 123!4!5
            lampKitchenLongStrip    = { ON = 18218, OFF = 18222 }, -- 1/A
            lampKitchenShortStrip   = { ON = 19190, OFF = 19194 }, -- 1/B
            noName1C                = { ON = 19514, OFF = 19518 }, -- 1/C
            noName1D                = { ON = 19622, OFF = 19626 }, -- 1/D

            -- Fernbedienung 2 - Wohnzimmer
            -- DIP 1!2!3!45
            lampStudyPillar         = { ON = 171308, OFF = 171312 }, -- 2/A
            lampLoungeWhiteBall     = { ON = 172280, OFF = 172284 }, -- 2/B
            lampLoungeBlackBowl     = { ON = 172604, OFF = 172608 }, -- 2/C
            lampLoungeReading       = { ON = 172712, OFF = 172716 }, -- 2/D

            -- Fernbedienung 3 - Terrarium
            -- DIP !1!2345
            noName3A                = { ON = 473114, OFF = 473118 }, -- 3/A
            noName3B                = { ON = 474086, OFF = 474090 }, -- 3/A
            lamp1                   = { ON = 474410, OFF = 474414 }, -- 3/A
            noName3D                = { ON = 474518, OFF = 474522 }, -- 3/A

    -- Fernbedienung 4 - Nina
    -- DIP !1234!5

    };

    local deviceCodes = codes [device];
    if ( deviceCodes and (state == "ON" or state == "OFF" ) ) then
        local code = deviceCodes [state];
        gpio.write ( espConfig.node.appCfg.ledpin, state == "ON" and gpio.HIGH or gpio.LOW );
        print ( "[RF] send: code=", code );
        -- sendCode ( code );
        table.insert ( M.queue, code );
    end

end

--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=", topic, " payload=", payload );
    local topicParts = util.splitTopic ( topic );
    local device = topicParts [#topicParts];
    queueCommand ( device, payload );

end

function M.offline ( client )

    print ( "[APP] offline" );
    
    return true; -- restart mqtt connection
    
end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded", moduleName )

gpio.mode ( espConfig.node.appCfg.rfpin, gpio.OUTPUT );
gpio.write ( espConfig.node.appCfg.rfpin, gpio.LOW );

gpio.mode ( espConfig.node.appCfg.ledpin, gpio.OUTPUT );
gpio.write ( espConfig.node.appCfg.ledpin, gpio.LOW );

M.queue = {};
tmr.alarm ( espConfig.node.timer.queue, espConfig.node.timer.queuePeriod, tmr.ALARM_AUTO, function () dequeueCommand () end ) -- timer_id, interval_ms, mode, callback


return M;

-------------------------------------------------------------------------------