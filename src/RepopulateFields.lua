RepopulateFields = {}
RepopulateFields.modName = g_currentModName
RepopulateFields.modDirectory = g_currentModDirectory
local RepopulateFields_mt = Class(RepopulateFields)

---
function RepopulateFields.new()
    local self = setmetatable({}, RepopulateFields_mt)

    addConsoleCommand("repopulateAllFields", "Repopulates all fields", "consoleCommandRepopulateAllFields", RepopulateFields)
    addConsoleCommand("repopulateOwnedFields", "Repopulates all owned fields", "consoleCommandRepopulateOwnedFields", RepopulateFields)
    addConsoleCommand("repopulateUnownedFields", "Repopulates all unowned fields", "consoleCommandRepopulateUnownedFields", RepopulateFields)
    addConsoleCommand("repopulateCurrentField", "Repopulates the current field the player is in", "consoleCommandRepopulateCurrentField", RepopulateFields)

    RepopulateFields:extendSettingsScreen()

    return self
end

---
function RepopulateFields:consoleCommandRepopulateAllFields()
    local fields = {}

    for _, field in pairs(g_fieldManager:getFields()) do
        table.insert(fields, field)
    end

    RepopulateFields:repopulateFields(fields)
end

---
function RepopulateFields:consoleCommandRepopulateOwnedFields()
    local fields = {}

    for _, field in pairs(g_fieldManager:getFields()) do
        if field:getHasOwner() then
            table.insert(fields, field)
        end
    end

    RepopulateFields:repopulateFields(fields)
end

---
function RepopulateFields:consoleCommandRepopulateUnownedFields()
    local fields = {}

    for _, field in pairs(g_fieldManager:getFields()) do
        if not field:getHasOwner() then
            table.insert(fields, field)
        end
    end

    RepopulateFields:repopulateFields(fields)
end

---
function RepopulateFields:consoleCommandRepopulateCurrentField()
    local fields = {}
    local fieldId = g_fieldManager:getFieldIdAtPlayerPosition()

    if fieldId ~= nil then
        local field = g_fieldManager:getFieldById(fieldId)
        table.insert(fields, field)

        RepopulateFields:repopulateFields(fields)
    end
end

---
function RepopulateFields:repopulateFields(fields)
    Logging.devInfo("[RepopulateFields]: Repopulating fields")
    for _, field in pairs(fields) do
        g_asyncTaskManager:addTask(function()
            local fruitIndex = table.getRandomElement(g_fieldManager.availableFruitTypeIndices)

            if field.grassMissionOnly then
                fruitIndex = FruitType.GRASS
            end

            local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)

            if fruitTypeDesc == nil then
                return
            end

            local growthState = fruitTypeDesc:getRandomInitialState(g_currentMission.missionInfo.growthMode)
            local weedState = 0
            local stoneLevel = 0
            local groundType = FieldGroundType.SOWN
            local groundAngle = field:getAngle()
            local sprayType = FieldSprayType.NONE
            local sprayLevel = math.random(0, g_fieldManager.sprayLevelMaxValue)
            local plowLevel = math.random(0, g_fieldManager.plowLevelMaxValue)
            local limeLevel = math.random(0, g_fieldManager.limeLevelMaxValue)

            if growthState ~= nil then
                if fruitTypeDesc.plantsWeed then
                    if growthState > 4 then
                        weedState = math.random(3, 9)
                    else
                        weedState = math.random(1, 7)
                    end
                end

                groundType = fruitTypeDesc:getGrowthStateGroundType(growthState) or groundType
            else
                fruitIndex = nil
                groundType = math.random() < 0.5 and FieldGroundType.CULTIVATED or FieldGroundType.PLOWED

                if groundType == FieldGroundType.PLOWED then
                    plowLevel = g_fieldManager.plowLevelMaxValue
                end

                if sprayLevel > 0 then
                    sprayType = math.random() < 0.7 and FieldSprayType.LIQUID_MANURE or FieldSprayType.MANURE
                end

                if limeLevel > 0 and math.random() < 0.1 then
                    sprayType = FieldSprayType.LIME
                end
            end

            if not g_currentMission.missionInfo.plowingRequiredEnabled then
                plowLevel = g_fieldManager.plowLevelMaxValue
            end

            local task = FieldUpdateTask.new()
            task:setField(field)
            task:setFruit(fruitIndex, growthState)
            task:setWeedState(weedState)
            task:setStoneLevel(stoneLevel)
            task:setGroundType(groundType)
            task:setGroundAngle(groundAngle)
            task:setSprayType(sprayType)
            task:setSprayLevel(sprayLevel)
            task:setLimeLevel(limeLevel)
            task:setPlowLevel(plowLevel)
            task:clearHeight()
            g_fieldManager:addFieldUpdateTask(task)
        end)
    end
