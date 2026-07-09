------------------------ Main Variables
script_author("romanespit")
script_name("Roulette Opener")
script_version("1.5.3")
local scr = thisScript()
local SCRIPT_TITLE = scr.name.." v"..scr.version
SCRIPT_SHORTNAME = "RouletteOpener"
MAIN_CMD = "ro"
COLOR_MAIN = "{A60FAA}"
SCRIPT_COLOR = 0xFFA60FAA
COLOR_YES = "{36C500}"
COLOR_NO = "{FF6A57}"
COLOR_WHITE = "{FFFFFF}"
SCRIPT_PREFIX = COLOR_MAIN.."[ "..SCRIPT_SHORTNAME.." ]{FFFFFF}: "
------------------------ 
local hook = require 'lib.samp.events'
local wm = require 'lib.windows.message'
local ffi = require 'ffi'
ffi.cdef [[
		typedef int BOOL;
		typedef unsigned long HANDLE;
		typedef HANDLE HWND;
		typedef const char* LPCSTR;
		typedef unsigned UINT;
		
        void* __stdcall ShellExecuteA(void* hwnd, const char* op, const char* file, const char* params, const char* dir, int show_cmd);
        uint32_t __stdcall CoInitializeEx(void*, uint32_t);
		
		BOOL ShowWindow(HWND hWnd, int  nCmdShow);
		HWND GetActiveWindow();
		
		
		int MessageBoxA(
		  HWND   hWnd,
		  LPCSTR lpText,
		  LPCSTR lpCaption,
		  UINT   uType
		);
		
		short GetKeyState(int nVirtKey);
		bool GetKeyboardLayoutNameA(char* pwszKLID);
		int GetLocaleInfoA(int Locale, int LCType, char* lpLCData, int cchData);
  ]]

local shell32 = ffi.load 'Shell32'
local ole32 = ffi.load 'Ole32'
ole32.CoInitializeEx(nil, 2 + 4)
local encoding = require('encoding')
encoding.default = 'cp1251'
u8 = encoding.UTF8
local effil_check, effil = pcall(require, 'effil')
local faicons = require('fAwesome6')
local imgui = require 'mimgui'
local dlstatus = require("moonloader").download_status
local json = require("cjson")
local io = require("io")
local dirml = getWorkingDirectory() -- Директория moonloader
local dirscr = dirml.."/rmnsptScripts/"..SCRIPT_SHORTNAME.."/"
local sx, sy = getScreenResolution() -- Разрешение экрана
local reloaded = false
local thread = lua_thread.create(function() return end)
------------------------ Updates
local NeedToLoad = {}
local needLoad = 0
------------------------ Another Variables
local stage = "notready"
local started = false
local OpenCount = 0
local NeedToOpen = 0
local DropStats = {}
local TotalDropPrice = 0
local PriceSetName = ""

function sms(text)
    sampAddChatMessage(SCRIPT_PREFIX..text, SCRIPT_COLOR)
end
function tech_sms(text)
    if not doesFileExist(dirml..'/NespitManager.lua') and not doesFileExist(dirml..'/NespitManager.luac') then sampAddChatMessage(SCRIPT_PREFIX..text, SCRIPT_COLOR) end
end
function Logger(text)
    print(COLOR_YES..text)
end
function CheckAndDownloadFiles()
    needLoad = 0
    NeedToLoad = {}
    if not doesFileExist(dirml..'/rmnsptScripts/EagleSans-Regular.ttf') then table.insert(NeedToLoad, {'https://github.com/romanespit/ScriptStorage/blob/main/extraFiles/EagleSans-Regular.ttf?raw=true',dirml..'/rmnsptScripts/EagleSans-Regular.ttf'}) needLoad = needLoad+1 end
    if needLoad ~= 0 then
        Logger("Требуется загрузка "..needLoad.." файлов. Начинаю скачивание...")
        for k,v in ipairs(NeedToLoad) do
            downloadUrlToFile(v[1], v[2], function(id, status, p1, p2)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    lua_thread.create(function()
                        wait(1000)
                        if doesFileExist(v[2]) then
                            Logger("Успешная загрузка файла "..v[2]:match(".+(rmnsptScripts/.+)"))
                            needLoad = needLoad-1
                        end
                    end)
                end
            end)
        end
    end
    repeat wait(100) until needLoad == 0
    if #NeedToLoad > 0 then sms("Загрузки необходимых файлов завершены. Перезагружаемся...") reloaded = true scr:reload() end
