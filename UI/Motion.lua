-- Motion: the few animations the UI has, all AnimationGroups (alpha and
-- scale; translation for the tab underline). Timings live in Theme.MOTION.
-- WoW only offers quadratic smoothing ("OUT", "IN_OUT"), not custom curves,
-- so durations are kept short to compensate. Every helper picks up from
-- where the previous animation had got to, so clicking again mid-way never
-- snaps back to the start.
-- "Reduce motion" in Settings (settings.reduceMotion) makes every helper
-- jump straight to its end state. Anything opened from the keyboard
-- (/sk, Escape) is never animated: callers pass instant = true.
local _, SK = ...

local Motion = {}
SK.Motion = Motion
local Theme, Compat = SK.Theme, SK.Compat

function Motion.Enabled()
	return not (SK.DB and SK.DB.settings and SK.DB.settings.reduceMotion)
end

-- One group per (frame, key), created on first use. Kept here, keyed by
-- frame (weakly), rather than as fields on the frames themselves.
local groups = setmetatable({}, { __mode = "k" })
local lastPulse = setmetatable({}, { __mode = "k" })

local function group(frame, key)
	local mine = groups[frame]
	if not mine then
		mine = {}
		groups[frame] = mine
	end
	local e = mine[key]
	if not e then
		-- e.g is the group; the animations in it are kept beside it on e.
		e = { g = frame:CreateAnimationGroup() }
		mine[key] = e
	end
	return e
end

local function stopAll(frame)
	for _, e in pairs(groups[frame] or {}) do
		if e.g:IsPlaying() then e.g:Stop() end
	end
end

-- How opaque the frame looks right now, part-way through a fade in or out.
local function shownAlpha(frame)
	local mine = groups[frame] or {}
	for key, e in pairs(mine) do
		if (key == "in" or key == "out") and e.alpha and e.g:IsPlaying() then
			local p = e.alpha:GetSmoothProgress() or 0
			local from, to = e.alpha:GetFromAlpha() or 0, e.alpha:GetToAlpha() or 1
			return from + (to - from) * p
		end
	end
	return frame:IsShown() and 1 or 0
end

-- Fade + grow in. origin: "CENTER" for the window (not anchored to a
-- trigger), "TOP" for a menu that drops from its button.
function Motion.In(frame, duration, scale, origin, instant)
	local from = frame:IsShown() and shownAlpha(frame) or 0
	stopAll(frame)
	frame:SetAlpha(1)
	frame:Show()
	if instant or not Motion.Enabled() or from >= 1 then return end
	local e = group(frame, "in")
	local g = e.g
	if not e.alpha then
		e.alpha = g:CreateAnimation("Alpha")
		e.alpha:SetToAlpha(1)
		e.alpha:SetSmoothing("OUT")
		e.scale = g:CreateAnimation("Scale")
		e.scale:SetSmoothing("OUT")
		e.hasScale = Compat.SetAnimScale(e.scale, scale or 1, 1)
		e.scale:SetOrigin(origin or "CENTER", 0, 0)
	end
	-- Interrupted fade-out: carry on from the current opacity, for the time
	-- that's left, and don't grow again.
	e.alpha:SetFromAlpha(from)
	e.alpha:SetDuration(duration * (1 - from))
	e.scale:SetDuration(e.hasScale and scale and from == 0 and duration or 0)
	g:Play()
end

-- Fade out, then Hide(). Faster than the entrance.
function Motion.Out(frame, duration, instant)
	if not frame:IsShown() then return end
	if instant or not Motion.Enabled() then
		stopAll(frame)
		frame:Hide()
		return
	end
	local e = group(frame, "out")
	local g = e.g
	if g:IsPlaying() then return end
	local from = shownAlpha(frame)
	if not e.alpha then
		e.alpha = g:CreateAnimation("Alpha")
		e.alpha:SetToAlpha(0)
		e.alpha:SetSmoothing("OUT")
		g:SetScript("OnFinished", function()
			frame:Hide()
			frame:SetAlpha(1)
		end)
	end
	stopAll(frame)
	e.alpha:SetFromAlpha(from)
	e.alpha:SetDuration(math.max(0.01, duration * from))
	g:Play()
