--------------------------------------------------------------------
--
-- nodes@home/luaNodes/ironNode
-- author: andreas at jungierek dot de
-- LICENSE http://opensource.org/licenses/MIT
--
--------------------------------------------------------------------
-- junand 11.11.2020

local moduleName = ...;
local M = {};
_G [moduleName] = M;

--local gpio, tmr, bit, rotary, u8g2, pwm = gpio, tmr, bit, rotary, u8g2, pwm;

-------------------------------------------------------------------------------
--  Settings

local display = {};
display.height = nodeConfig.appCfg.resolution.height;
display.width = nodeConfig.appCfg.resolution.width;
display.sdaPin = nodeConfig.appCfg.display.sdaPin;
display.sclPin = nodeConfig.appCfg.display.sclPin;

local max6675 = {};
max6675.csPin = nodeConfig.appCfg.max6675.csPin;
max6675.sckPin = nodeConfig.appCfg.max6675.sckPin;
max6675.misoPin = nodeConfig.appCfg.max6675.misoPin;
max6675.DELAY = 2; -- us

local rot = {};
rot.channel = 0;
rot.outAPin = nodeConfig.appCfg.rotary.outAPin;
rot.outBPin = nodeConfig.appCfg.rotary.outBPin;
rot.switchPin = nodeConfig.appCfg.rotary.switchPin;

local rotaryEventType = {
    [rotary.PRESS] = "PRESS",
    [rotary.LONGPRESS] = "LONGPRESS",
    [rotary.RELEASE] = "RELEASE",
    [rotary.TURN] = "TURN",
    [rotary.CLICK] = "CLICK",
    [rotary.DBLCLICK] = "DBLCLICK",
}

local retain = nodeConfig.mqtt.retain;
local NO_RETAIN = 0;
local qos = nodeConfig.mqtt.qos or 1;

local ssrPin = nodeConfig.appCfg.ssrPin;
local activeHigh = nodeConfig.appCfg.activeHigh;
if ( activeHigh == nil ) then activeHigh = true end;
local SOCKET_ON = activeHigh and gpio.HIGH or gpio.LOW;
local SOCKET_OFF = activeHigh and gpio.LOW or gpio.HIGH;

local loopPeriod = nodeConfig.timer.loopPeriod; -- ms

local pid = {};
pid.dT = loopPeriod / 1000; -- period in sec
pid.Kp = nodeConfig.appCfg.pid.Kp;
pid.Ki = nodeConfig.appCfg.pid.Ki * pid.dT;
pid.Kd = nodeConfig.appCfg.pid.Kd / pid.dT;
pid.PID_RANGE = nodeConfig.appCfg.pid.functionalrange; -- K
pid.PID_MAX_OUT = 1023 / (nodeConfig.appCfg.pid.pwmScale or 1);
pid.AUTOTUNE_TIMEOUT = nodeConfig.appCfg.autotune.timeout; -- min
pid.AUTOTUNE_MAXTEMPDIFF = nodeConfig.appCfg.autotune.maxtempdiff; -- K
pid.AUTOTUNE_STRATEGY = nodeConfig.appCfg.autotune.strategy;

local temp = {};
temp.mqttPeriod = 2000;
temp.N = temp.mqttPeriod / loopPeriod;
temp.series = {}; for i = 1, temp.N do temp.series [i] = 0 end
temp.index = 1;

----------------------------------------------------------------------------------------
-- private

local target = nodeConfig.appCfg.target;

local hysteresis = 0.5;

local GRAD = string.char ( 176 );

local loopTimer = tmr.create ();

STATE_IDLE = "idle";
STATE_HEATING = "heating";
STATE_AUTOTUNE = "autotune";
local state = STATE_IDLE;

SSR_STATE_ON = "on";
SSR_STATE_OFF = "off";
SSR_STATE_PWM = "pwm";
local ssrState = SSR_STATE_OFF;

local lastRotaryPos = 0;

local lastPidTemp;
local iTerm, dTerm;

local abortAutotune = false;

local verbose = false;

----------------------------------------------------------------------------------------
-- private functions