end
------------------------ Script Directories
if not doesDirectoryExist(dirml.."/rmnsptScripts/") then
    createDirectory(dirml.."/rmnsptScripts/")
    Logger("Директория rmnsptScripts не была найдена. Создаём...")
end
if not doesDirectoryExist(dirml.."/rmnsptScripts/"..SCRIPT_SHORTNAME.."/") then
    createDirectory(dirscr)
    Logger("Директория rmnsptScripts/"..SCRIPT_SHORTNAME.." не была найдена. Создаём...")
end
------------------------ Default Config

local cfg = {
    --Turned = true,
    HasCompass = false,
    Timer = 15
}
local ItemPrice = {
    ["Ларец организации"] = "120000",
    ["Подарок"] = "45000",
    ["Деньги"] = "1"
}
function SaveCFG()
    local filepath = dirml.."/rmnsptScripts/"..SCRIPT_SHORTNAME.."-settings.json"
    local file = io.open(filepath, "w")
    if file then
        file:write(json.encode(cfg))
        file:close()
    else
        Logger("Ошибка сохранения файла настроек")
    end
end
function LoadCFG()
    local filepath = dirml.."/rmnsptScripts/"..SCRIPT_SHORTNAME.."-settings.json"
    local file = io.open(filepath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        cfg = json.decode(content)
    else
        Logger("Ошибка чтения файла настроек! Создаём...")
        SaveCFG()
    end
end
LoadCFG() -- Загрузка настроек
function LoadItemPrices()
    local filepath = dirml.."/rmnsptScripts/ItemPrices.json"
    local file = io.open(filepath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        ItemPrice = json.decode(content)
        for k,v in pairs(ItemPrice) do
            if ItemPrice[k] == 0 or tonumber(ItemPrice[k]) < 0 or tonumber(ItemPrice[k]) == nil then ItemPrice[k] = "0" end
        end
    else
        Logger("Ошибка чтения файла с ценами! Создаём...")
        SaveItemPrices()
    end
end
function SaveItemPrices()
    local filepath = dirml.."/rmnsptScripts/ItemPrices.json"
    local file = io.open(filepath, "w")
    if file then
        file:write(json.encode(ItemPrice))
        file:close()
    else
        Logger("Ошибка сохранения файла с ценами")
    end
end

------------------------ MimGUI Variables
local new, str = imgui.new, ffi.string
local WinState = new.bool()
local PriceState = new.bool()
--local Turned = new.bool(cfg.Turned)
local HasCompass = new.bool(cfg.HasCompass)
local Timer = new.int(cfg.Timer)
local imNeedToOpen = new.char[256](u8(tostring(NeedToOpen)))
local imPrice = new.char[10]()
------------------------ 
function onScriptTerminate(scr, is_quit)
	if scr == thisScript() and not is_quit and not reloaded then
        tech_sms("Скрипт непредвиденно выключился! Проверьте консоль SAMPFUNCS.")
	end
end
OPENTIME = os.time()
function onSendPacket(id, bs)
    if id == 220 then
		raknetBitStreamIgnoreBits(bs, 8)
        if raknetBitStreamReadInt8(bs) == 18 then
            --local text = raknetBitStreamReadString(bs, raknetBitStreamReadInt32(bs))
            local text = raknetBitStreamReadString(bs, raknetBitStreamReadInt16(bs))
            --("[DBG] cef send | text="..text)
            if text:find("onActiveViewChanged|CrateRoulette") then
                if started and not WinState[0] then WinState[0] = true end
                stage = "readytoopen"
                --print("[DBG] Send OAVC CR | stage="..stage)
                if started then
                    thread = lua_thread.create(function()
                        wait(300)
                        cefSend("crate.roulette.open")
                        OPENTIME = os.time()
                        --print("[DBG] Send cef crate.roulette.open | "..stage)
                    end)
                end
            end
        end
    end
end
function onReceivePacket(id, bs)
	if id == 220 then
		raknetBitStreamIgnoreBits(bs, 8)
		if raknetBitStreamReadInt8(bs) == 17 then
			raknetBitStreamIgnoreBits(bs, 32)
            local length = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            local text = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
            if text:find("event.setActiveView") and not text:find("CrateRoulette") then
                stage = "notready"
            elseif text:find("event.crate.roulette.onCrateOpen") then
                stage = "notready"
                if started then
                    thread = lua_thread.create(function()
                        if cfg.HasCompass == true then 
                            wait(300)                            
                        else
                            wait(cfg.Timer*1000)
                        end                        
                        cefSend("crate.roulette.takePrize")
                        wait(150) 
                        cefSend("crate.roulette.exit") 
                        if NeedToOpen > 0 then
                            NeedToOpen = NeedToOpen-1
                            if NeedToOpen == 0 then
                                started = false
                            end
                        end
                    end)
                end
            end
        end
    end
end
------------------------ Another Funcs
function AddDrop(name,count)
    if ItemPrice[name] == nil then ItemPrice[name] = "0" SaveItemPrices() end
    local found = false
    OpenCount = OpenCount + 1
    if #DropStats > 0 then
        for i,v in ipairs(DropStats) do
            if DropStats[i].Name == name then 
                DropStats[i].Count = DropStats[i].Count+count
                found = true
                break
            end
        end
    end 
    if not found then
        table.insert(DropStats, {Name=name,Count=count})
    end
end
function cefSend(text)
    local bs = raknetNewBitStream()
	raknetBitStreamWriteInt8(bs, 220)
	raknetBitStreamWriteInt8(bs, 18)
	raknetBitStreamWriteInt16(bs, string.len(text))
	raknetBitStreamWriteString(bs, text)
	raknetSendBitStreamEx(bs, 1, 7, 1)
	raknetDeleteBitStream(bs)
end
------------------------ Main Function
function main()
	while not isSampAvailable() do wait(0) end
	repeat wait(100) until sampIsLocalPlayerSpawned() 
    CheckAndDownloadFiles()
    sampRegisterChatCommand(MAIN_CMD, function() WinState[0] = not WinState[0] end) -- Главное окно скрипта
    LoadItemPrices()
	tech_sms("Успешная загрузка скрипта. Используйте: ".. COLOR_MAIN .."/"..MAIN_CMD.."{FFFFFF}. Автор: "..COLOR_MAIN..table.concat(scr.authors, ", ")) -- Приветственное сообщение
    while true do
		wait(0)
        if started then
            if cfg.HasCompass == true then 
                if os.time() > OPENTIME+1 then
                    cefSend("crate.roulette.open")
                    OPENTIME = os.time()
                end                          
            else
                if os.time() > OPENTIME+1+cfg.Timer then
                    cefSend("crate.roulette.open")
                    OPENTIME = os.time()
                end 
            end 
            
        end
    end  
    wait(-1)
end
------------------------ Samp Events Hook funcs
function hook.onShowDialog(id, style, title, button1, button2, text)
    if id == 0 and text:find("Поздравляем с получением") then 
        local prize,count = text:match("Поздравляем с получением: {......}(.+) %((%d+) шт%){......}")
        if prize ~= nil and count ~= nil then
            AddDrop(prize,count)
            sampSendDialogResponse(id, 1, 0, nil)
            sampCloseCurrentDialogWithButton(0)
            return false
        end
    end
end
function hook.onServerMessage(color,text)
    if text:find("%[Подсказка%] {......}Вы получили %+%$.+%!") then
        AddDrop("Деньги",text:gsub("%p",""):match("(%d+)"))
    end
end
------------------------ 
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    --Font
    if doesFileExist(dirml..'/rmnsptScripts/EagleSans-Regular.ttf') then        
        imgui.GetIO().Fonts:Clear()
        imgui.GetIO().Fonts:AddFontFromFileTTF(u8(dirml..'/rmnsptScripts/EagleSans-Regular.ttf'), 15, nil, glyph_ranges)
        imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 14, config, iconRanges)

        
        MiddleFont = imgui.GetIO().Fonts:AddFontFromFileTTF(u8(dirml..'/rmnsptScripts/EagleSans-Regular.ttf'), 18, nil, glyph_ranges)
        imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 18, config, iconRanges)
    else Logger("Отсутствует файл EagleSans-Regular.ttf.") end
    MimStyle()