end

function Motion.IsLeaving(frame)
	local e = groups[frame] and groups[frame].out
	return e ~= nil and e.g:IsPlaying() and true or false
end

-- Hover highlight: fades in, disappears at once on leave.
function Motion.HoverIn(region)
	region:Show()
	if not Motion.Enabled() then return end
	local e = group(region, "hover")
	local g = e.g
	if not e.alpha then
		e.alpha = g:CreateAnimation("Alpha")
		e.alpha:SetFromAlpha(0)
		e.alpha:SetToAlpha(1)
		e.alpha:SetSmoothing("OUT")
		e.alpha:SetDuration(Theme.MOTION.hover)
	end
	g:Restart()
end

function Motion.HoverOut(region)
	stopAll(region)
	region:Hide()
end

-- Glide a marker from where it was to its new anchor. Call after the
-- marker has been re-anchored; dx is old left minus new left, and
-- widthRatio is old width / new width.
function Motion.Glide(marker, dx, widthRatio, duration)
	if not Motion.Enabled() or not dx or (math.abs(dx) < 0.5 and math.abs((widthRatio or 1) - 1) < 0.01) then return end
	local e = group(marker, "glide")
	local g = e.g
	if not e.jump then
		-- Translation offsets add up inside a group: jump back to the old
		-- place instantly, then travel to the new one.
		e.jump = g:CreateAnimation("Translation")
		e.jump:SetOrder(1)
		e.jump:SetDuration(0)
		e.move = g:CreateAnimation("Translation")
		e.move:SetOrder(2)
		e.move:SetSmoothing("IN_OUT")
		e.width = g:CreateAnimation("Scale")
		e.width:SetOrder(2)
		e.width:SetSmoothing("IN_OUT")
		e.width:SetOrigin("LEFT", 0, 0)
	end
	-- Clicked again mid-glide: start from where the marker is now, not from
	-- the tab it was heading to.
	if g:IsPlaying() and e.dx then
		dx = dx + e.dx * (1 - (e.move:GetSmoothProgress() or 1))
		g:Stop()
	end
	e.dx = dx
	e.jump:SetOffset(dx, 0)
	e.move:SetOffset(-dx, 0)
	e.move:SetDuration(duration)
	local scaled = e.width.SetScaleFrom and widthRatio and widthRatio > 0
	if scaled then
		e.width:SetScaleFrom(widthRatio, 1)
		e.width:SetScaleTo(1, 1)
	end
	e.width:SetDuration(scaled and duration or 0)
	g:Play()
end

-- Sync heard something: a ring grows out of the status dot and fades.
-- A status signal, not a response to a click, so it may run a little past
-- 300 ms. At most once per Theme.MOTION.pulseEvery seconds (a login backfill
-- brings dozens of profiles; one ring says it, twenty would be noise), and
-- only while the window is on screen.
function Motion.Pulse(ring, now)
	if not Motion.Enabled() or not ring:IsVisible() then return end
	if lastPulse[ring] and now and now - lastPulse[ring] < Theme.MOTION.pulseEvery then return end
	lastPulse[ring] = now
	local e = group(ring, "pulse")
	local g = e.g
	if not e.alpha then
		e.alpha = g:CreateAnimation("Alpha")
		e.alpha:SetFromAlpha(0.9)
		e.alpha:SetToAlpha(0)
		e.alpha:SetSmoothing("OUT")
		e.scale = g:CreateAnimation("Scale")
		e.scale:SetSmoothing("OUT")
		e.hasScale = Compat.SetAnimScale(e.scale, 0.6, 1.6)
		g:SetScript("OnFinished", function() ring:SetAlpha(0) end)
		g:SetScript("OnPlay", function() ring:SetAlpha(1) end)
	end
	e.alpha:SetDuration(Theme.MOTION.pulse)
	e.scale:SetDuration(e.hasScale and Theme.MOTION.pulse or 0)
	g:Restart()
end