end

---
function RepopulateFields:extendSettingsScreen()
    local settingsPage = g_inGameMenu.pageSettings
    local scrollPanel = settingsPage.gameSettingsLayout

    for _, element in pairs(scrollPanel.elements) do
        if element.name == "sectionHeader" then
            self.sectionHeader = element:clone(scrollPanel)
        end

        if element.typeName == "Bitmap" then
            if element.elements[1].typeName == "Button" then
                self.button = element
            end
        end

        if self.sectionHeader ~= nil and self.button ~= nil then
            break
        end
    end

    self.sectionHeader:setText(RepopulateFields:getText("repopulateFields_sectionHeader"))

    local controls = {
        RepopulateFields:addButtonSettingsOption(scrollPanel, settingsPage, "repopulateAllFields", RepopulateFields.consoleCommandRepopulateAllFields),
        RepopulateFields:addButtonSettingsOption(scrollPanel, settingsPage, "repopulateOwnedFields", RepopulateFields.consoleCommandRepopulateOwnedFields),
        RepopulateFields:addButtonSettingsOption(scrollPanel, settingsPage, "repopulateUnownedFields", RepopulateFields.consoleCommandRepopulateUnownedFields),
        RepopulateFields:addButtonSettingsOption(scrollPanel, settingsPage, "repopulateCurrentField", RepopulateFields.consoleCommandRepopulateCurrentField),
    }

    UIHelper.registerFocusControls(controls, scrollPanel)
    local buttonNames = {"repopulateAllFields", "repopulateOwnedFields", "repopulateUnownedFields", "repopulateCurrentField"}

    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function(frame)
        for _, name in ipairs(buttonNames) do
            if frame[name] then
                frame[name]:setDisabled(false)
            end
        end
    end)

    local origInputEvent = InGameMenuSettingsFrame.inputEvent

    InGameMenuSettingsFrame.inputEvent = function(self, action, value)
        if action == InputAction.MENU_ACCEPT then
            local focused = FocusManager:getFocusedElement()

            if focused ~= nil then
                for _, name in ipairs(buttonNames) do
                    if focused == self[name] then
                        return false
                    end
                end
            end
        end

        return origInputEvent(self, action, value)
    end

    scrollPanel:invalidateLayout()
end

---
function RepopulateFields:addButtonSettingsOption(scrollPanel, settingsPage, settingName, onClickCallback)
    local newOption

    local function callback()
        newOption:setDisabled(true)
        local ok, err = pcall(onClickCallback)

        if not ok then
            Logging.devError("[RepopulateFields]: command '%s' errored: %s", settingName, tostring(err))
        end
    end

    local parent = self.button:clone(scrollPanel)
    newOption = parent.elements[1]
    parent.id = nil
    parent.elements[2]:setText(RepopulateFields:getText(settingName .. "_title"))
    parent:applyProfile("fs25_multiTextOptionContainer", true)

    newOption:setText(RepopulateFields:getText(settingName .. "_button"))
    newOption.id = settingName
    newOption:reset()
    newOption.onClickCallback = callback
    newOption:applyProfile("fs25_settingsPauseButton", true)
    newOption:setIconSize(0, 0)
    newOption:setTextFocusedColor(1, 1, 1, 1)
    settingsPage[settingName] = newOption

    parent:setVisible(true)
    parent:setDisabled(false)

    UIHelper.updateFocusIds(parent)

    return parent
end

---
function RepopulateFields:getText(key)
    return g_i18n:getText(key, RepopulateFields.modName)
end