end)
------------------------ MimGUI Frames
imgui.OnFrame(function() return WinState[0] and not PriceState[0] end, -- Main Frame
    function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(sx/3, 500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        --imgui.Begin(faicons('gem').." "..u8(SCRIPT_TITLE), WinState, imgui.WindowFlags.AlwaysAutoResize+imgui.WindowFlags.NoCollapse)
        imgui.Begin(faicons('gem').." "..u8(SCRIPT_TITLE), WinState, imgui.WindowFlags.AlwaysAutoResize+imgui.WindowFlags.NoCollapse+imgui.WindowFlags.NoTitleBar)
        imgui.MainWindowHeader() 
        if not started and stage == "readytoopen" then
            imgui.SetCursorPosX(imgui.GetWindowWidth()/2-100)
            if imgui.Button(u8'Начать', imgui.ImVec2(200, 50)) then
                started = true
                cefSend("crate.roulette.open")
            end
        elseif started then
            imgui.SetCursorPosX(imgui.GetWindowWidth()/2-100)
            if imgui.Button(u8'Остановить', imgui.ImVec2(200, 50)) then
                started = false
                if thread:status() ~= "dead" then thread:terminate() end
            end
        elseif stage ~= "readytoopen" and not started then
            imgui.TextColoredRGB(COLOR_YES.."Выберите в инвентаре рулетку")
            imgui.TextColoredRGB(COLOR_YES.."И нажмите на ней Использовать")
        end
        if imgui.InputText(u8"Сколько открыть", imNeedToOpen, 256) then if u8:decode(ffi.string(imNeedToOpen)) ~= "" then NeedToOpen = tonumber(u8:decode(ffi.string(imNeedToOpen))) else NeedToOpen = 0 end end
        imgui.TextColoredRGB('Осталось открыть: '..COLOR_YES..(NeedToOpen ~= 0 and NeedToOpen or 'Пока не кончатся/остановится'))
        if imgui.Checkbox(u8'У меня есть рулеточный компас', HasCompass) then
            cfg.HasCompass = HasCompass[0]
            SaveCFG()
        end
        if not HasCompass[0] then
            if imgui.SliderInt(u8'Таймер открытия (сек)', Timer, 1, 15) then				
                cfg.Timer = Timer[0]
                SaveCFG()
            end
            if Timer[0] < 15 then
                imgui.TextColoredRGB("{FF0000}ВНИМАНИЕ! Стандартное время открытия - 15 секунд")
                imgui.TextColoredRGB("{FF0000}Ставив время меньше 15 секунд, вы можете получить")
                imgui.TextColoredRGB("{FF0000}наказание от администрации сервера.")
                imgui.TextColoredRGB("{FF0000}Автор скрипта ответственности НЕ несёт!")
            end
        end
        if imgui.CollapsingHeader(u8"Статистика") then
            imgui.Text(u8"Статистика открытий:")
            imgui.TextColoredRGB("Открыто рулеток: "..COLOR_YES..OpenCount)            
            imgui.TextColoredRGB("Цена всего дропа: "..COLOR_YES.."$"..TotalDropPrice)
            imgui.Separator()
            if #DropStats > 0 then
                TotalDropPrice = 0
                for i,v in ipairs(DropStats) do
                    imgui.TextColoredRGB(DropStats[i].Name.."{FFFF00} x"..DropStats[i].Count..COLOR_YES..(ItemPrice[DropStats[i].Name] ~= "0" and " $"..ItemPrice[DropStats[i].Name] or " Цена неизвестна"))
                    TotalDropPrice = TotalDropPrice+(tonumber(ItemPrice[DropStats[i].Name])*DropStats[i].Count)
                    if DropStats[i].Name ~= "Деньги" then
                        imgui.SameLine()
                        imgui.Text(faicons.PEN_TO_SQUARE)
                        if imgui.IsItemHovered() then
                            imgui.BeginTooltip()
                            imgui.Text(u8'Нажмите, чтобы изменить цену')
                            imgui.EndTooltip()
                        end        
                        if imgui.IsItemClicked() then 
                            PriceState[0] = not PriceState[0]
                            PriceSetName = DropStats[i].Name
                            imgui.StrCopy(imPrice, u8(ItemPrice[DropStats[i].Name]))
                        end
                    end
                end
                imgui.SetCursorPosX(imgui.GetWindowWidth()/2-100)
                if imgui.Button(u8'Сохранить в файл', imgui.ImVec2(200, 30)) then
                    local text = ""
                    local filepath = dirscr.."SavedDrop-"..os.date("%d%m%y-%H-%M-%S")..".log"
                    local file = io.open(filepath, "w")
                    if file then
                        TotalDropPrice = 0
                        for i,v in ipairs(DropStats) do
                            TotalDropPrice = TotalDropPrice+(tonumber(ItemPrice[DropStats[i].Name])*DropStats[i].Count)
                            text = text.."\n"..DropStats[i].Name.." - x"..DropStats[i].Count..". Средняя цена: "..(ItemPrice[DropStats[i].Name] ~= "0" and " $"..ItemPrice[DropStats[i].Name] or " Цена неизвестна")  
                        end
                        text = text.."\n\nОбщая цена дропа: $"..TotalDropPrice
                        file:write(u8(text))
                        file:close()
                    end
                    sms("Дроп сохранен в файл /moonloader/rmnsptScripts/"..SCRIPT_SHORTNAME.."/SavedDrop-"..os.date("%d%m%y-%H-%M-%S")..".log")
                end 
            end
            imgui.SetCursorPosX(imgui.GetWindowWidth()/2-100)
            if imgui.Button(u8'Обнулить статистику', imgui.ImVec2(200, 30)) then
                OpenCount = 0
                DropStats = {}
                TotalDropPrice = 0
                sms("Статистика сброшена")
            end 
            
        end   
        --imgui.Link("https://romanespit.ru/lua",u8"© "..table.concat(scr.authors, ", "))
        imgui.End()
    end
)
imgui.OnFrame(function() return PriceState[0] end, -- Main Frame
    function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(sx/3, 500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.Begin(u8("Настройки цен дропа"), PriceState, imgui.WindowFlags.AlwaysAutoResize+imgui.WindowFlags.NoCollapse)
        imgui.TextColoredRGB("Введите цену для "..COLOR_YES..PriceSetName..COLOR_WHITE..":")
        imgui.SameLine()
        imgui.PushItemWidth(100)
        imgui.InputText("", imPrice, 10)
        imgui.SetCursorPosX(imgui.GetWindowWidth()/2-100) 
        if imgui.Button(u8'Сохранить', imgui.ImVec2(200, 30)) then
            if u8:decode(ffi.string(imPrice)) == nil or
            u8:decode(ffi.string(imPrice)) == "" or
            tonumber(u8:decode(ffi.string(imPrice))) == nil or
            tonumber(u8:decode(ffi.string(imPrice))) < 0 then imgui.StrCopy(imPrice, u8("0")) end
            ItemPrice[PriceSetName] = u8:decode(ffi.string(imPrice))
            SaveItemPrices()
            PriceSetName = ""
            PriceState[0] = false
        end        
        imgui.End()
    end
)






















------------------------ External imgui funcs
function imgui.TextColoredRGB(string, max_float)
	local style = imgui.GetStyle()
	local colors = style.Colors
	local clr = imgui.Col
	local u8 = require 'encoding'.UTF8

	local function color_imvec4(color)
		if color:upper():sub(1, 6) == 'SSSSSS' then return imgui.ImVec4(colors[clr.Text].x, colors[clr.Text].y, colors[clr.Text].z, tonumber(color:sub(7, 8), 16) and tonumber(color:sub(7, 8), 16)/255 or colors[clr.Text].w) end
		local color = type(color) == 'number' and ('%X'):format(color):upper() or color:upper()
		local rgb = {}
		for i = 1, #color/2 do rgb[#rgb+1] = tonumber(color:sub(2*i-1, 2*i), 16) end
		return imgui.ImVec4(rgb[1]/255, rgb[2]/255, rgb[3]/255, rgb[4] and rgb[4]/255 or colors[clr.Text].w)
	end

	local function render_text(string)
		for w in string:gmatch('[^\r\n]+') do
			local text, color = {}, {}
			local render_text = 1
			local m = 1
			if w:sub(1, 8) == '[center]' then
				render_text = 2
				w = w:sub(9)
			elseif w:sub(1, 7) == '[right]' then
				render_text = 3
				w = w:sub(8)
			end
			w = w:gsub('{(......)}', '{%1FF}')
			while w:find('{........}') do
				local n, k = w:find('{........}')
				if tonumber(w:sub(n+1, k-1), 16) or (w:sub(n+1, k-3):upper() == 'SSSSSS' and tonumber(w:sub(k-2, k-1), 16) or w:sub(k-2, k-1):upper() == 'SS') then
					text[#text], text[#text+1] = w:sub(m, n-1), w:sub(k+1, #w)
					color[#color+1] = color_imvec4(w:sub(n+1, k-1))
					w = w:sub(1, n-1)..w:sub(k+1, #w)
					m = n
				else w = w:sub(1, n-1)..w:sub(n, k-3)..'}'..w:sub(k+1, #w) end
			end
			local length = imgui.CalcTextSize(u8(w))
			if render_text == 2 then
				imgui.NewLine()
				imgui.SameLine(max_float / 2 - ( length.x / 2 ))
			elseif render_text == 3 then
				imgui.NewLine()
				imgui.SameLine(max_float - length.x - 5 )
			end
			if text[0] then
				for i, k in pairs(text) do
					imgui.TextColored(color[i] or colors[clr.Text], u8(k))
					imgui.SameLine(nil, 0)
				end
				imgui.NewLine()
			else imgui.Text(u8(w)) end
		end
	end
	
	render_text(string)
end
function imgui.Link(link, text)
    text = text or link
    local tSize = imgui.CalcTextSize(text)
    local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    local col = { 0xFFFF7700, 0xFFFF9900 }
    if imgui.InvisibleButton("##" .. link, tSize) then print(shell32.ShellExecuteA(nil, 'open', link, nil, nil, 1)) end
    local color = imgui.IsItemHovered() and col[1] or col[2]
    DL:AddText(p, color, text)
    DL:AddLine(imgui.ImVec2(p.x, p.y + tSize.y), imgui.ImVec2(p.x + tSize.x, p.y + tSize.y), color)
end
function imgui.MainWindowHeader()
    imgui.SetCursorPosY(5)
    imgui.SetCursorPosX(10)
    if imgui.Button(faicons.BUG.."##reportbug", imgui.ImVec2(40, 25)) then print(shell32.ShellExecuteA(nil, 'open', "https://github.com/romanespit/ScriptStorage/blob/main/HOWTO-REPORT.md", nil, nil, 1)) end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Сообщить о проблеме или предложить что-то новое")
    end
    imgui.SameLine()
    imgui.SetCursorPosX(60)
    if imgui.Button(faicons.GLOBE.."##siteurl", imgui.ImVec2(40, 25)) then print(shell32.ShellExecuteA(nil, 'open', "https://romanespit.ru/", nil, nil, 1)) end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Перейти на сайт разработчика")
    end
    imgui.SameLine()
    imgui.SetCursorPosY(4)
    imgui.PushFont(MiddleFont)
        imgui.CenterText(u8(SCRIPT_TITLE))  
    imgui.PopFont()
    imgui.SameLine()
    
    imgui.SetCursorPosY(5)
    --[[imgui.SetCursorPosX(imgui.GetWindowWidth()-150)
    if imgui.Button(faicons.ARROWS_ROTATE.."##updatescripts", imgui.ImVec2(40, 25)) then checkUpdates() sms(EOK.."Данные о скриптах обновлены") end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Нажмите, чтобы обновить данные о скриптах")
    end
    imgui.SameLine()]]
    imgui.SetCursorPosX(imgui.GetWindowWidth()-100)
    if imgui.Button(faicons.ROTATE_RIGHT.."##reload", imgui.ImVec2(40, 25)) then reloaded = true scr:reload() end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Нажмите, чтобы перезагрузить скрипт")
    end
    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetWindowWidth()-50)
    if imgui.Button(faicons.XMARK.."##closewindow", imgui.ImVec2(40, 25)) then WinState[0] = false end
    imgui.Separator()
end

function imgui.CenterText(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.Text(text)
end
------------------------ MimGUI Style
function MimStyle()
    local style = imgui.GetStyle();
    local colors = style.Colors;
    style.Alpha = 1;
    style.WindowPadding = imgui.ImVec2(8.00, 8.00);
    style.WindowRounding = 12;
    style.WindowBorderSize = 0;
    style.WindowMinSize = imgui.ImVec2(32.00, 32.00);
    style.WindowTitleAlign = imgui.ImVec2(0.50, 0.50);
    style.ChildRounding = 6;
    style.ChildBorderSize = 0;
    style.PopupRounding = 12;
    style.PopupBorderSize = 0;
    style.FramePadding = imgui.ImVec2(10.00, 5.00);
    style.FrameRounding = 7;
    style.FrameBorderSize = 0;
    style.ItemSpacing = imgui.ImVec2(5.00, 4.00);
    style.ItemInnerSpacing = imgui.ImVec2(10.00, 4.00);
    style.IndentSpacing = 20;
    style.ScrollbarSize = 10;
    style.ScrollbarRounding = 12;
    style.GrabMinSize = 8;
    style.GrabRounding = 12;
    style.TabRounding = 7;
    style.ButtonTextAlign = imgui.ImVec2(0.50, 0.50);
    style.SelectableTextAlign = imgui.ImVec2(0.50, 0.50);
    colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00);
    colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.50, 0.50, 0.50, 1.00);
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.20, 0.20, 0.20, 0.94);
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.20, 0.20, 0.20, 0.94);
    colors[imgui.Col.PopupBg] = imgui.ImVec4(0.20, 0.20, 0.20, 0.94);
    colors[imgui.Col.Border] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50);
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.00, 0.26, 0.64, 0.54);
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.40);
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.26, 0.59, 0.98, 0.67);
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.16, 0.29, 0.48, 0.79);
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.16, 0.29, 0.48, 1.00);
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.16, 0.29, 0.48, 0.70);
    colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.16, 0.29, 0.48, 0.78);
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.59);
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.34, 0.34, 0.34, 1.00);
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.41, 0.41, 0.41, 1.00);
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.51, 0.51, 0.51, 1.00);
    colors[imgui.Col.CheckMark] = imgui.ImVec4(0.23, 0.42, 0.70, 1.00);
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.16, 0.29, 0.48, 1.00);
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.22, 0.39, 0.64, 1.00);
    colors[imgui.Col.Button] = imgui.ImVec4(0.18, 0.35, 0.58, 0.86);
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.16, 0.29, 0.48, 1.00);
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.21, 0.38, 0.61, 1.00);
    colors[imgui.Col.Header] = imgui.ImVec4(0.72, 0.72, 0.72, 0.31);
    colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.18, 0.35, 0.58, 0.74);
    colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.18, 0.35, 0.58, 0.86);
    colors[imgui.Col.Separator] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50);
    colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.10, 0.40, 0.75, 0.78);
    colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.10, 0.40, 0.75, 1.00);
    colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.66, 0.66, 0.66, 0.31);
    colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.77, 0.77, 0.77, 0.67);
    colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.18, 0.35, 0.58, 0.86);
    colors[imgui.Col.Tab] = imgui.ImVec4(0.18, 0.35, 0.58, 0.51);
    colors[imgui.Col.TabHovered] = imgui.ImVec4(0.18, 0.35, 0.58, 1.00);
    colors[imgui.Col.TabActive] = imgui.ImVec4(0.24, 0.45, 0.75, 0.86);
    colors[imgui.Col.TabUnfocused] = imgui.ImVec4(0.07, 0.10, 0.15, 0.97);
    colors[imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.14, 0.26, 0.42, 1.00);
    colors[imgui.Col.PlotLines] = imgui.ImVec4(0.61, 0.61, 0.61, 1.00);
    colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(1.00, 0.43, 0.35, 1.00);
    colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.90, 0.70, 0.00, 1.00);
    colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(1.00, 0.60, 0.00, 1.00);
    colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.26, 0.59, 0.98, 0.35);
    colors[imgui.Col.DragDropTarget] = imgui.ImVec4(1.00, 1.00, 0.00, 0.90);
    colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.18, 0.35, 0.58, 0.86);
    colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70);
    colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.20);
    colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.35);
end
addEventHandler('onWindowMessage', function(msg, wparam, lparam)
	if wparam == 27 then
		if WinState[0] then
			if msg == wm.WM_KEYDOWN then
				consumeWindowMessage(true, false)
			end
			if msg == wm.WM_KEYUP then
				WinState[0] = false
			end
		end
	end
end)