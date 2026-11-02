local imgui = require 'mimgui'
local encoding = require 'encoding'
local ffi = require 'ffi'
local cjson = require 'cjson' 

local renderWindow = imgui.new.bool(false)

local newName = imgui.new.char[256]()
local newGroup = imgui.new.char[256]()
local newLib = imgui.new.char[256]()

local configPath = getWorkingDirectory() .. '\\config\\setanim.json'
local configDir = getWorkingDirectory() .. '\\config'

local default_sets_count = 10

local function makeDefaultSets()
    return {
        {name = "Дефолт",  group = "man",      lib = nil, bind = {}},
        {name = "CJ",      group = "PLAYER",   lib = nil, bind = {}},
        {name = "Берсерк", group = "berserk",  lib = "berserk", bind = {}},
        {name = "Фрирен",  group = "friren1",  lib = "friren1", bind = {}},
        {name = "Друид",   group = "druid",    lib = "druid", bind = {}},
        {name = "Личь",    group = "lich1",    lib = "lich1", bind = {}},
        {name = "Викинг",  group = "viking1",  lib = "viking1", bind = {}},
        {name = "Обратень",group = "werewolf1",lib = "werewolf1", bind = {}},
        {name = "Ведьма",  group = "witch1",   lib = "witch1", bind = {}},
        {name = "Роллер",  group = "skatef",   lib = "skatef", bind = {}},
    }
end

local defaultConfig = {
    isAnimEnabled = false,
    activeSetIdx = 1,
    bindKey = {},
    sets = makeDefaultSets()
}

local config = {}

local function saveConfig()
    if not doesDirectoryExist(configDir) then createDirectory(configDir) end
    local f = io.open(configPath, 'w')
    if f then
        f:write(cjson.encode(config))
        f:close()
    end
end

local function loadConfig()
    local f = io.open(configPath, 'r')
    if f then
        local content = f:read('*a')
        f:close()
        local status, result = pcall(cjson.decode, content)
        if status and result and type(result.sets) == "table" then
            config = result
            if config.isAnimEnabled == nil then config.isAnimEnabled = false end
            if type(config.bindKey) == "number" then
                config.bindKey = config.bindKey == 0 and {} or { config.bindKey }
            end
            if type(config.bindKey) ~= "table" then config.bindKey = {} end
            for _, s in ipairs(config.sets) do
                if type(s.bind) == "number" then
                    s.bind = s.bind == 0 and {} or { s.bind }
                elseif type(s.bind) ~= "table" then
                    s.bind = {}
                end
            end
        else
            config = defaultConfig
            saveConfig()
        end
    else
        config = defaultConfig
        saveConfig()
    end
end

loadConfig()
local activeSetIdx = config.activeSetIdx or 1
local isAnimEnabled = imgui.new.bool(config.isAnimEnabled)

local bindingTarget = nil
local pendingCombo = {}

