local Cursor = {
    x = 0,
    y = 0,
    usingVirtual = false,
}

function Cursor.update()
    if Cursor.usingVirtual then
        -- updated by stick / keys later
    else
        Cursor.x, Cursor.y = love.mouse.getPosition()
    end
end

return Cursor