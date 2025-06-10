RealisticClothes = RealisticClothes or {}

function RealisticClothes.getRepairedTimes(item)
    return item:getHaveBeenRepaired() - 1
end

function RealisticClothes.createItem(fullType)
    return InventoryItemFactory.CreateItem(fullType)
end