local keyNames = {
    [1] = "ЛКМ", [2] = "ПКМ", [3] = "Колесо", [4] = "СКМ", [5] = "X1", [6] = "X2",
    [8] = "Backspace", [9] = "Tab", [13] = "Enter", [16] = "Shift", [17] = "Ctrl",
    [18] = "Alt", [19] = "Pause", [20] = "CapsLock", [27] = "Esc", [32] = "Space",
    [33] = "PageUp", [34] = "PageDown", [35] = "End", [36] = "Home",
    [37] = "Left", [38] = "Up", [39] = "Right", [40] = "Down",
    [45] = "Insert", [46] = "Delete",
    [48] = "0", [49] = "1", [50] = "2", [51] = "3", [52] = "4", [53] = "5",
    [54] = "6", [55] = "7", [56] = "8", [57] = "9",
    [65] = "A", [66] = "B", [67] = "C", [68] = "D", [69] = "E", [70] = "F",
    [71] = "G", [72] = "H", [73] = "I", [74] = "J", [75] = "K", [76] = "L",
    [77] = "M", [78] = "N", [79] = "O", [80] = "P", [81] = "Q", [82] = "R",
    [83] = "S", [84] = "T", [85] = "U", [86] = "V", [87] = "W", [88] = "X",
    [89] = "Y", [90] = "Z",
    [96] = "Numpad0", [97] = "Numpad1", [98] = "Numpad2", [99] = "Numpad3",
    [100] = "Numpad4", [101] = "Numpad5", [102] = "Numpad6", [103] = "Numpad7",
    [104] = "Numpad8", [105] = "Numpad9",
    [106] = "Numpad*", [107] = "Numpad+", [109] = "Numpad-", [110] = "Numpad.",
    [111] = "Numpad/",
    [112] = "F1", [113] = "F2", [114] = "F3", [115] = "F4", [116] = "F5",
    [117] = "F6", [118] = "F7", [119] = "F8", [120] = "F9", [121] = "F10",
    [122] = "F11", [123] = "F12",
    [160] = "LShift", [161] = "RShift", [162] = "LCtrl", [163] = "RCtrl",
    [164] = "LAlt", [165] = "RAlt",
    [186] = ";", [187] = "=", [188] = ",", [189] = "-", [190] = ".",
    [191] = "/", [192] = "`", [219] = "[", [220] = "\\", [221] = "]",
    [222] = "'",
}

local function keyName(code)
    return keyNames[code] or ("K" .. tostring(code))
end

local function comboToString(combo)
    if not combo or #combo == 0 then return nil end
    local parts = {}
    for _, code in ipairs(combo) do
        table.insert(parts, keyName(code))
    end
    return table.concat(parts, " + ")
end

local C = {
    panel       = imgui.ImVec4(0.078, 0.102, 0.157, 0.95),
    border      = imgui.ImVec4(0.314, 0.549, 1.000, 0.180),
    accent      = imgui.ImVec4(0.302, 0.553, 1.000, 1.000),
    accent_hov  = imgui.ImVec4(0.302, 0.553, 1.000, 1.000),
    accent_act  = imgui.ImVec4(0.227, 0.435, 0.878, 1.000),
    text        = imgui.ImVec4(0.902, 0.925, 0.961, 1.000),
    text_dim    = imgui.ImVec4(0.478, 0.541, 0.627, 1.000),
    danger      = imgui.ImVec4(1.000, 0.302, 0.427, 1.000),
    success     = imgui.ImVec4(0.184, 0.820, 0.541, 1.000),
    input_bg    = imgui.ImVec4(0.000, 0.000, 0.000, 0.250),
}

local function pushWindowColors()
    imgui.PushStyleColor(imgui.Col.WindowBg,             C.panel)
    imgui.PushStyleColor(imgui.Col.Border,               C.border)
    imgui.PushStyleColor(imgui.Col.FrameBg,              C.input_bg)
    imgui.PushStyleColor(imgui.Col.FrameBgHovered,       imgui.ImVec4(0.302,0.553,1.0,0.10))
    imgui.PushStyleColor(imgui.Col.FrameBgActive,        imgui.ImVec4(0.302,0.553,1.0,0.18))
    imgui.PushStyleColor(imgui.Col.TitleBg,              imgui.ImVec4(0.078,0.102,0.157,1.0))
    imgui.PushStyleColor(imgui.Col.TitleBgActive,        imgui.ImVec4(0.105,0.140,0.220,1.0))
    imgui.PushStyleColor(imgui.Col.ScrollbarBg,          imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.ScrollbarGrab,        imgui.ImVec4(0.302,0.553,1.0,0.25))
    imgui.PushStyleColor(imgui.Col.ScrollbarGrabHovered, imgui.ImVec4(0.302,0.553,1.0,0.45))
    imgui.PushStyleColor(imgui.Col.ScrollbarGrabActive,  imgui.ImVec4(0.302,0.553,1.0,0.65))
    imgui.PushStyleColor(imgui.Col.CheckMark,            C.accent)
    imgui.PushStyleColor(imgui.Col.Button,               imgui.ImVec4(0.302,0.553,1.0,0.15))
    imgui.PushStyleColor(imgui.Col.ButtonHovered,        imgui.ImVec4(0.302,0.553,1.0,0.30))
    imgui.PushStyleColor(imgui.Col.ButtonActive,         imgui.ImVec4(0.302,0.553,1.0,0.45))
    imgui.PushStyleColor(imgui.Col.Separator,            C.border)
    imgui.PushStyleColor(imgui.Col.Text,                 C.text)
    imgui.PushStyleColor(imgui.Col.TextDisabled,         C.text_dim)
