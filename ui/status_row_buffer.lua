local StatusRowBuffer = {}

function StatusRowBuffer.new()
	return {rows = {}, count = 0}
end

function StatusRowBuffer.writeVisitor(buffer, index, id, label, icon, color, stacks, value, remainingFraction)
	local row = buffer.rows[index]
	if not row then
		row = {}
		buffer.rows[index] = row
	end

	row.id = id
	row.label = label
	row.icon = icon
	row.color = color
	row.stacks = stacks
	row.value = value
	row.remainingFraction = remainingFraction
end

function StatusRowBuffer.finish(buffer, count)
	for index = count + 1, buffer.count do
		local row = buffer.rows[index]
		row.id = nil
		row.label = nil
		row.icon = nil
		row.color = nil
		row.stacks = nil
		row.value = nil
		row.remainingFraction = nil
	end
	buffer.count = count
end

return StatusRowBuffer