local function publishValue ( client, topic, temperature )

    --print ( "[APP] publish: t=" .. temperature .. " topic=" .. topic );

    local payload = ('{"state":"%s","ssr":"%s","temperature":%.1f,"target":%d,"unit":"°C"}'):format ( state, ssrState, temperature, target ); 

    --print ( "[APP] payload=" .. payload );

    client:publish ( topic .. "/value/temperature", payload, NO_RETAIN, retain,
        function ( client )
        end
    );

end

local function displayValue ( temperature )

    --print ( "[APP] displayValue: t=" .. temperature .. " target=" .. target );

    local d = display.display;

    --local t1 = ('%.1f'):format ( temperature + 0.05 ) .. GRAD;
    local t1 = ('%d'):format ( temperature + 0.5 ) .. GRAD;
    local t2 = ('%d'):format ( target ) .. GRAD;

    d:clearBuffer ();

    -- display:drawFrame ( 1, 1, 64, 16 );
    -- display:drawBox ( 64, 1, 64, 16 );

    d:setFont ( u8g2.font_fur20_tf );
    d:setFontPosTop ();
    local y = 8;
    local x1 = 1;
    local x2 = display.width - d:getStrWidth ( t2 ) - x1;
    d:drawStr ( x1, y, t1 );
    d:drawStr ( x2, y, t2 );

    --display:drawStr ( 1, 35, "Hallo" );

    d:setFont ( u8g2.font_6x10_tf );
    d:drawStr ( x1, 0, state );
    d:drawStr ( 55, 0, ssrState );
    d:drawStr ( x2, 0, "Target" );

    d:sendBuffer ();

end

local function readIronTemp ()

    local word = 0;

    -- Force CS low to output the first bit on the SO pin. A
    -- complete serial interface read requires 16 clock cycles.
    -- Read the 16 output bits on the falling edge of the clock.
    -- The first bit, D15, is a dummy sign bit and is always
    -- zero. Bits D14–D3 contain the converted temperature in
    -- the order of MSB to LSB. Bit D2 is normally low and
    -- goes high when the thermocouple input is open. D1 is
    -- low to provide a device ID for the MAX6675 and bit D0
    -- is three-state.

    gpio.write ( max6675.csPin, gpio.LOW );      --> activate the chip
    tmr.delay ( max6675.DELAY );                 --> 1us Delay

    for i = 15, 0, -1 do

        local b = gpio.read ( max6675.misoPin );
        -- print ( "[APP] readIronTemp: i=" .. i .. " b=" .. b .. " word=" .. tohex ( word, 4 ) );
        if ( b == 1 ) then
            word = bit.set ( word, i );
        end

        gpio.write ( max6675.sckPin, gpio.HIGH );
        tmr.delay ( max6675.DELAY );
        gpio.write ( max6675.sckPin, gpio.LOW );
        tmr.delay ( max6675.DELAY );

    end

    gpio.write ( max6675.csPin, gpio.HIGH );

    --print ( "[APP] readIronTemp: word=" .. tohex ( word, 4 ) );

    if ( bit.isset ( word, 2 ) ) then                      -- refer MAX6675 Datasheet
        print ( "[APP] readIronTemp: Sensor not connected" )
        return nil;
    end

    local t = bit.rshift ( bit.band ( word, 0x7FF8 ), 3 ) * 0.25;

    --print ( "[APP] readIronTemp: t=" ..  t );

    --temp.avg = temp.avg - (temp.series [temp.index] - t ) / temp.N;
    --temp.series [temp.index] = t;
    --temp.index = temp.index + 1;
    --if ( temp.index > temp.N ) then
    --    temp.index = 1;
    --end
    --return temp.avg;

    return t;

end

local function constrain ( value, min, max )

    return math.max ( math.min ( value, max ), min );

end

local function setPwmDuty ( out )

    out = constrain ( activeHigh and out or (1023 - out), 0, 1023 );
    pwm.setduty ( ssrPin, out );

    return out;

end

