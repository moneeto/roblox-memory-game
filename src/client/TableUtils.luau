local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local TableUtils = {}

local TAG = "MemoryTable"

function TableUtils.getTableModel(tableId: string): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("Model") and instance.Name == tableId then
			return instance
		end
	end

	local plaza = workspace:FindFirstChild("MemoryPlaza")
	if plaza then
		local found = plaza:FindFirstChild(tableId)
		if found and found:IsA("Model") then
			return found
		end
	end

	local direct = workspace:FindFirstChild(tableId, true)
	if direct and direct:IsA("Model") then
		return direct
	end

	return nil
end

function TableUtils.waitForTableModel(tableId: string, timeout: number?): Model?
	local deadline = os.clock() + (timeout or 8)
	repeat
		local found = TableUtils.getTableModel(tableId)
		if found then
			return found
		end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

function TableUtils.getFocusPart(tableModel: Model): BasePart?
	local boardOrigin = tableModel:FindFirstChild("BoardOrigin")
	if boardOrigin and boardOrigin:IsA("BasePart") then
		return boardOrigin
	end

	local tableTop = tableModel:FindFirstChild("TableTop")
	if tableTop and tableTop:IsA("BasePart") then
		return tableTop
	end

	return tableModel:FindFirstChildWhichIsA("BasePart", true)
end

function TableUtils.getSeatPositions(tableModel: Model): { Vector3 }
	local positions: { Vector3 } = {}
	for _, name in { "Seat1", "Seat2" } do
		local seat = tableModel:FindFirstChild(name)
		if seat and seat:IsA("Seat") then
			table.insert(positions, seat.Position)
		end
	end
	return positions
end

function TableUtils.getLocalPlayerSeat(tableModel: Model, player: Player?): Seat?
	local target = player or Players.LocalPlayer
	for _, name in { "Seat1", "Seat2" } do
		local seat = tableModel:FindFirstChild(name)
		if seat and seat:IsA("Seat") and seat.Occupant then
			local character = seat.Occupant.Parent
			if character and Players:GetPlayerFromCharacter(character) == target then
				return seat
			end
		end
	end
	return nil
end

function TableUtils.getOppositeSeat(tableModel: Model, mySeat: Seat): Seat?
	local otherName = if mySeat.Name == "Seat1" then "Seat2" else "Seat1"
	local other = tableModel:FindFirstChild(otherName)
	if other and other:IsA("Seat") then
		return other
	end
	return nil
end

return TableUtils
