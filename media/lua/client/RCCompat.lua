-- functions providing compability between B41 and B42

RealisticClothes = RealisticClothes or {}

function RealisticClothes.getRepairedTimes(item)
    return item:getHaveBeenRepaired() - 1
end

function RealisticClothes.createItem(fullType)
    return InventoryItemFactory.CreateItem(fullType)
end

function RealisticClothes.getDrainableUses(item)
    return item:getRemainingUses()
end

function RealisticClothes.useDrainable(item)
    item:Use()
end