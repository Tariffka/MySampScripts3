script_author('tarif_jan')
script_name('Taxes')
script_version('2.3.2')

require("moonloader")
local sampev = require("samp.events")
local inicfg = require("inicfg")

local encoding = require("encoding")
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local iniFile = "Taxes_v2.ini"
local iniData = inicfg.load({
    main = {
        autoTaxes = false,
        autoFamHouse = false
    }
}, iniFile)

local isPayingTaxes = false
local isPayingFamHouse = false

function chat(text)
    sampAddChatMessage(u8:decode("{ffa500}[Taxes v2]{ffffff}: " .. text), -1)
end

function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand('tx', function()
        toggleTaxesPay()
    end)

    sampRegisterChatCommand('th', function()
        toggleFamHousePay()
    end)

    sampRegisterChatCommand('txm', function()
        iniData.main.autoTaxes = not iniData.main.autoTaxes
        inicfg.save(iniData, iniFile)
        local status = iniData.main.autoTaxes and "{00ff00}Включена" or "{ff0000}Выключена"
        chat("Авто-оплата всех налогов теперь " .. status)
    end)

    sampRegisterChatCommand('thm', function()
        iniData.main.autoFamHouse = not iniData.main.autoFamHouse
        inicfg.save(iniData, iniFile)
        local status = iniData.main.autoFamHouse and "{00ff00}Включена" or "{ff0000}Выключена"
        chat("Авто-оплата семейной квартиры теперь " .. status)
    end)

    sampRegisterChatCommand('fhmode', function()
        chat("Список команд:")
        chat("{ffc0cb}/tx{ffffff} - Ручная оплата налогов дом/биз")
        chat("{ffc0cb}/th{ffffff} - Ручная оплата Фам.КВ")
        chat("{ffc0cb}/txm{ffffff} - Включить/Выключить авто-оплату налогов дом/биз")
        chat("{ffc0cb}/thm{ffffff} - Включить/Выключить авто-оплату Фам.КВ")
    end)

    chat("[TJ]Скрипт загружен. Введите {ffc0cb}/fhmode{ffffff} для справки.")
    
    local paydayTriggered = false 
    local paymentTimestamp = nil
    math.randomseed(os.time())

    while true do
        wait(1000) 
        
        local currentMinute = tonumber(os.date("%M"))
        if currentMinute == 0 then
            if not paydayTriggered then
                paydayTriggered = true            
                local randomSeconds = math.random(15, 50)
                paymentTimestamp = os.time() + randomSeconds
            end

            if paymentTimestamp and os.time() >= paymentTimestamp then
                paymentTimestamp = nil
                
                lua_thread.create(function()
                    if iniData.main.autoTaxes then
                        toggleTaxesPay()
                        
                        while isPayingTaxes do
                            wait(100)
                        end
                        
                        wait(math.random(3000, 6000))
                    end

                    if iniData.main.autoFamHouse then
                        toggleFamHousePay()
                    end
                end)
            end
        else
            paydayTriggered = false
            paymentTimestamp = nil
        end
    end
end

function toggleTaxesPay()
    if isPayingTaxes then return end
    isPayingTaxes = true
    lua_thread.create(function()
        sampSendChat('/phone')
        wait(1000)
        sendCef('launchedApp|24')
        wait(300)
        sendCefRaw({220, 0, 27, 0})
        wait(500)
        sendCef('onSvelteAppInit')
        
        wait(5000)
        if isPayingTaxes then
            isPayingTaxes = false
        end
    end)
end

function toggleFamHousePay()
    if isPayingFamHouse then return end
    isPayingFamHouse = true
    lua_thread.create(function()
        sampSendChat('/fammenu')
        wait(1200) 
        sendCef('familyMenu.changePage|5')
        wait(300)
        sendCef('familyMenu.apart.payTax')
        wait(300)
        sendCef('familyMenu.exit')
        
        wait(5000)
        if isPayingFamHouse then
            isPayingFamHouse = false
        end
    end)
end

function sendCefRaw(packet)
    local bs = raknetNewBitStream()
    for _, value in ipairs(packet) do
        raknetBitStreamWriteInt8(bs, value)
    end
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function sendCef(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, string.len(str))
    raknetBitStreamWriteString(bs, str)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if isPayingTaxes then
        if title == "{BFBBBA}" and text:find(u8:decode("{FFFFFF}1. Состояние основного счета")) then
            if text:find(u8:decode("{ffff00}Оплата всех налогов{FFFFFF}")) then
                local num = 0
                for line in text:gmatch("[^\r\n]+") do
                    if line:find(u8:decode("Оплата всех налогов")) then 
                        sampSendDialogResponse(id, 1, num, line)
                        return false
                    end
                    num = num + 1
                end
            else
                sampSendDialogResponse(id, 0)

                isPayingTaxes = false
                return false
            end

        elseif title == u8:decode("{BFBBBA}Оплата всех налогов") then
            sampSendDialogResponse(id, 1) 
            isPayingTaxes = false

            if text == u8:decode("{00ff00}-{ffffff} У Вас нет налогов, которые требуется оплатить!") then
                
            end
            return false
        end
    end

    if isPayingFamHouse then
        local u8Title = u8(title)
        local u8Text = u8(text)

        if u8Title:find('[Сс]емейн') or u8Title:find('[Кк]вартир') or u8Title:find('[Нн]алог') or u8Text:find('[Сс]емейную квартиру') then
            local cleanText = u8(text):gsub('{.-}', '')
            local taxRaw = cleanText:match('составляет%s*.-(%d[%d%s%.,]*)') or cleanText:match('налог%s*.-(%d[%d%s%.,]*)')
            local tax = nil

            if taxRaw then
                tax = taxRaw:gsub('%D', '')
            end

            if not tax or tonumber(tax) == 0 then
                local firstNum = cleanText:match('(%d[%d%s%.,]*)')
                if firstNum then
                    tax = firstNum:gsub('%D', '')
                end
            end

            if tax and tonumber(tax) and tonumber(tax) > 0 then
                sampSendDialogResponse(id, 1, 0, tostring(tax))
                return false
            end

            isPayingFamHouse = false
            
            sampSendDialogResponse(id, 0)
            return false

        elseif u8Title:find('информац') and (u8Text:find('теперь налог') or u8Text:find('вы оплатили')) then
            isPayingFamHouse = false
            local cleanInfo = u8(text):gsub('{.-}', '')
            
            local payedRaw = cleanInfo:match('Вы оплатили%s*.-(%d[%d%s%.,]*)')
            local remainRaw = cleanInfo:match('составляет%s*.-(%d[%d%s%.,]*)') or cleanInfo:match('налог%s*.-(%d[%d%s%.,]*)')
            
            local payed = payedRaw and payedRaw:gsub('%D', '') or "неизвестно"
            local remain = remainRaw and remainRaw:gsub('%D', '') or "0"
            
            sampSendDialogResponse(id, 0)
            return false
        end
    end
end

function sampev.onServerMessage(color, text)
    if text:find(u8:decode("^Вы оплатили все налоги на сумму")) then
    end
end