local function autotune ( nCycles, target )

    print ( "[APP] autotune: start" );

    local bias = pid.PID_MAX_OUT / 2;
    local d = pid.PID_MAX_OUT / 2;
    local Ku, Tu, Kp, Ki, Kd;

    local heating = false;

    local cycles = 0;

    --local tsHeatingOff = tmr.time ();
    local tsHeatingOff = tmr.now (); -- us
    local tsHeatingOn = tsHeatingOff;
    local timeHeating = 0;
    local timeCooling = 0;

    local min, max = 10000, 0;

    tmr.create ():alarm ( loopPeriod, tmr.ALARM_AUTO,
        function ( timer )

            local t = readIronTemp ();
            min = math.min ( min, t );
            max = math.max ( max, t );

            if ( heating == true and t > target ) then
                heating = false;
                setPwmDuty ( bias - d );
                --tsHeatingOff = tmr.time (); -- sec
                tsHeatingOff = tmr.now (); -- us
                timeHeating = tsHeatingOff - tsHeatingOn;
                if ( timeHeating < 0 ) then
                    timeHeating = timeHeating + 2147483647;
                end
                max = target;
            end
            if ( heating == false and t < target ) then
                heating = true;
                --tsHeatingOn = tmr.time (); -- sec
                tsHeatingOn = tmr.now (); -- us
                timeCooling = (tsHeatingOn - tsHeatingOff);
                if ( timeCooling < 0 ) then
                    timeCooling = timeCooling + 2147483647;
                end
                if ( cycles > 0 ) then
                    bias = bias + (d * (timeHeating - timeCooling)) / (timeHeating + timeCooling);
                    bias = constrain ( bias, 20, pid.PID_MAX_OUT - 20 );
                    if ( bias > pid.PID_MAX_OUT / 2 ) then
                        d = pid.PID_MAX_OUT - 1 - bias;
                    else
                        d = bias;
                    end
                    print ( "[APP] autotune: bias=" .. bias .. " d=" .. d .. " min=" .. min .. " max=" .. max );
                    if ( cycles > 2 ) then
                        Ku = (4 * d) / (3.14159 * (max - min)/2);
                        Tu = (timeCooling - timeHeating) / 1000000; -- sec
                        print ( "[APP] autotune: Ku=" .. Ku .. " Tu=" .. Tu );
                        if ( pid.AUTOTUNE_STRATEGY == "classic" ) then
                            Kp = 6 * Ku; Ki = 2 * Kp / Tu; Kd = Kp * Tu / 8;
                        elseif ( pid.AUTOTUNE_STRATEGY == "some_overshoot" ) then
                            Kp = 0.33 * Ku; Ki = 1 * Kp / Tu; Kd = Kp * Tu / 3;
                        elseif ( pid.AUTOTUNE_STRATEGY == "no_overshoot" ) then
                            Kp = 0.2 * Ku; Ki = 2 * Kp / Tu; Kd = Kp * Tu / 3;
                        end
                        print ( "[APP] autotune: " .. pid.AUTOTUNE_STRATEGY .. " -> Kp=" .. Kp .. " Ki=" .. Ki .. " Kd=" .. Kd );
                    end
                end
                setPwmDuty ( bias + d );
                cycles = cycles + 1;
                min = target;
            end

            print ( "[APP] autotune: t=" .. t .. " @ " .. pwm.getduty ( ssrPin ) .. " cycles=" .. cycles .. " bias=" .. bias .. " d=" .. d .. " tsHeatingOff=" .. tsHeatingOff .. " tsHeatingOn=" .. tsHeatingOn .. " timeCooling=" .. timeCooling .. " timeHeating=" .. timeHeating );

            if ( t > target + pid.AUTOTUNE_MAXTEMPDIFF ) then
                print ( "[APP] autotune: PID Autotune failed! Temperature too high t=" .. t .. " target=" .. target );
                timer:unregister ();
                pwm.close ( ssrPin );
                state = STATE_IDLE;
                return;
            end

            if ( (tmr.time () - tsHeatingOff / 1000000) + (tmr.time () - tsHeatingOn / 1000000) > pid.AUTOTUNE_TIMEOUT * 60 * 2 ) then -- sec
                print ( "[APP] autotune: PID Autotune failed! timeout" );
                timer:unregister ();
                pwm.close ( ssrPin );
                state = STATE_IDLE;
                return;
            end

            if ( cycles > nCycles ) then
                print ( "[APP] autotune: PID Autotune finished! Put the last Kp, Ki and Kd constants from above into configuration" );
                timer:unregister ();
                pwm.close ( ssrPin );
                state = STATE_IDLE;
                return;
            end

            if ( abortAutotune ) then
                abortAutotune = false;
                print ( "[APP] autotune: aborted" );
                timer:unregister ();
                pwm.close ( ssrPin );
                state = STATE_IDLE;
                return;
            end

        end
    );
