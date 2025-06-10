require "TimedActions/ISBaseTimedAction"

ISUpsizeClothes = ISBaseTimedAction:derive("ISUpsizeClothes")

function ISUpsizeClothes:new(character, item, needle, scissors, threads, strips)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.strips = strips

    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = character:isTimedActionInstant() and 1 or RealisticClothes.getChangeDuration(item, true)
    return o
end

function ISUpsizeClothes:start()
    self.item:setJobType(getText("IGUI_JobType_UpsizeClothes"))
    self.item:setJobDelta(0.0)

    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.scissors, self.needle)

    self.sound = self.character:getEmitter():playSound("ResizeClothes")
end

function ISUpsizeClothes:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end

    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function ISUpsizeClothes:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end

    ISBaseTimedAction.perform(self)
    self.item:setJobDelta(0.0)

    -- remove used materials
    local threadUses = RealisticClothes.getRequiredThreadCount(self.item)
    local stripUses = #self.strips

    local successChance = RealisticClothes.getSuccessChanceForChange(
        self.character:getPerkLevel(Perks.Tailoring), RealisticClothes.getRequiredLevelToChange(self.item, true))
    if ZombRandFloat(0, 1) < successChance then
        local data = RealisticClothes.getOrCreateModData(self.item)
        local newSize = RealisticClothes.getNextSize(data.size)
        if data.reveal and newSize and newSize.name ~= data.size then
            data.size = newSize.name
            data.resized = 1
            RealisticClothes.updateOneClothes(self.item, self.character)

            -- redraw inventory to separate clothes with different sizes
            self.character:getInventory():setDrawDirty(true)

            if RealisticClothes.canClothesDegrade(self.item) then
                local requiredLevel = RealisticClothes.getRequiredLevelToChange(self.item, true)
                local tailoring = self.character:getPerkLevel(Perks.Tailoring)
                if tailoring > requiredLevel then
                    self.item:setCondition(self.item:getCondition() + ZombRand(math.min(tailoring - requiredLevel, 3) + 1))
                else
                    if ZombRandFloat(0, 1) < RealisticClothes.ChanceToDegradeOnFailure then
                        self.item:setCondition(self.item:getCondition() - 1)
                    end
                end
            end
            self.character:getXp():AddXP(Perks.Tailoring, RealisticClothes.getTailoringXpForChange(self.item, true, true))
        else
            error('Invalid size for upizing: ' .. tostring(data.size))
            threadUses = 0
            stripUses = 0
        end
    else
        self.character:getEmitter():playSound("ResizeFailed");
        if RealisticClothes.canClothesDegrade(self.item) then
            if ZombRandFloat(0, 1) < 0.5 then
                self.item:setCondition(self.item:getCondition() - 1)
            end
        end
        self.character:getXp():AddXP(Perks.Tailoring, RealisticClothes.getTailoringXpForChange(self.item, true, false))

        -- only cost half the materials on failure
        threadUses = math.ceil(threadUses / 2)
        stripUses = math.ceil(stripUses / 2)
    end

    for _, thread in ipairs(self.threads) do
        while threadUses > 0 and RealisticClothes.getDrainableUses(thread) > 0 do
            RealisticClothes.useDrainable(thread)
            threadUses = threadUses - 1
        end
    end
    for _, strip in ipairs(self.strips) do
        if stripUses > 0 then
            self.character:getInventory():Remove(strip)
            stripUses = stripUses - 1
        end
    end
end

function ISUpsizeClothes:update()
    self.item:setJobDelta(self:getJobDelta())
end

function ISUpsizeClothes:isValid()
    local inv = self.character:getInventory()

    for _, thread in ipairs(self.threads) do
        if not inv:contains(thread) then return false end
    end

    for _, strip in ipairs(self.strips) do
        if not inv:contains(strip) then return false end
    end

    return inv:contains(self.item)
        and self.character:isPrimaryHandItem(self.scissors)
        and self.character:isSecondaryHandItem(self.needle)
end