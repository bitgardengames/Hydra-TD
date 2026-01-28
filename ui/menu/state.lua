local State = {}

State.cursor = 1
State.settingsCursor = 1

State.previewAlpha = 1

State.lancerIdle = {
	angle = -math.pi / 6,
	from = -math.pi / 6,
	to = -math.pi / 6 - math.rad(28),
	t = 0,
	hold = 0,
	dir = 1,
	startupHold = 5,
}

State.mapPreviews = {}

return State