end
local WINDOW_COLORS_COUNT = 17

local function popWindowColors()
    imgui.PopStyleColor(WINDOW_COLORS_COUNT)
end

local function applyAnimState()
    lua_thread.create(function()
        if config.isAnimEnabled then
            local set = config.sets[activeSetIdx]
            if set then
                if set.lib and set.lib ~= "" then
                    requestAnimation(set.lib)
                    local timeout = 0
                    while not hasAnimationLoaded(set.lib) do
                        wait(10)
                        timeout = timeout + 10
                        if timeout >= 5000 then break end
                    end
                end
                if set.group and set.group ~= "" then
                    setAnimGroupForChar(PLAYER_PED, set.group)
                end
            end
            clearCharTasksImmediately(PLAYER_PED)
        else
            setAnimGroupForChar(PLAYER_PED, "man")
        end
    end)
end

local function forceRestoreAnimation()
    if not config.isAnimEnabled then return end
    if not sampIsLocalPlayerSpawned() then return end
    
    local set = config.sets[activeSetIdx]
    if not set or not set.group then return end
    
    setAnimGroupForChar(PLAYER_PED, set.group)
end

local function notifyChat(text)
    local cp1251_text = encoding.UTF8:decode(text)
    sampAddChatMessage("{4d8dff}[ArzSet] {ffffff}" .. cp1251_text, 0xFFFFFF)
end

local function activateSet(idx)
    if not config.sets[idx] then idx = 1 end
    activeSetIdx = idx
    config.activeSetIdx = idx
    saveConfig()
    
    if config.isAnimEnabled then
        applyAnimState()
        notifyChat("Активирован сет: " .. config.sets[idx].name)
    end
end

