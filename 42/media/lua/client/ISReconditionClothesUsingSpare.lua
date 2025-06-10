require "TimedActions/ISBaseTimedAction"

ISReconditionClothesUsingSpare = ISBaseTimedAction:derive("ISReconditionClothesUsingSpare")

function ISReconditionClothesUsingSpare:new(character, item, needle, scissors, threads, spareItem, threadUses)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.spareItem = spareItem
    o.threadUses = threadUses

    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = character:isTimedActionInstant() and 1 or RealisticClothes.getReconditionDuration(item)
    return o
end

function ISReconditionClothesUsingSpare:start()
    self.item:setJobType(getText("IGUI_JobType_ReconditionClothes"))
    self.item:setJobDelta(0.0)
end

function ISReconditionClothesUsingSpare:stop()
    ISBaseTimedAction.stop(self);
    self.item:setJobDelta(0.0);
end

function ISReconditionClothesUsingSpare:perform()
    ISBaseTimedAction.perform(self);
    self.item:setJobDelta(0.0);

    local threadUses = self.threadUses
    local successChance = RealisticClothes.getSuccessChanceUsingSpare(self.item, self.character, self.spareItem)
    if ZombRandFloat(0, 1) < successChance then
        local potentialRepair = RealisticClothes.getPotentialRepairUsingSpare(self.item, self.character, self.spareItem)
        local conditionGain = math.ceil(potentialRepair * (self.item:getConditionMax() - self.item:getCondition()))
        local repairedTimes = RealisticClothes.getRepairedTimes(self.item)
        self.character:getXp():AddXP(Perks.Tailoring, RealisticClothes.getTailoringXpForRecondition(self.item, true))
        self.character:getXp():AddXP(Perks.Maintenance, conditionGain * 0.5 / (repairedTimes < 10 and (repairedTimes + 1) or 0))

        self.item:setCondition(self.item:getCondition() + conditionGain)
        self.item:setHaveBeenRepaired(self.item:getHaveBeenRepaired() + 1)
        
        self.character:getInventory():Remove(self.spareItem)
    else
        if ZombRandFloat(0, 1) < RealisticClothes.ChanceToDegradeOnFailure then
            self.item:setCondition(self.item:getCondition() - 1)
        end

        self.character:getEmitter():playSound("ResizeFailed")
        self.character:getXp():AddXP(Perks.Tailoring, RealisticClothes.getTailoringXpForRecondition(self.item, false))

        threadUses = math.ceil(threadUses / 2)
        while true do
            if ZombRand(2) == 0 then
                if self.spareItem:getCondition() > 0 then
                    self.spareItem:setCondition(self.spareItem:getCondition() - 1)
                else
                    self.character:getInventory():Remove(self.spareItem)
                    break
                end
            else
                break
            end
        end
    end

    for _, thread in ipairs(self.threads) do
        while threadUses > 0 and RealisticClothes.getDrainableUses(thread) > 0 do
            RealisticClothes.useDrainable(thread)
            threadUses = threadUses - 1
        end
    end
end

function ISReconditionClothesUsingSpare:update()
    self.item:setJobDelta(self:getJobDelta())
end

function ISReconditionClothesUsingSpare:isValid()
    local inv = self.character:getInventory()

    for _, thread in ipairs(self.threads) do
        if not inv:contains(thread) then return false end
    end

    return inv:contains(self.item) and inv:contains(self.needle) and inv:contains(self.scissors) and inv:contains(self.spareItem)
end