end

local function rotaryon ( type, pos, when )

    --print ( "[APP] rotaryon: pos=" .. pos .. " event=" .. rotaryEventType [type] .. " time=" .. when );

    if ( type == rotary.LONGPRESS ) then
        if ( state == STATE_IDLE ) then
            state = STATE_AUTOTUNE;
        elseif ( state == STATE_AUTOTUNE ) then
            --state = STATE_IDLE;
            abortAutotune = true;
        end
        --print ( "state=" .. state );
    elseif ( type == rotary.CLICK ) then
        if ( state == STATE_IDLE ) then
            state = STATE_HEATING;
            -- init pid
        elseif ( state == STATE_HEATING ) then
            state = STATE_IDLE;
        end
        --print ( "state=" .. state );
    elseif ( type == rotary.TURN ) then
        local d = pos - lastRotaryPos;
        if ( d < -3 or d > 3 ) then -- every rotation step creates 4 on events
            -- for bettr pcb layout the rotation direction seems inverted
            target = target + ( d < 0 and 1 or -1 ); 
            lastRotaryPos = pos;
        end
        --print ( "target=" .. target );
    end
    
end

local function bangbang ( t )

    if ( t > target ) then
        if ( ssrState ~= SSR_STATE_OFF ) then
            ssrState = SSR_STATE_OFF;
            gpio.write ( ssrPin, SOCKET_OFF );
        end
    elseif ( t < target - hysteresis ) then
        if ( ssrState ~= SSR_STATE_ON ) then
            ssrState = SSR_STATE_ON;
            gpio.write ( ssrPin, SOCKET_ON );
        end
    end

end

--https://www.youtube.com/watch?v=zOByx3Izf5U https://github.com/pms67/PID
--https://courses.cs.washington.edu/courses/csep567/10wi/lectures/Lecture9.pdf


local function pidcontrol ( t )

    local d = target - t;

    if ( d > pid.PID_RANGE ) then
        bangbang ( t );
        --print ( "[APP] pid: out of functional range t=" .. t .. " target=" .. target );
    elseif ( d < -pid.PID_RANGE ) then
        print ( "[APP] pid: target to low t=" .. t .. " target=" .. target );
        state = STATE_IDLE;
    else

        local pTerm = pid.Kp * d;

        iTerm = pid.Ki * d + iTerm;
        iTerm = constrain ( iTerm, 0, pid.PID_MAX_OUT );

        --local K1 = 0.75;
        --dTerm = (1 - K1) * pid.Kd * (t - lastPidTemp) + K1 * dTerm;
        dTerm = pid.Kd * (lastPidTemp - t);

        local out = pTerm + iTerm + dTerm;

        if ( verbose ) then
            print ( "[APP] pid: target=" .. target .. " t=" .. t .. " d=" .. d .. " pTerm=" .. pTerm .. " iTerm=" .. iTerm .. " dTerm=" .. dTerm .. " out=" .. out );
        end

        setPwmDuty ( out );

    end

    lastPidTemp = t;

end

local function initPwm ()

    pwm.setup ( ssrPin, 500, activeHigh and 0 or 1023  ); -- 10 Hz
    pwm.start ( ssrPin );
    ssrState = SSR_STATE_PWM;

end