local function comboEquals(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function dedupBinds(targetIdx, combo)
    if #combo == 0 then return end
    for i, s in ipairs(config.sets) do
        if i ~= targetIdx and s.bind and comboEquals(s.bind, combo) then
            s.bind = {}
        end
    end
end

local function collectPressedKeys()
    local combo = {}
    for i = 1, 255 do
        if isKeyDown(i) then
            local dup = false
            for _, existing in ipairs(combo) do
                if existing == i then dup = true; break end
            end
            if not dup then table.insert(combo, i) end
        end
    end
    return combo
end

local function isComboTriggered(combo)
    if not combo or #combo == 0 then return false end
    local justPressed = false
    for _, key in ipairs(combo) do
        if not isKeyDown(key) then return false end
        if isKeyJustPressed(key) then justPressed = true end
    end
    return justPressed
end

imgui.OnFrame(function() return renderWindow[0] end,
    function(player)
        local io = imgui.GetIO()
        local isRMB = io.MouseDown[1]
        
        if isRMB then
            io.MouseDown[0] = false
            io.WantCaptureMouse = false
        end

        pushWindowColors()

        imgui.SetNextWindowSize(imgui.ImVec2(520, 0), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(500, 350), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

        imgui.Begin("ArzSet", renderWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize)

        if imgui.Checkbox("Включить подмену", isAnimEnabled) then
            config.isAnimEnabled = isAnimEnabled[0]
            saveConfig()
            applyAnimState()
        end

        imgui.Dummy(imgui.ImVec2(0, 3))
        imgui.PushStyleColor(imgui.Col.Text, C.text_dim)
        imgui.Text("ОБЩИЙ БИНД (вкл/выкл подмену)")
        imgui.PopStyleColor()

        local toggleLabel = comboToString(config.bindKey) and ("Изменить [" .. comboToString(config.bindKey) .. "]") or "Назначить комбинацию"
        if imgui.Button(toggleLabel, imgui.ImVec2(320, 0)) then
            bindingTarget = -1
            pendingCombo = {}
        end

        if config.bindKey and #config.bindKey > 0 then
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(1,0.302,0.427,0.10))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,0.302,0.427,0.25))
            imgui.PushStyleColor(imgui.Col.Text,          C.danger)
            if imgui.Button("Сброс##globalreset", imgui.ImVec2(80, 0)) then
                config.bindKey = {}
                saveConfig()
            end
            imgui.PopStyleColor(3)
        end

        imgui.Dummy(imgui.ImVec2(0, 5))
        imgui.Separator()
        imgui.Dummy(imgui.ImVec2(0, 5))

        imgui.PushStyleColor(imgui.Col.Text, C.text_dim)
        imgui.Text("НАБОРЫ (у каждого свой бинд)")
        imgui.PopStyleColor()

        for i, set in ipairs(config.sets) do
            if imgui.RadioButtonBool(set.name .. "##rb" .. i, activeSetIdx == i) then
                activateSet(i)
            end

            imgui.SameLine(170)
            local btnLabel
            if bindingTarget == i then
                btnLabel = "..."
            else
                local comboStr = comboToString(set.bind)
                btnLabel = comboStr and ("[" .. comboStr .. "]") or "Бинд"
            end
            if imgui.Button(btnLabel .. "##b" .. i, imgui.ImVec2(180, 0)) then
                bindingTarget = i
                pendingCombo = {}
            end

            if set.bind and #set.bind > 0 then
                imgui.SameLine()
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(1,0.302,0.427,0.10))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,0.302,0.427,0.25))
                imgui.PushStyleColor(imgui.Col.Text,          C.danger)
                if imgui.Button("✕##breset" .. i, imgui.ImVec2(24, 0)) then
                    set.bind = {}
                    saveConfig()
                end
                imgui.PopStyleColor(3)
            end

            if i > default_sets_count then
                imgui.SameLine(400)
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(1,0.302,0.427,0.10))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,0.302,0.427,0.25))
                imgui.PushStyleColor(imgui.Col.Text,          C.danger)
                if imgui.Button("X##del" .. i, imgui.ImVec2(24, 0)) then
                    table.remove(config.sets, i)
                    if activeSetIdx == i then
                        activateSet(1)
                    elseif activeSetIdx > i then
                        activeSetIdx = activeSetIdx - 1
                        config.activeSetIdx = activeSetIdx
                        saveConfig()
                    else
                        saveConfig()
                    end
                    if bindingTarget == i then bindingTarget = nil end
                    break
                end
                imgui.PopStyleColor(3)
            end
        end

        if bindingTarget ~= nil then
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))

            imgui.PushStyleColor(imgui.Col.Text, C.success)
            local tgtName = bindingTarget == -1 and "ОБЩИЙ БИНД" or ("сет «" .. config.sets[bindingTarget].name .. "»")
            imgui.Text("Назначение для: " .. tgtName)
            imgui.PopStyleColor()

            pendingCombo = collectPressedKeys()

            local previewStr = comboToString(pendingCombo) or "— зажмите клавиши —"
            imgui.PushStyleColor(imgui.Col.Text, C.accent)
            imgui.Text("Комбинация: [" .. previewStr .. "]")
            imgui.PopStyleColor()

            imgui.Dummy(imgui.ImVec2(0, 3))

            local canConfirm = #pendingCombo > 0
            if not canConfirm then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.3,0.3,0.3,0.3))
            end
            if imgui.Button("Подтвердить", imgui.ImVec2(150, 30)) and canConfirm then
                if bindingTarget == -1 then
                    config.bindKey = pendingCombo
                else
                    config.sets[bindingTarget].bind = pendingCombo
                    dedupBinds(bindingTarget, pendingCombo)
                end
                saveConfig()
                bindingTarget = nil
                pendingCombo = {}
            end
            if not canConfirm then
                imgui.PopStyleColor()
            end

            imgui.SameLine()
            if imgui.Button("Отмена", imgui.ImVec2(100, 30)) then
                bindingTarget = nil
                pendingCombo = {}
            end

            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(1,0.302,0.427,0.10))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,0.302,0.427,0.25))
            imgui.PushStyleColor(imgui.Col.Text,          C.danger)
            if imgui.Button("Сбросить бинд", imgui.ImVec2(140, 30)) then
                if bindingTarget == -1 then
                    config.bindKey = {}
                else
                    config.sets[bindingTarget].bind = {}
                end
                saveConfig()
                bindingTarget = nil
                pendingCombo = {}
            end
            imgui.PopStyleColor(3)
        end

        imgui.Dummy(imgui.ImVec2(0, 5))
        imgui.Separator()
        imgui.Dummy(imgui.ImVec2(0, 5))

        imgui.PushStyleColor(imgui.Col.Text, C.text_dim)
        imgui.Text("ДОБАВИТЬ НОВЫЙ СЕТ")
        imgui.PopStyleColor()

        imgui.PushItemWidth(120)
        imgui.InputText("Название##name", newName, 256)
        imgui.InputText("Group##group", newGroup, 256)
        imgui.InputText("Lib##lib", newLib, 256)
        imgui.PopItemWidth()

        if imgui.Button("Добавить", imgui.ImVec2(-1, 0)) then
            local nameStr = ffi.string(newName)
            local groupStr = ffi.string(newGroup)
            local libStr = ffi.string(newLib)

            if nameStr ~= "" and groupStr ~= "" then
                table.insert(config.sets, {
                    name = nameStr,
                    group = groupStr,
                    lib = (libStr ~= "" and libStr or nil),
                    bind = {}
                })
                saveConfig()
                
                newName[0] = 0
                newGroup[0] = 0
                newLib[0] = 0
            end
        end

        imgui.End()
        popWindowColors()
    end
)

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("arzset", function()
        renderWindow[0] = not renderWindow[0]
    end)

    local wasSpawned = false
    local waitCounter = 0

    while true do
        wait(30)
        
        local isSpawned = sampIsLocalPlayerSpawned()

        if not renderWindow[0] and isSpawned and bindingTarget == nil then
            if config.bindKey and #config.bindKey > 0 and isComboTriggered(config.bindKey) then
                config.isAnimEnabled = not config.isAnimEnabled
                isAnimEnabled[0] = config.isAnimEnabled
                saveConfig()
                applyAnimState()
                notifyChat(config.isAnimEnabled and "Подмена включена" or "Подмена выключена")
            else
                for i, set in ipairs(config.sets) do
                    if set.bind and #set.bind > 0 and isComboTriggered(set.bind) then
                        activateSet(i)
                        break
                    end
                end
            end
        end
        
        if isSpawned and not wasSpawned then
            lua_thread.create(function()
                wait(500)
                if config.isAnimEnabled then
                    applyAnimState()
                end
            end)
        end
        
        if isSpawned and config.isAnimEnabled then
            waitCounter = waitCounter + 1
            if waitCounter >= 10 then
                forceRestoreAnimation()
                waitCounter = 0
            end
        else
            waitCounter = 0
        end
        
        wasSpawned = isSpawned
    end
end