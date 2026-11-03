-- Motion: the few animations the UI has, all AnimationGroups (alpha and
-- scale; translation for the tab underline). Timings live in Theme.MOTION.
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

-- One group per (frame, key), created on first use.
local function group(frame, key)
	frame.skAnims = frame.skAnims or {}
	local g = frame.skAnims[key]
	if not g then
		g = frame:CreateAnimationGroup()
		frame.skAnims[key] = g
	end
	return g
end

local function stopAll(frame)
	for _, g in pairs(frame.skAnims or {}) do
		if g:IsPlaying() then g:Stop() end
	end
end

-- Fade + grow in. origin: "CENTER" for the window (not anchored to a
-- trigger), "TOP" for a menu that drops from its button.
function Motion.In(frame, duration, scale, origin, instant)
	stopAll(frame)
	frame:SetAlpha(1)
	frame:Show()
	if instant or not Motion.Enabled() then return end
	local g = group(frame, "in")
	if not g.alpha then
		g.alpha = g:CreateAnimation("Alpha")
		g.alpha:SetFromAlpha(0)
		g.alpha:SetToAlpha(1)
		g.alpha:SetSmoothing("OUT")
		g.scale = g:CreateAnimation("Scale")
		g.scale:SetSmoothing("OUT")
		g.hasScale = Compat.SetAnimScale(g.scale, scale or 1, 1)
		g.scale:SetOrigin(origin or "CENTER", 0, 0)
	end
	g.alpha:SetDuration(duration)
	g.scale:SetDuration(g.hasScale and scale and duration or 0)
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
	local g = group(frame, "out")
	if not g.alpha then
		g.alpha = g:CreateAnimation("Alpha")
		g.alpha:SetFromAlpha(1)
		g.alpha:SetToAlpha(0)
		g.alpha:SetSmoothing("OUT")
		g:SetScript("OnFinished", function()
			frame:Hide()
			frame:SetAlpha(1)
		end)
	end
	if g:IsPlaying() then return end
	stopAll(frame)
	g.alpha:SetDuration(duration)
	g:Play()
end

function Motion.IsLeaving(frame)
	local g = frame.skAnims and frame.skAnims.out
	return g ~= nil and g:IsPlaying() and true or false
end

-- A quick lift of new content: from `from` alpha (never 0, so the page is
-- readable at once) to 1.
function Motion.Reveal(frame, duration, from)
	if not Motion.Enabled() then frame:SetAlpha(1) return end
	local g = group(frame, "reveal")
	if not g.alpha then
		g.alpha = g:CreateAnimation("Alpha")
		g.alpha:SetToAlpha(1)
		g.alpha:SetSmoothing("OUT")
	end
	if g:IsPlaying() then g:Stop() end
	g.alpha:SetFromAlpha(from or 0.4)
	g.alpha:SetDuration(duration)
	g:Play()
end

-- Hover highlight: fades in, disappears at once on leave.
function Motion.HoverIn(region)
	region:Show()
	if not Motion.Enabled() then return end
	local g = group(region, "hover")
	if not g.alpha then
		g.alpha = g:CreateAnimation("Alpha")
		g.alpha:SetFromAlpha(0)
		g.alpha:SetToAlpha(1)
		g.alpha:SetSmoothing("OUT")
		g.alpha:SetDuration(Theme.MOTION.hover)
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
	local g = group(marker, "glide")
	if not g.jump then
		-- Translation offsets add up inside a group: jump back to the old
		-- place instantly, then travel to the new one.
		g.jump = g:CreateAnimation("Translation")
		g.jump:SetOrder(1)
		g.jump:SetDuration(0)
		g.move = g:CreateAnimation("Translation")
		g.move:SetOrder(2)
		g.move:SetSmoothing("IN_OUT")
		g.width = g:CreateAnimation("Scale")
		g.width:SetOrder(2)
		g.width:SetSmoothing("IN_OUT")
		g.width:SetOrigin("LEFT", 0, 0)
	end
	if g:IsPlaying() then g:Stop() end
	g.jump:SetOffset(dx, 0)
	g.move:SetOffset(-dx, 0)
	g.move:SetDuration(duration)
	local scaled = g.width.SetScaleFrom and widthRatio and widthRatio > 0
	if scaled then
		g.width:SetScaleFrom(widthRatio, 1)
		g.width:SetScaleTo(1, 1)
	end
	g.width:SetDuration(scaled and duration or 0)
	g:Play()
end

-- Sync heard something: a ring grows out of the status dot and fades.
-- At most once every 2 s, and only while the window is on screen.
function Motion.Pulse(ring, now)
	if not Motion.Enabled() or not ring:IsVisible() then return end
	if ring.lastPulse and now and now - ring.lastPulse < 2 then return end
	ring.lastPulse = now
	local g = group(ring, "pulse")
	if not g.alpha then
		g.alpha = g:CreateAnimation("Alpha")
		g.alpha:SetFromAlpha(0.9)
		g.alpha:SetToAlpha(0)
		g.alpha:SetSmoothing("OUT")
		g.scale = g:CreateAnimation("Scale")
		g.scale:SetSmoothing("OUT")
		g.hasScale = Compat.SetAnimScale(g.scale, 0.6, 1.6)
		g:SetScript("OnFinished", function() ring:SetAlpha(0) end)
		g:SetScript("OnPlay", function() ring:SetAlpha(1) end)
	end
	g.alpha:SetDuration(Theme.MOTION.pulse)
	g.scale:SetDuration(g.hasScale and Theme.MOTION.pulse or 0)
	g:Restart()
end
