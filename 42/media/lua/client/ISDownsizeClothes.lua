require "TimedActions/ISBaseTimedAction"

ISDownsizeClothes = ISBaseTimedAction:derive("ISDownsizeClothes")

function ISDownsizeClothes:new(character, item, needle, scissors, threads, paperclips)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.paperclips = paperclips

    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = character:isTimedActionInstant() and 1 or RealisticClothes.getChangeDuration(item, false)
    return o
end

function ISDownsizeClothes:start()
    self.item:setJobType(getText("IGUI_JobType_DownsizeClothes"))
    self.item:setJobDelta(0.0)

    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.scissors, self.needle)

    self.sound = self.character:getEmitter():playSound("ResizeClothes")
end

function ISDownsizeClothes:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end

    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function ISDownsizeClothes:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end

    ISBaseTimedAction.perform(self)
    self.item:setJobDelta(0.0)

    -- remove used materials
    local threadUses = RealisticClothes.getRequiredThreadCount(self.item)
    local paperclipUses = #self.paperclips

    local successChance = RealisticClothes.getSuccessChanceForChange(
        self.character:getPerkLevel(Perks.Tailoring), RealisticClothes.getRequiredLevelToChange(self.item, false))
    if ZombRandFloat(0, 1) < successChance then 
        local data = RealisticClothes.getOrCreateModData(self.item)
        local newSize = RealisticClothes.getPrevSize(data.size)
        if data.reveal and newSize and newSize.name ~= data.size then
            data.size = newSize.name
            data.resized = -1
            RealisticClothes.updateOneClothes(self.item, self.character)

            -- redraw inventory to separate clothes with different sizes
            self.character:getInventory():setDrawDirty(true)

            if RealisticClothes.canClothesDegrade(self.item) then
                local requiredLevel = RealisticClothes.getRequiredLevelToChange(self.item, false)
                local tailoring = self.character:getPerkLevel(Perks.Tailoring)
                if tailoring > requiredLevel then
                    self.item:setCondition(self.item:getCondtion() + ZombRand(math.min(tailoring - requiredLevel, 3) + 1))
                else
                    if ZombRandFloat(0, 1) < 0.5 then
                        self.item:setCondition(self.item:getCondition() - 1)
                    end
                end
            end
            self.character:getXp():AddXP(Perks.Tailoring, RealisticClothes.getTailoringXpForChange(self.item, false, true))
        else
            error('Invalid size for downsizing: ' .. tostring(data.size))
            threadUses = 0
            paperclipUses = 0
        end
    else
        self.character:getEmitter():playSound("ResizeFailed");
        if RealisticClothes.canClothesDegrade(self.item) then
            if ZombRandFloat(0, 1) < RealisticClothes.ChanceToDegradeOnFailure then
                self.item:setCondition(self.item:getCondition() - 1)
            end
        end
        self.character:getXp():AddXP(Perks.Tailoring, RealisticClothes.getTailoringXpForChange(self.item, false, false))

        -- only cost half the materials on failure
        threadUses = math.ceil(threadUses / 2)
        paperclipUses = math.ceil(paperclipUses / 2)
    end

    for _, thread in ipairs(self.threads) do
        while threadUses > 0 and RealisticClothes.getDrainableUses(thread) > 0 do
            thread:UseAndSync()
            threadUses = threadUses - 1
        end
    end
    for _, paperclip in ipairs(self.paperclips) do
        if paperclipUses > 0 then   
            self.character:getInventory():Remove(paperclip)
            paperclipUses = paperclipUses - 1
        end
    end
end

function ISDownsizeClothes:update()
    self.item:setJobDelta(self:getJobDelta())
end

function ISDownsizeClothes:isValid()
    local inv = self.character:getInventory()

    for _, thread in ipairs(self.threads) do
        if not inv:contains(thread) then return false end
    end

    for _, paperclip in ipairs(self.paperclips) do
        if not inv:contains(paperclip) then return false end
    end

    return inv:contains(self.item)
        and self.character:isPrimaryHandItem(self.scissors)
        and self.character:isSecondaryHandItem(self.needle)
end