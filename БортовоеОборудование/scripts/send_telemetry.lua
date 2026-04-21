-- usb adapter подключен к uart4, необходимые изменения параметров:
-- uart4 (serial6), uart8 (serial5): user logic, 5v tolerent
-- SERIAL6_BAUD = 115 (115200)
-- SERIAL6_PROTOCOL = 28 (Scripting)
-- PROTOCOL = 28 должен быть только на 1 порту (сейчас uart4)

-- Дополнительно проверить:
-- SCR_ENABLE = 1

local CONFIG = {
    UART_PORT = 0,
    UPDATE_MS = 500,
    UART_BAUD_RATE = 115200
}
local uart = nil

function send_telemetry()
    if not uart then return end

    local pos = get_position()
    local airspeed = get_airspeed()

    local msg

    if pos and airspeed then
        msg = string.format(
            "POS,%.7f,%.7f,%.2f,%.2f\n",
            pos.lat,
            pos.lng,
            pos.alt,
            airspeed or -1
        )
    elseif pos then
        msg = string.format(
            "POS,%.7f,%.7f,%.2f\n",
            pos.lat,
            pos.lng,
            pos.alt
        )
    elseif airspeed then
        msg = string.format(
            "AS,%.2f\n",
            airspeed or -1
        )
    else
        msg = "NO_DATA\n"
    end

    uart_write_string(uart, msg)
end

function uart_write_string(uart, str)
    for i = 1, #str do
        uart:write(string.byte(str, i))
    end
end

function get_position()
    local loc = ahrs:get_location()
    if not loc then return nil end

    return {
        lat = loc:lat() / 1e7,
        lng = loc:lng() / 1e7,
        alt = loc:alt() / 100,
    }
end

function get_airspeed()
    return ahrs:airspeed_estimate()
end

function init()
    uart = serial:find_serial(CONFIG.UART_PORT)

    if uart then
        uart:begin(CONFIG.UART_BAUD_RATE)
        gcs:send_text(6, "UART OK")
    else
        gcs:send_text(4, "UART FAIL")
    end
end

function update()
    if not uart then
        init()
    end

    send_telemetry()

    return update, CONFIG.UPDATE_MS
end

return update, 1000