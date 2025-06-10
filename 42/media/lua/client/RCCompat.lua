RealisticClothes = RealisticClothes or {}

function RealisticClothes.getRepairedTimes(item)
    return item:getHaveBeenRepaired()
end

function RealisticClothes.createItem(fullType)
    return instanceItem(fullType)
end

function RealisticClothes.getDrainableUses(item)
    return item:getCurrentUses()
end