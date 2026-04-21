-- Читает до 20 точек из /APM/scripts/waypoints.csv и строит по ним миссию

local CONFIG = {
    FILE_PATH = "/APM/scripts/waypoints.csv",
    MAX_POINTS = 20,
    UPDATE_MS = 1000
}

local STATE = {
    loaded = false
}

local MAV_CMD_NAV_WAYPOINT = 16
local MAV_FRAME_GLOBAL_RELATIVE_ALT = 3

local function send_info(text)
    gcs:send_text(6, text)
end

local function send_warn(text)
    gcs:send_text(4, text)
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_csv_line(line)
    line = trim(line)
    if line == "" then
        return nil
    end

    -- пропускаем заголовок
    if line:lower():find("lat", 1, true) then
        return nil
    end

    local lat_str, lon_str, alt_str = line:match("^([^,]+),([^,]+),([^,]+)$")
    if not lat_str then
        return nil
    end

    local lat = tonumber(trim(lat_str))
    local lon = tonumber(trim(lon_str))
    local alt = tonumber(trim(alt_str))

    if not lat or not lon or not alt then
        return nil
    end

    return {
        lat = lat,
        lon = lon,
        alt = alt
    }
end

local function read_points_from_csv(path, max_points)
    local file = io.open(path, "r")
    if not file then
        return nil, "Не удалось открыть файл: " .. path
    end

    local points = {}
    for line in file:lines() do
        local point = parse_csv_line(line)
        if point then
            points[#points + 1] = point
            if #points >= max_points then
                break
            end
        end
    end

    file:close()

    if #points == 0 then
        return nil, "В файле нет валидных точек"
    end

    return points, nil
end

local function build_mission_item(template, seq, point)
    -- Берём существующий mission item как шаблон
    local item = template

    item:command(MAV_CMD_NAV_WAYPOINT)
    item:frame(MAV_FRAME_GLOBAL_RELATIVE_ALT)
    item:current(0)
    item:seq(seq)

    -- стандартные параметры WAYPOINT
    item:param1(0)  -- hold time
    item:param2(0)  -- acceptance radius
    item:param3(0)  -- pass radius
    item:param4(0)  -- yaw

    -- lat/lon в int32 * 1e7, alt в метрах
    item:x(math.floor(point.lat * 10000000))
    item:y(math.floor(point.lon * 10000000))
    item:z(point.alt)

    return item
end

local function clear_and_prepare_mission()
    local ok = mission:clear()
    if not ok then
        return false, "mission:clear() вернул false"
    end

    -- После clear HOME должен остаться как item 0.
    -- В ArduPilot mission API item 0 зарезервирован под home,
    -- и в примерах Lua работа идёт относительно него. :contentReference[oaicite:1]{index=1}
    if mission:num_commands() < 1 then
        return false, "После очистки mission:num_commands() < 1"
    end

    return true, nil
end

local function load_points_into_mission(points)
    local ok, err = clear_and_prepare_mission()
    if not ok then
        return false, err
    end

    local home_item = mission:get_item(0)
    if not home_item then
        return false, "Не удалось получить HOME item"
    end

    for i = 1, #points do
        -- каждый раз получаем копию home как шаблон
        local item = mission:get_item(0)
        if not item then
            return false, "Не удалось получить шаблон mission item"
        end

        item = build_mission_item(item, i, points[i])

        -- append в конец миссии:
        -- официальный пример ArduPilot использует именно
        -- mission:set_item(mission:num_commands(), item) для добавления новых точек. :contentReference[oaicite:2]{index=2}
        local set_ok = mission:set_item(mission:num_commands(), item)
        if not set_ok then
            return false, string.format("Не удалось записать waypoint %d", i)
        end
    end

    return true, nil
end

local function vehicle_ready_for_mission_edit()
    if arming:is_armed() then
        return false, "Нельзя менять миссию в armed-состоянии"
    end

    local home = ahrs:get_home()
    if not home then
        return false, "HOME ещё недоступен"
    end

    if home:lat() == 0 then
        return false, "HOME ещё не установлен"
    end

    return true, nil
end

local function load_mission_once()
    local ready, reason = vehicle_ready_for_mission_edit()
    if not ready then
        send_warn(reason)
        return false
    end

    local points, read_err = read_points_from_csv(CONFIG.FILE_PATH, CONFIG.MAX_POINTS)
    if not points then
        send_warn(read_err)
        return false
    end

    local ok, load_err = load_points_into_mission(points)
    if not ok then
        send_warn(load_err)
        return false
    end

    send_info(string.format("Миссия загружена: %d точек", #points))
    return true
end

function update()
    if not STATE.loaded then
        STATE.loaded = load_mission_once()
    end

    return update, CONFIG.UPDATE_MS
end

return update, CONFIG.UPDATE_MS