local function loop  ( client, topic )

    local t = readIronTemp ();

    if ( t ) then

        temp.series [temp.index] = t;
        temp.index = temp.index + 1;
    
        --print ( "[APP] loop: t=" ..  t .. " target=" .. target .. " state=" .. state .. " ssr=" .. ssrState .. " count=" .. publishCount .. " heap=" .. node.heap () );

        if ( state == STATE_IDLE ) then
            if ( ssrState ~= SSR_STATE_OFF ) then
                if ( ssrState == SSR_STATE_PWM ) then
                    pwm.close ( ssrPin );
                end
                ssrState = SSR_STATE_OFF;
            end
            if ( ssrState == SSR_STATE_OFF ) then
                gpio.write ( ssrPin, SOCKET_OFF );
            end
        elseif ( state == STATE_HEATING ) then
            if ( ssrState ~= SSR_STATE_PWM ) then
                initPwm ();
                iTerm = 0;
                dTerm = 0;
                lastPidTemp = t;
            end
            pidcontrol ( t );
            --bangbang ( t );
        elseif ( state == STATE_AUTOTUNE ) then
            if ( ssrState ~= SSR_STATE_PWM ) then
                initPwm ();
                autotune ( 10, target );
            end
        end

        if ( temp.index > temp.N ) then
            local avg = 0;
            for i = 1, temp.N do
                avg = avg + temp.series [i]
            end
            avg = avg / temp.N;
            displayValue ( avg );
            publishValue ( client, topic, avg );
            temp.index = 1;
        end

    end

end
--------------------------------------------------------------------
-- public
-- mqtt callbacks

function M.start ( client, topic )

    print ( "[APP] start" );

    local speed = i2c.setup ( 0, display.sdaPin, display.sclPin, i2c.SLOW );
    print ( "[APP] i2c intialized with speed=" .. speed );

    local resolution = display.width .. "x" .. display.height;
    print ( "[APP] intialize display with sda=" .. display.sdaPin .. " scl=" .. display.sclPin .. " res=" .. resolution );
    display.display = u8g2 ["ssd1306_i2c_" .. resolution .. "_noname"] ( 0, 0x3C );
    -- https://www.amazon.de/gp/product/B01L9GC470/ref=ppx_yo_dt_b_asin_title_o03_s00?ie=UTF8&th=1

    gpio.mode ( max6675.csPin, gpio.OUTPUT );
    gpio.write ( max6675.csPin, gpio.HIGH ); -- disable /cs
    gpio.mode ( max6675.sckPin, gpio.OUTPUT );
    gpio.write ( max6675.sckPin, gpio.LOW );
    gpio.mode ( max6675.misoPin, gpio.INPUT );

    rotary.setup ( rot.channel, rot.outAPin, rot.outBPin, rot.switchPin );
    rotary.on ( rot.channel, rotary.LONGPRESS + rotary.TURN + rotary.CLICK, rotaryon );

    gpio.mode ( ssrPin, gpio.OPENDRAIN );
    gpio.write ( ssrPin, SOCKET_OFF );

    loopTimer:alarm ( loopPeriod, tmr.ALARM_AUTO, function () loop ( client, topic ) end );

end

function M.connect ( client, topic )

    print ( "[APP] connect" );

end

function M.offline ( client )

    print ( "[APP] offline" );

    return true; -- restart mqtt

end

function M.message ( client, topic, payload )

    print ( "[APP] message: topic=" .. topic .. " payload=" .. payload );

    local detailTopic = topic:sub ( nodeConfig.topic:len () + 1 );

    if ( detailTopic == "/set" ) then

        local ok, json = pcall ( sjson.decode, payload );
        if ( ok ) then

            if ( json.pid ) then
                pid.Kp = json.pid.Kp;
                pid.Ki = json.pid.Ki * pid.dT;
                pid.Kd = json.pid.Kd / pid.dT;
            end

            if ( json.target ) then
                target = json.target;
            end

            if ( json.verbose ~= nil ) then
                verbose = json.verbose;
            end
            
        end

    end

end

function M.periodic ( client, topic )

    print ( "[APP] periodic: topic=" .. topic );

end

-------------------------------------------------------------------------------
-- main

print ( "[MODULE] loaded: " .. moduleName )

return M;

-------------------------------------------------------------------------------