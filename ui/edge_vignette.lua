-- Cached, resolution-independent edge falloff used behind opaque UI panels.
local EdgeVignette = {}

local shader

local shaderSource = [[
	extern vec2 viewportSize;
	extern vec2 clearHalfSize;

	vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
	{
		vec2 center = viewportSize * 0.5;
		vec2 edgeWidth = max(center - clearHalfSize, vec2(1.0));
		vec2 beyondCenter = max(abs(screenCoords - center) - clearHalfSize, vec2(0.0));
		float edge = max(beyondCenter.x / edgeWidth.x, beyondCenter.y / edgeWidth.y);
		float falloff = smoothstep(0.0, 1.0, edge);
		return vec4(color.rgb, color.a * falloff * falloff);
	}
]]

local function getShader()
	if not shader then shader = love.graphics.newShader(shaderSource) end
	return shader
end

function EdgeVignette.draw(width, height, clearWidth, clearHeight, color, alpha)
	local activeShader = getShader()
	activeShader:send("viewportSize", {width, height})
	activeShader:send("clearHalfSize", {
		math.min(clearWidth * 0.5, width * 0.5),
		math.min(clearHeight * 0.5, height * 0.5),
	})

	love.graphics.setShader(activeShader)
	love.graphics.setColor(color[1], color[2], color[3], alpha)
	love.graphics.rectangle("fill", 0, 0, width, height)
	love.graphics.setShader()
end

return EdgeVignette
