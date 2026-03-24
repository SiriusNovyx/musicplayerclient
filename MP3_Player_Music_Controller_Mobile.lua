local Svc={Players=game:GetService("Players"),UserInput=game:GetService("UserInputService"),SoundService=game:GetService("SoundService"),RunService=game:GetService("RunService"),TweenService=game:GetService("TweenService"),ReplicatedStorage=game:GetService("ReplicatedStorage"),Workspace=game:GetService("Workspace"),MarketplaceService=game:GetService("MarketplaceService"),HttpService=game:GetService("HttpService"),Debris=game:GetService("Debris")}
-- Safe pcall wrapper that logs failures to output
local function safeCall(fn, context)
	local ok, err = pcall(fn)
	if not ok then
		warn("[MusicController] Error" .. (context and (" in " .. context) or "") .. ": " .. tostring(err))
	end
	return ok
end

-- Simple connection manager to prevent leaks
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _connections = {} }, Maid)
end

function Maid:add(conn)
	table.insert(self._connections, conn)
	return conn
end

function Maid:cleanUp()
	for _, conn in ipairs(self._connections) do
		if conn and conn.Disconnect then
			pcall(function() conn:Disconnect() end)
		end
	end
	self._connections = {}
end

local mainMaid = Maid.new()

local player=Svc.Players.LocalPlayer
local pGui=player:WaitForChild("PlayerGui")
local C={BG=Color3.fromRGB(5,4,3),CARD_HI=Color3.fromRGB(26,20,10),CARD_LO=Color3.fromRGB(3,2,1),SURFACE=Color3.fromRGB(16,13,7),ELEVATED=Color3.fromRGB(30,24,12),BORDER=Color3.fromRGB(46,36,16),BORDER_LIT=Color3.fromRGB(148,114,42),ACCENT=Color3.fromRGB(208,164,68),ACCENT_DIM=Color3.fromRGB(86,64,20),TEXT=Color3.fromRGB(230,218,186),TEXT2=Color3.fromRGB(132,112,70),TEXT3=Color3.fromRGB(62,50,26),SUCCESS=Color3.fromRGB(72,190,110),DANGER=Color3.fromRGB(200,62,62),HANDLE=Color3.fromRGB(206,174,100)}
local AT=Color3.fromRGB(10,8,4)
-- ─────────────────────────────────────────────────────────────────────────────
-- MOBILE / SCREEN-SIZE ADAPTATION
-- Detects touch devices and small viewports, then scales every fixed-pixel
-- dimension proportionally so the UI fits any screen.
-- ─────────────────────────────────────────────────────────────────────────────
local GuiService  = game:GetService("GuiService")
local UserInputService = Svc.UserInput

local function getViewport()
	return Svc.Workspace.CurrentCamera and Svc.Workspace.CurrentCamera.ViewportSize
		or Vector2.new(1920, 1080)
end

-- Returns true when running on a touch/mobile device
local function isMobileDevice()
	local ok, hasTouchEnabled = pcall(function()
		return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end)
	return ok and hasTouchEnabled
end

-- Base design resolution the UI was built for
local DESIGN_WIDTH  = 1280
local DESIGN_HEIGHT = 720

-- Compute a 0-1 scale factor so the card always fits within the viewport
local function computeUiScale()
	local vp = getViewport()
	local scaleX = vp.X / DESIGN_WIDTH
	local scaleY = vp.Y / DESIGN_HEIGHT
	-- Use the smaller axis so nothing gets cropped
	local scale  = math.min(scaleX, scaleY)
	-- On non-mobile desktop don't scale *up* beyond 1
	if not isMobileDevice() then
		scale = math.min(scale, 1)
	end
	-- Clamp so the UI is never unreadably tiny
	return math.clamp(scale, 0.42, 1.2)
end

-- Whether the viewport is narrow enough to be treated as "mobile layout"
local function isMobileLayout()
	local vp = getViewport()
	return vp.X < 700 or isMobileDevice()
end

-- Live scale value — recalculated on viewport changes
local currentUiScale = computeUiScale()

local Cfg={workspacePath="Music Workspace/Musics",configsPath="Music Workspace/Configs",categoriesPath="Music Workspace/Configs/categories.json",soundIdsPath="Music Workspace/Configs/soundids.json",AUTO_SCAN_INTERVAL=2,CROSSFADE_TIME=1.0,CROSSFADE_TRIGGER=1.0,TRACK_SWITCH_COOLDOWN=1,CARD_WIDTH=380,BASE_HEIGHT=315,REVERB_EXTRA_HEIGHT=150,LIST_WIDTH=260,SLIDER_MIN=0,SLIDER_MAX=10,SNAP_VALUE=1,SNAP_THRESHOLD=0.25,SOUND_ID_CATEGORY_ID="__ROBLOX_SOUND_IDS__",SOUND_ID_CATEGORY_NAME="Roblox Sound ID's",ORDER_PATH="Music Workspace/Configs/order.json",SETTINGS_PATH="Music Workspace/Configs/settings.json",DNPATH="Music Workspace/Configs/displaynames.json",SHAKE_PANEL_HEIGHT=58,THEME_ROW_HEIGHT=28,THEME_PANEL_COLLAPSED_HEIGHT=36,PANEL_GAP=12,REVERB_ROW_HEIGHT=18,REVERB_ROW_GAP=4,FLAGGED_PATH="Music Workspace/Configs/flagged_instrumental.json"}
local St={currentVolume=1,currentSpeed=1,currentIncrement=0.1,crossfadeEnabled=true,repeatEnabled=false,shuffleEnabled=false,screenShakeEnabled=false,lyricsEnabled=false,currentTrackIndex=1,isPaused=true,lastTrackSwitchTime=0,showingSettings=false,guiOpen=true,animating=false,draggingWindow=false,draggingProgress=false,wasPlayingBeforeDrag=false,listPanelOpen=false,queuePanelOpen=false,capturingKeybind=false,isShowingNotification=false,lastDisplayedTime="",draggedButton=nil,isDraggingToQueue=false,draggedTrackIndex=nil,isDraggingToCategory=false,categoryBeingRenamed=nil,expandedCategories={},selectingCategoryForTrack=false,pendingTrackIndexForCategory=nil,hoveredCategoryIndex=nil,shakeIntensity=1,fovIntensity=1,hoveredTrackIndex=nil,hoveredTrackInCategory=false,pendingDeleteTrackIndex=nil,crossfadeTriggered=false,settingsActiveTab="main",searchQuery="",searchActive=false,notifVolume=0.65,muteGameSounds=false,pendingRenameSoundIdIndex=nil,scResults={},scIdx=1,scBusy=false,scGen=0,scArtGen=0,scCid=nil,translateEnabled=false,cinematicMode=false,kbPrev=Enum.KeyCode.F6,kbPlay=Enum.KeyCode.F7,kbNext=Enum.KeyCode.F8,kbRepeat=nil,kbShuffle=nil,kbLyrics=nil,kbTranslate=nil,kbMute=nil,kbCinematic=nil}
local Dat={trackList={},createdSounds={},queueList={},lastMp3Files={},notificationQueue={},categories={},meterBars={},soundEndedConnection=nil,currentTrackAnimationTween=nil,dragStart=nil,startPos=nil,trackOrderList={},listButtonRefs={},suppressAutoNotify={},crossfadingSounds={},activeFadeOutTween=nil,crossfadeCleanupGen=0,currentLyrics={},lyricsFetchGen=0,lastLyricIndex=-1,permanentlyDeleted={},eolFired=false,smoothShakeLoud=0,fovLockedVal=nil,fovBaseline=nil,fovSmooth=0,muteConns={},muteDescConn=nil,toastBarTween=nil,translateCache={},translatePending={},prevTrackIndex=nil}
local UI={}
local shakeVal=Svc.ReplicatedStorage:FindFirstChild("ShakinessEnabled") or Instance.new("BoolValue")
shakeVal.Name="ShakinessEnabled"
shakeVal.Value=false
shakeVal.Parent=Svc.ReplicatedStorage
St.screenShakeEnabled=false
local kbVal=Svc.ReplicatedStorage:FindFirstChild("MusicControllerKeybind")
if not kbVal then kbVal=Instance.new("StringValue")
kbVal.Name="MusicControllerKeybind"
kbVal.Value="N"
kbVal.Parent=Svc.ReplicatedStorage end
local function keyNameToKeyCode(n) for _,k in ipairs(Enum.KeyCode:GetEnumItems()) do if k.Name==n then return k end end end
local curKC=keyNameToKeyCode(kbVal.Value) or Enum.KeyCode.N
kbVal.Changed:Connect(function(v) local k=keyNameToKeyCode(v);if k then curKC=k end end)
for _,n in ipairs({"MusicControllerGui","MusicLyricsOverlay","MusicLyricsGui"}) do local x=pGui:FindFirstChild(n)
if x then x:Destroy() end end
if _G.__MCMuteCleanup then pcall(_G.__MCMuteCleanup)
_G.__MCMuteCleanup=nil end
pcall(function() local f=Svc.SoundService:FindFirstChild("MusicControllerSounds");if f then for _,s in ipairs(f:GetChildren()) do if s:IsA("Sound") then s:Stop() end end;f:Destroy() end end)
local displayNamesMap=Dat.displayNamesMap or {}
local function loadDisplayNameMap() if isfile(Cfg.DNPATH) then local ok,r=pcall(function() return Svc.HttpService:JSONDecode(readfile(Cfg.DNPATH)) end)
if ok and r then displayNamesMap=r end end end
local function saveDisplayNameMap() if not isfolder(Cfg.configsPath) then makefolder(Cfg.configsPath) end
pcall(function() writefile(Cfg.DNPATH,Svc.HttpService:JSONEncode(displayNamesMap)) end) end
local flaggedInstrumental={}
local function loadFlaggedInstrumentals() if isfile(Cfg.FLAGGED_PATH) then local ok,r=pcall(function() return Svc.HttpService:JSONDecode(readfile(Cfg.FLAGGED_PATH)) end)
if ok and type(r)=="table" then flaggedInstrumental=r end end end
local function saveFlaggedInstrumentals() if not isfolder(Cfg.configsPath) then makefolder(Cfg.configsPath) end
pcall(function() writefile(Cfg.FLAGGED_PATH,Svc.HttpService:JSONEncode(flaggedInstrumental)) end) end
-- ─────────────────────────────────────────────────────────────────────────────
-- SETTINGS SCHEMA
-- Single source of truth for all persisted settings.
-- Each entry: { key, type, default, min?, max? }
-- loadUserSettings and saveUserSettings both derive from this table.
-- ─────────────────────────────────────────────────────────────────────────────
local SETTINGS_SCHEMA = {
	{ key = "volume",        stateKey = "currentVolume",   type = "number"  },
	{ key = "speed",         stateKey = "currentSpeed",    type = "number"  },
	{ key = "increment",     stateKey = "currentIncrement",type = "number"  },
	{ key = "crossfade",     stateKey = "crossfadeEnabled",type = "boolean" },
	{ key = "repeat_",       stateKey = "repeatEnabled",   type = "boolean" },
	{ key = "shuffle",       stateKey = "shuffleEnabled",  type = "boolean" },
	{ key = "shakeIntensity",stateKey = "shakeIntensity",  type = "number"  },
	{ key = "fovIntensity",  stateKey = "fovIntensity",    type = "number"  },
	{ key = "notifVolume",   stateKey = "notifVolume",     type = "number"  },
	{ key = "mute",          stateKey = "muteGameSounds",  type = "boolean" },
	{ key = "translate",     stateKey = "translateEnabled",type = "boolean" },
}

local KEYBIND_SCHEMA = {
	{ key = "kbPrev",      default = Enum.KeyCode.F6  },
	{ key = "kbPlay",      default = Enum.KeyCode.F7  },
	{ key = "kbNext",      default = Enum.KeyCode.F8  },
	{ key = "kbRepeat",    default = nil              },
	{ key = "kbShuffle",   default = nil              },
	{ key = "kbLyrics",    default = nil              },
	{ key = "kbTranslate", default = nil              },
	{ key = "kbMute",      default = nil              },
	{ key = "kbCinematic", default = nil              },
}

local function saveUserSettings()
	if not isfolder(Cfg.configsPath) then makefolder(Cfg.configsPath) end
	local function kbn(k) return St[k] and St[k].Name or nil end
	local d={volume=St.currentVolume,speed=St.currentSpeed,increment=St.currentIncrement,crossfade=St.crossfadeEnabled,repeat_=St.repeatEnabled,shuffle=St.shuffleEnabled,shakeIntensity=St.shakeIntensity,fovIntensity=St.fovIntensity,notifVolume=St.notifVolume,mute=St.muteGameSounds,translate=St.translateEnabled,kbPrev=kbn("kbPrev"),kbPlay=kbn("kbPlay"),kbNext=kbn("kbNext"),kbRepeat=kbn("kbRepeat"),kbShuffle=kbn("kbShuffle"),kbLyrics=kbn("kbLyrics"),kbTranslate=kbn("kbTranslate"),kbMute=kbn("kbMute"),kbCinematic=kbn("kbCinematic")}
	pcall(function() writefile(Cfg.SETTINGS_PATH,Svc.HttpService:JSONEncode(d)) end)
end
local function loadUserSettings()
	if not isfile(Cfg.SETTINGS_PATH) then return end
	local ok,d=pcall(function() return Svc.HttpService:JSONDecode(readfile(Cfg.SETTINGS_PATH)) end)
	if not ok or not d then return end
	if type(d.volume)=="number" then St.currentVolume=d.volume end
if type(d.speed)=="number" then St.currentSpeed=d.speed end
	if type(d.increment)=="number" then St.currentIncrement=d.increment end
if type(d.crossfade)=="boolean" then St.crossfadeEnabled=d.crossfade end
	if type(d.repeat_)=="boolean" then St.repeatEnabled=d.repeat_ end
if type(d.shuffle)=="boolean" then St.shuffleEnabled=d.shuffle end
	if type(d.shakeIntensity)=="number" then St.shakeIntensity=d.shakeIntensity end
	if type(d.fovIntensity)=="number" then St.fovIntensity=d.fovIntensity end
	if type(d.notifVolume)=="number" then St.notifVolume=d.notifVolume end
if type(d.mute)=="boolean" then St.muteGameSounds=d.mute end
	if type(d.translate)=="boolean" then St.translateEnabled=d.translate end
	local function lkb(k,def) if type(d[k])=="string" then local kc=Enum.KeyCode:GetEnumItems()
for _,e in ipairs(kc) do if e.Name==d[k] then St[k]=e
return end end end
St[k]=def end
	lkb("kbPrev",Enum.KeyCode.F6)
lkb("kbPlay",Enum.KeyCode.F7)
lkb("kbNext",Enum.KeyCode.F8)
	lkb("kbRepeat",nil)
lkb("kbShuffle",nil)
lkb("kbLyrics",nil)
lkb("kbTranslate",nil)
lkb("kbMute",nil)
lkb("kbCinematic",nil)
end
local function makeSafeFilename(displayName)
	local safe=displayName:gsub("[^%w%s%.%-%_%(%)%[%]%!]","")
safe=safe:gsub("%s+","_"):match("^%s*(.-)%s*$") or ""
	if #safe==0 then local hex=""
for i=1,#displayName do hex=hex..string.format("%02X",displayName:byte(i)) end
safe="track_"..hex:sub(1,32) end
return safe
end
local function getTrackDisplayName(diskBaseName) return displayNamesMap[diskBaseName] or diskBaseName end
local function ensureMusicDirectories() if not isfolder("Workspace") then makefolder("Workspace") end
if not isfolder(Cfg.workspacePath) then makefolder(Cfg.workspacePath)
writefile(Cfg.workspacePath.."/README.txt","Place your MP3 files here!") end end
local function scanMusicDirectory()
	local r={}
	if isfolder(Cfg.workspacePath) then
		for _,p in ipairs(listfiles(Cfg.workspacePath)) do
			local _np=p:gsub("\\","/")
local n=_np:match("([^/]+)$") or p
			if n and n:lower():match("%.mp3$") then
				if Dat.permanentlyDeleted[p] then continue end
				local diskBase=n:gsub("%.mp3$","")
local displayName=getTrackDisplayName(diskBase)
				table.insert(r,{Path=p,Name=displayName,FileName=n,Type="mp3"})
			end
		end
	end
return r
end
local function getTrackId(t) if t.Type=="mp3" then return "mp3:"..(t.FileName or t.DisplayName) end
if t.Type=="soundid" then return "soundid:"..tostring(t.SoundId) end
return "name:"..(t.DisplayName or "") end
local function saveCategoriesToDisk()
	local seen,clean={},{}
	for _,cat in ipairs(Dat.categories) do
		if cat.CategoryID then
			if not seen[cat.CategoryID] then seen[cat.CategoryID]=cat
table.insert(clean,cat)
			else local ex=seen[cat.CategoryID]
for _,tid in ipairs(cat.TrackTIDs or {}) do local dup=false
for _,et in ipairs(ex.TrackTIDs or {}) do if et==tid then dup=true
break end end
if not dup then table.insert(ex.TrackTIDs,tid) end end end
		else table.insert(clean,cat) end
	end
	Dat.categories=clean
local cd={}
	for _,cat in ipairs(Dat.categories) do table.insert(cd,{Name=cat.Name,TrackTIDs=cat.TrackTIDs or {},CategoryID=cat.CategoryID}) end
	if not isfolder(Cfg.configsPath) then makefolder(Cfg.configsPath) end
writefile(Cfg.categoriesPath,Svc.HttpService:JSONEncode(cd))
end
local function rebuildCategoryTrackIndices()
	local tidToIdx={}
	for i,t in ipairs(Dat.trackList) do tidToIdx[getTrackId(t)]=i end
	for _,cat in ipairs(Dat.categories) do
		if not cat.TrackTIDs then cat.TrackTIDs={} end
		local newTracks={}
local seen={}
		for _,tid in ipairs(cat.TrackTIDs) do local idx=tidToIdx[tid]
if idx and not seen[idx] then table.insert(newTracks,idx)
seen[idx]=true end end
		cat.Tracks=newTracks
	end
end
local function loadCategoriesFromDisk()
	if not isfile(Cfg.categoriesPath) then return end
	local ok,r=pcall(function() return Svc.HttpService:JSONDecode(readfile(Cfg.categoriesPath)) end)
	if not ok or not r then return end
	Dat.categories={}
local seen={}
	for _,cd in ipairs(r) do
		local tids=cd.TrackTIDs or {}
local cat={Name=cd.Name,Tracks={},TrackTIDs=tids,CategoryID=cd.CategoryID}
		if cd.CategoryID and seen[cd.CategoryID] then local ex=seen[cd.CategoryID]
for _,tid in ipairs(tids) do local f=false
for _,et in ipairs(ex.TrackTIDs) do if et==tid then f=true
break end end
if not f then table.insert(ex.TrackTIDs,tid) end end
		else table.insert(Dat.categories,cat)
if cd.CategoryID then seen[cd.CategoryID]=cat end end
	end
end
ensureMusicDirectories()
if not isfolder(Cfg.configsPath) then makefolder(Cfg.configsPath) end
if not isfile(Cfg.soundIdsPath) then safeCall(function() writefile(Cfg.soundIdsPath,"[]") end, "writefile") end
pcall(function() if isfolder(Cfg.configsPath) then for _,f in ipairs(listfiles(Cfg.configsPath)) do local fn=(f:gsub("\\","/"):match("([^/]+)$") or ""):lower();if fn:match("^sc_art_") or fn:match("^dl_art_") then safeCall(function() delfile(f) end, "delfile") end end end end)
loadCategoriesFromDisk()
loadDisplayNameMap()
loadFlaggedInstrumentals()
loadUserSettings()
local function saveTrackOrder() if not isfolder(Cfg.configsPath) then makefolder(Cfg.configsPath) end
pcall(function() writefile(Cfg.ORDER_PATH,Svc.HttpService:JSONEncode(Dat.trackOrderList)) end) end
local function loadTrackOrder() if isfile(Cfg.ORDER_PATH) then local ok,r=pcall(function() return Svc.HttpService:JSONDecode(readfile(Cfg.ORDER_PATH)) end)
if ok and r then Dat.trackOrderList=r end end end
local function getOrderedUncategorizedTracks()
	local us,ul={},{}
	for i,t in ipairs(Dat.trackList) do
		if Dat.createdSounds[i]==false then continue end
		local inc=false
for _,cat in ipairs(Dat.categories) do for _,idx in ipairs(cat.Tracks) do if idx==i then inc=true
break end end
if inc then break end end
		if not inc then local id=getTrackId(t)
us[id]=i
table.insert(ul,{id=id,index=i,name=(t.DisplayName or ""):lower()}) end
	end
	local res,placed={},{}
	for _,id in ipairs(Dat.trackOrderList) do if us[id] then table.insert(res,us[id])
placed[id]=true end end
	local chg=false
	local newItems={}
	for _,item in ipairs(ul) do if not placed[item.id] then table.insert(newItems,item) end end
	table.sort(newItems,function(a,b) return a.name<b.name end)
	for _,item in ipairs(newItems) do
		local inserted=false
		local itmName=item.name
		for pos,id in ipairs(Dat.trackOrderList) do
			local existing=us[id] and Dat.trackList[us[id]]
			if existing and (existing.DisplayName or ""):lower()>itmName then
				table.insert(Dat.trackOrderList,pos,item.id)
				table.insert(res,pos,item.index)
				inserted=true
chg=true
break
			end
		end
		if not inserted then table.insert(res,item.index)
table.insert(Dat.trackOrderList,item.id)
chg=true end
	end
	local co={}
	for _,id in ipairs(Dat.trackOrderList) do if us[id] then table.insert(co,id) else chg=true end end
	Dat.trackOrderList=co
if chg then saveTrackOrder() end
return res
end
loadTrackOrder()
local sfHolder=Instance.new("Folder")
sfHolder.Name="MusicControllerSounds"
sfHolder.Parent=Svc.SoundService
local soundsFolder=sfHolder
local sound=nil
local reverb=Instance.new("ReverbSoundEffect")
reverb.Enabled=false
local distortion=Instance.new("DistortionSoundEffect")
distortion.Enabled=false
local equalizer=Instance.new("EqualizerSoundEffect")
equalizer.Enabled=false
local chorus=Instance.new("ChorusSoundEffect")
chorus.Enabled=false
local function safeReparentEffect(e,p,cn) local en=false
pcall(function() en=e.Enabled end)
local ok=pcall(function() e.Parent=p end)
if not ok then local f=Instance.new(cn)
f.Enabled=en
f.Parent=p
return f end
return e end
local function moveAudioEffects(t) reverb=safeReparentEffect(reverb,t,"ReverbSoundEffect")
distortion=safeReparentEffect(distortion,t,"DistortionSoundEffect")
equalizer=safeReparentEffect(equalizer,t,"EqualizerSoundEffect")
chorus=safeReparentEffect(chorus,t,"ChorusSoundEffect") end
local function loadAllMusicTracks(isRefresh)
	local mp3s=scanMusicDirectory()
	if isRefresh then
		local sid={}
for i=#Dat.trackList,1,-1 do if Dat.trackList[i].Type=="soundid" then table.insert(sid,1,{track=Dat.trackList[i],sound=Dat.createdSounds[i]}) end end
		local osp={}
for i=1,#Dat.createdSounds do local cs=Dat.createdSounds[i]
if cs and Dat.trackList[i] and Dat.trackList[i].Path then osp[Dat.trackList[i].Path]=cs end end
		Dat.createdSounds={}
Dat.trackList={}
		for i,fi in ipairs(mp3s) do
			Dat.trackList[i]={Path=fi.Path,DisplayName=fi.Name,FullName=fi.Name,FileName=fi.FileName,Type="mp3"}
local s=nil
			if osp[fi.Path] then s=osp[fi.Path]
osp[fi.Path]=nil
if s.Parent~=soundsFolder then s.Parent=soundsFolder end
s.Volume=St.currentVolume
s.PlaybackSpeed=St.currentSpeed
s.Looped=false
Dat.createdSounds[i]=s
			else local ns=Instance.new("Sound")
ns.Name=fi.Name
local ok,au=pcall(function() return getcustomasset(fi.Path,true) end)
if ok and au then ns.SoundId=au
ns.Volume=St.currentVolume
ns.PlaybackSpeed=St.currentSpeed
ns.Looped=false
ns.Parent=soundsFolder
Dat.createdSounds[i]=ns
s=ns else warn("[MC] Failed: "..fi.Name)
ns:Destroy() end end
			if s and s.SetAttribute then pcall(function() s:SetAttribute("Path",fi.Path) end) end
		end
		for _,lo in pairs(osp) do if lo and lo.Parent==soundsFolder then pcall(function() lo:Destroy() end) end end
		for _,d in ipairs(sid) do table.insert(Dat.trackList,d.track)
table.insert(Dat.createdSounds,d.sound) end
	else
		for i,fi in ipairs(mp3s) do
			Dat.trackList[i]={Path=fi.Path,DisplayName=fi.Name,FullName=fi.Name,FileName=fi.FileName,Type="mp3"}
			local s=Instance.new("Sound")
s.Name=fi.Name
local ok,au=pcall(function() return getcustomasset(fi.Path,true) end)
			if ok and au then s.SoundId=au
s.Volume=St.currentVolume
s.PlaybackSpeed=St.currentSpeed
s.Looped=false
s.Parent=soundsFolder
Dat.createdSounds[i]=s else warn("[MC] Failed: "..fi.Name)
s:Destroy() end
		end
	end
	Dat.lastMp3Files=mp3s
return #Dat.createdSounds>0
end
local function saveSoundIdTracks()
	if not isfolder(Cfg.configsPath) then makefolder(Cfg.configsPath) end
	local d={}
for _,t in ipairs(Dat.trackList) do if t.Type=="soundid" then table.insert(d,{SoundId=t.SoundId,Name=t.DisplayName}) end end
	pcall(function() writefile(Cfg.soundIdsPath,Svc.HttpService:JSONEncode(d)) end)
end
local function loadSoundIdTracks()
	if not isfile(Cfg.soundIdsPath) then safeCall(function() writefile(Cfg.soundIdsPath,"[]") end, "writefile")
	else
		local ok,r=pcall(function() return Svc.HttpService:JSONDecode(readfile(Cfg.soundIdsPath)) end)
		if ok and r and type(r)=="table" then
			local seen,ded={},{}
			for _,e in ipairs(r) do local id=tostring(e.SoundId or "")
if id~="" and not seen[id] then seen[id]=true
table.insert(ded,e) end end
			for _,e in ipairs(ded) do
				if e.SoundId and e.Name then
					local ns=Instance.new("Sound")
ns.Name=e.Name
ns.SoundId="rbxassetid://"..tostring(e.SoundId)
ns.Volume=St.currentVolume
ns.PlaybackSpeed=St.currentSpeed
ns.Looped=false
ns.Parent=soundsFolder
					table.insert(Dat.createdSounds,ns)
table.insert(Dat.trackList,{DisplayName=e.Name,FullName=e.Name,Type="soundid",SoundId=e.SoundId})
				end
			end
		end
	end
	local sic=nil
for _,cat in ipairs(Dat.categories) do if cat.CategoryID==Cfg.SOUND_ID_CATEGORY_ID then sic=cat
break end end
	if not sic then sic={Name=Cfg.SOUND_ID_CATEGORY_NAME,Tracks={},TrackTIDs={},CategoryID=Cfg.SOUND_ID_CATEGORY_ID}
table.insert(Dat.categories,sic) end
	if not sic.TrackTIDs then sic.TrackTIDs={} end
	sic.TrackTIDs={}
for _,t in ipairs(Dat.trackList) do if t.Type=="soundid" then table.insert(sic.TrackTIDs,getTrackId(t)) end end
	saveCategoriesToDisk()
end
loadAllMusicTracks(false)
loadSoundIdTracks()
rebuildCategoryTrackIndices()
saveCategoriesToDisk()
sound=Dat.createdSounds[St.currentTrackIndex]
if sound then moveAudioEffects(sound) end
local guardConns={}
local function attachVolumeGuard(s)
	if not s or not s:IsA("Sound") then return end
	if guardConns[s] then for _,c in ipairs(guardConns[s]) do pcall(function() c:Disconnect() end) end end
	local conns={}
	table.insert(conns,s:GetPropertyChangedSignal("Volume"):Connect(function()
		if s~=sound or St.isPaused then return end;if Dat.crossfadingSounds[s] then return end
		local iv=St.currentVolume;if math.abs(s.Volume-iv)>0.05 then task.defer(function() if s==sound and not St.isPaused and not Dat.crossfadingSounds[s] then s.Volume=iv end end) end
	end))
	table.insert(conns,s:GetPropertyChangedSignal("PlaybackSpeed"):Connect(function()
		if s~=sound then return end;local iv=(St.currentSpeed<=0) and 0.01 or St.currentSpeed
		if math.abs(s.PlaybackSpeed-iv)>0.01 then task.defer(function() if s==sound then s.PlaybackSpeed=iv end end) end
	end))
	guardConns[s]=conns
end
for _,s in ipairs(Dat.createdSounds) do attachVolumeGuard(s) end
Dat.attachVolumeGuard=attachVolumeGuard
local refreshPlayButton
local rebuildTrackListUI
local showTrackNotification
Svc.Players.LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5);if not St.isPaused and sound and not sound.IsPlaying then pcall(function() sound:Play() end) end end)
local function stripQ(u) return u:match("([^?]+)") or u end
local function getSoundCloudClientId()
	local ok,html=pcall(function() return game:HttpGet("https://soundcloud.com") end)
if not ok or not html then return nil,"Cannot fetch soundcloud.com" end
	local scripts={}
for src in html:gmatch('<script[^>]+src="(https://a%-v2%.sndcdn%.com/assets/[^"]+%.js)"') do table.insert(scripts,src) end
	if #scripts==0 then return nil,"No JS bundles found" end
	for i=#scripts,1,-1 do
		local jok,js=pcall(function() return game:HttpGet(scripts[i]) end)
		if jok and js and #js>0 then
			for cid in js:gmatch('client_id%s*:%s*"([%w]+)"') do if #cid>=20 then return cid,nil end end
			for cid in js:gmatch('"client_id","([%w]+)"') do if #cid>=20 then return cid,nil end end
			for cid in js:gmatch('clientId%s*:%s*"([%w]+)"') do if #cid>=20 then return cid,nil end end
			for cid in js:gmatch('client_id%s*=%s*"([%w]+)"') do if #cid>=20 then return cid,nil end end
		end
task.wait(0.05)
	end
return nil,"client_id not found"
end
local function downloadSoundCloudTrack(rawUrl,cb)
	local turl=stripQ(rawUrl)
cb=cb or function() end
cb("Extracting client_id…")
	local cid,cerr=getSoundCloudClientId()
if not cid then return nil,"client_id error: "..(cerr or "?") end
	cb("Resolving metadata…")
	local ok1,rr=pcall(function() return request({Url="https://api-v2.soundcloud.com/resolve?url="..turl.."&client_id="..cid,Method="GET",Headers={["Accept"]="application/json"}}) end)
	if not ok1 or not rr or rr.StatusCode~=200 then return nil,"Resolve failed (HTTP "..(rr and tostring(rr.StatusCode) or "?")..")" end
	local ok2,td=pcall(function() return Svc.HttpService:JSONDecode(rr.Body) end)
if not ok2 or not td then return nil,"Cannot parse track data",nil end
	local policy=(td.policy or ""):upper()
	local isSnipped=policy=="SNIPPED" or (td.duration and td.full_duration and td.full_duration>0 and td.duration<td.full_duration and td.duration<=31000)
	if isSnipped then
		local fullSecs=td.full_duration and math.floor(td.full_duration/1000) or 0
		local fullFmt=fullSecs>0 and string.format(" (full song is %d:%02d)",math.floor(fullSecs/60),fullSecs%60) or ""
		return nil,"GO+ track — 30s preview only"..fullFmt,td.title
	end
	local scTitle=td.title or nil
local saurl=nil
	if td.media and td.media.transcodings then
		for _,t in ipairs(td.media.transcodings) do if t.format and t.format.protocol=="progressive" and (t.format.mime_type or ""):find("mpeg",1,true) then saurl=t.url
break end end
		if not saurl then for _,t in ipairs(td.media.transcodings) do if t.format and t.format.protocol=="progressive" then saurl=t.url
break end end end
	end
	if not saurl then return nil,"No progressive MP3 stream found" end
	cb("Getting CDN URL…")
	local ok3,sr=pcall(function() return request({Url=saurl.."?client_id="..cid,Method="GET",Headers={["Accept"]="application/json"}}) end)
	if not ok3 or not sr or sr.StatusCode~=200 then return nil,"Stream URL fetch failed" end
	local ok4,si=pcall(function() return Svc.HttpService:JSONDecode(sr.Body) end)
if not ok4 or not si or not si.url then return nil,"No CDN URL in response" end
	cb("Downloading audio…")
	local ok5,resp=pcall(function() return request({Url=si.url,Method="GET",Headers={["User-Agent"]="Mozilla/5.0",["Content-Type"]="application/octet-stream"}}) end)
	if not ok5 or not resp then return nil,"Download request failed" end
	local status=resp.StatusCode or resp.status or 0
local audioData=resp.Body or resp.body or ""
	if status~=200 and status~=206 then return nil,"CDN returned HTTP "..tostring(status) end
	if #audioData<1000 then return nil,"File too small — likely an error page" end
	cb(string.format("%.1f",#audioData/1048576).."MB downloaded ✓")
return audioData,nil,scTitle
end
local function parseLrcLyrics(lrc)
	local lines={}
	for line in (lrc or ""):gmatch("[^\n\r]+") do
		local m,s,rest=line:match("%[(%d+):([%d%.]+)%](.*)")
		if m and s then
			local lt=tonumber(m)*60+tonumber(s)
			if rest and rest:find("<%d+:[%d%.]+>") then
				local wl={}
for wm,ws,wt in rest:gmatch("<(%d+):([%d%.]+)>([^<]*)") do local wc=wt:match("^%s*(.-)%s*$") or ""
if wc~="" then table.insert(wl,{text=wc,time=tonumber(wm)*60+tonumber(ws)}) end end
				if #wl>0 then local p={}
for _,w in ipairs(wl) do table.insert(p,w.text) end
table.insert(lines,{time=lt,text=table.concat(p," "),words=wl}) end
			else local cl=rest and rest:match("^%s*(.-)%s*$") or ""
if cl~="" and not cl:match("^%[") then table.insert(lines,{time=lt,text=cl}) end end
		end
	end
table.sort(lines,function(a,b) return a.time<b.time end)
return lines
end
local lyricsOverlay=nil
local eolTitleTween=nil
local function clearCurrentLyrics()
	Dat.currentLyrics={}
Dat.lastLyricIndex=-1
Dat.eolFired=false
Dat.detectedLyricsTitle=nil
Dat.translateCache={}
	if lyricsOverlay then
		lyricsOverlay.prev.Active=true
lyricsOverlay.current.Active=true
lyricsOverlay.next.Active=true
		lyricsOverlay.prev.Text=""
lyricsOverlay.prev.TextTransparency=0.35
		lyricsOverlay.current.Text=""
lyricsOverlay.current.TextTransparency=0
lyricsOverlay.current.Position=UDim2.new(0.5,0,0,34)
		lyricsOverlay.next.Text=""
lyricsOverlay.next.TextTransparency=0.35
lyricsOverlay.noResults.Text=""
		if lyricsOverlay.spinnerImg then lyricsOverlay.spinnerImg.Visible=false end
		if lyricsOverlay.displayedIndices then lyricsOverlay.displayedIndices.prev=0
lyricsOverlay.displayedIndices.cur=0
lyricsOverlay.displayedIndices.next=0 end
		if eolTitleTween then eolTitleTween:Cancel()
eolTitleTween=nil end
		if lyricsOverlay.eolTitle then lyricsOverlay.eolTitle.Text=""
lyricsOverlay.eolTitle.TextTransparency=1
lyricsOverlay.eolTitle.Position=UDim2.new(0.5,0,0.5,0) end
		lyricsOverlay.underline.Position=UDim2.new(0.5,0,0,76)
Svc.TweenService:Create(lyricsOverlay.underline,TweenInfo.new(0.2),{Size=UDim2.new(0,0,0,2)}):Play()
	end
	if St.cinematicMode and _cinGui then
		for _,ch in ipairs(_cinGui:GetChildren()) do if ch:IsA("TextLabel") then pcall(function() ch:Destroy() end) end end
		local topBar=_cinGui:FindFirstChild("TopCinBar")
local botBar=_cinGui:FindFirstChild("BotCinBar")
		if topBar and topBar.Position.Y.Scale>=0 then
			local retractTI=TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
			Svc.TweenService:Create(topBar,retractTI,{Position=UDim2.new(0,0,-0.14,0)}):Play()
			if botBar then Svc.TweenService:Create(botBar,retractTI,{Position=UDim2.new(0,0,1.14,0)}):Play() end
		end
	end
end
local function httpGet(url)
	local ok,r
ok,r=pcall(function() return request({Url=url,Method="GET",Headers={["Accept"]="application/json",["User-Agent"]="Mozilla/5.0"}}) end)
	if ok and r and(r.StatusCode==200 or r.status==200) then return r.Body or r.body end
	ok,r=pcall(function() return game:HttpGet(url) end)
if ok and r and #r>10 then return r end
	ok,r=pcall(function() return game:GetService("HttpService"):GetAsync(url,true) end)
if ok and r and #r>10 then return r end
end
local function httpPost(url,body)
	local ok,r
ok,r=pcall(function() return request({Url=url,Method="POST",Headers={["Content-Type"]="application/x-www-form-urlencoded",["User-Agent"]="Mozilla/5.0"},Body=body}) end)
	if ok and r and(r.StatusCode==200 or r.status==200) then return r.Body or r.body end
	ok,r=pcall(function() return syn and syn.request({Url=url,Method="POST",Headers={["Content-Type"]="application/x-www-form-urlencoded"},Body=body}) end)
	if ok and r and(r.StatusCode==200 or r.status==200) then return r.Body or r.body end
end
local function base64Encode(data)
	local ok,res
ok,res=pcall(function() return syn.crypt.base64.encode(data) end)
if ok and res and #res>0 then return res end
	ok,res=pcall(function() return crypt.base64encode(data) end)
if ok and res and #res>0 then return res end
	ok,res=pcall(function() return crypt.base64.encode(data) end)
if ok and res and #res>0 then return res end
	local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local out={}
local i=1
while i<=#data do
		local b1=data:byte(i)
local b2=(i+1<=#data) and data:byte(i+1) or 0
local b3=(i+2<=#data) and data:byte(i+2) or 0
local v=b1*65536+b2*256+b3
		out[#out+1]=chars:sub(math.floor(v/262144)%64+1,math.floor(v/262144)%64+1)
out[#out+1]=chars:sub(math.floor(v/4096)%64+1,math.floor(v/4096)%64+1)
		out[#out+1]=(i+1>#data) and "=" or chars:sub(math.floor(v/64)%64+1,math.floor(v/64)%64+1)
out[#out+1]=(i+2>#data) and "=" or chars:sub(v%64+1,v%64+1)
i=i+3
	end
return table.concat(out)
end
local function cleanTrackName(s)
	s=s:gsub("%s*%(feat%.?[^%)]*%)",""):gsub("%s*%(ft%.?[^%)]*%)",""):gsub("%[.-%]",""):gsub("%(Official.-%)", ""):gsub("%(Lyric.-%)", ""):gsub("%(Audio.-%)", ""):gsub("%(Music.-%)", "")
	s=s:gsub("%(Radio%s*Edit%)", ""):gsub("%(Extended.-%)", ""):gsub("%(Remix.-%)", ""):gsub("%(prod%.?.-%)", ""):gsub("%(Prod%.?.-%)", "")
	s=s:gsub("%s*feat%.?%s+[^%(]+",""):gsub("%s*ft%.?%s+[^%(]+",""):gsub("%s*&.+",""):gsub("%s*x%s+%u.+",""):gsub("_%d+$",""):gsub("%s+"," ")
	return s:match("^%s*(.-)%s*$")
end
local function urlEncode(s) return s:gsub("[^%w%.%- ]",function(c) return string.format("%%%02X",c:byte()) end):gsub(" ","+") end
local function translateLyricLine(text,cb)
	if not text or text=="" then cb(text)
return end
	local cached=Dat.translateCache[text]
if cached then cb(cached)
return end
	if Dat.translatePending[text] then
		table.insert(Dat.translatePending[text],cb)
return
	end
	Dat.translatePending[text]={cb}
	task.spawn(function()
		local encoded=text:gsub("([^%w%-_%.~])",function(c) return string.format("%%%02X",c:byte()) end)
		local url="https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q="..encoded
		local ok,resp=pcall(function() return request({Url=url,Method="GET",Headers={["Accept"]="application/json",["User-Agent"]="Mozilla/5.0"}}) end)
		local result=text
		if ok and resp and (resp.StatusCode==200 or (resp.StatusCode or 0)==0) then
			local pok,data=pcall(function() return Svc.HttpService:JSONDecode(resp.Body or resp.body or "") end)
			if pok and data and type(data)=="table" and data[1] and type(data[1])=="table" then
				local translated=""
				for _,part in ipairs(data[1]) do if type(part)=="table" and type(part[1])=="string" then translated=translated..part[1] end end
				if translated~="" then result=translated end
			end
		end
		Dat.translateCache[text]=result
		local waiters=Dat.translatePending[text] or {}
		Dat.translatePending[text]=nil
		for _,wcb in ipairs(waiters) do pcall(wcb,result) end
	end)
end
local function prefetchLyricTranslations(gen)
	if not St.translateEnabled then return end
	local lyr=Dat.currentLyrics
if #lyr==0 then return end
	task.spawn(function()
		for _,entry in ipairs(lyr) do
			if Dat.lyricsFetchGen~=gen then return end
			if not Dat.translateCache[entry.text] then
				translateLyricLine(entry.text,function() end)
			end
			task.wait()
		end
	end)
end
local function setLyricsStatusText(text)
	if not lyricsOverlay then return end
lyricsOverlay.noResults.Text=text
	if lyricsOverlay.spinnerImg then lyricsOverlay.spinnerImg.Visible=text~="" and(text:find("identifying",1,true) or text:find("searching",1,true)) and true or false end
	if St.cinematicMode and _cinGui then
		local noLyr=text:find("no lyrics",1,true) or text:find("instrumental",1,true) or text:find("Instrumental",1,true) or text:find("unsynced",1,true)
		local hasSynced=(text=="" and #Dat.currentLyrics>0)
		local sg=_cinGui
		local topBar=sg:FindFirstChild("TopCinBar")
local botBar=sg:FindFirstChild("BotCinBar")
		if noLyr then
			local exitTI=TweenInfo.new(1.0,Enum.EasingStyle.Sine,Enum.EasingDirection.In)
			if topBar and topBar.Position.Y.Scale>=0 then
				Svc.TweenService:Create(topBar,exitTI,{Position=UDim2.new(0,0,-0.14,0)}):Play()
				Svc.TweenService:Create(botBar,exitTI,{Position=UDim2.new(0,0,1.14,0)}):Play()
			end
		elseif hasSynced then
			local inTI=TweenInfo.new(0.9,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
			if topBar and topBar.Position.Y.Scale<0 then
				Svc.TweenService:Create(topBar,inTI,{Position=UDim2.new(0,0,0,0)}):Play()
				Svc.TweenService:Create(botBar,inTI,{Position=UDim2.new(0,0,1,0)}):Play()
			end
		end
	end
end
local function fetchLyricsForTrack(name,gen)
	task.spawn(function()
		if #name<=6 then if lyricsOverlay and St.lyricsEnabled then setLyricsStatusText("♪  no lyrics found") end;return end
		clearCurrentLyrics();if lyricsOverlay and St.lyricsEnabled then setLyricsStatusText("♪  searching…") end
		if flaggedInstrumental[name] then
			if lyricsOverlay and St.lyricsEnabled then lyricsOverlay.current.RichText=false;lyricsOverlay.current.Text="[ Instrumental ]";lyricsOverlay.current.TextTransparency=0;setLyricsStatusText("");if lyricsOverlay.refreshUnderline then lyricsOverlay.refreshUnderline() end end;return
		end
		local nameLow=name:lower()
		local isInstrumental=(
			nameLow=="teapot lms" or nameLow:find("instrumental") or nameLow:find("%f[%a]inst%.?%f[%A]") or
			nameLow:find("no vocals?") or nameLow:find("no lyrics") or
			nameLow:find("%f[%a]bgm%f[%A]") or nameLow:find("background music") or
			nameLow:find("%f[%a]ost%f[%A]") or nameLow:find("original soundtrack") or
			nameLow:find("music only") or nameLow:find("karaoke") or
			nameLow:find("backing track") or nameLow:find("without vocals?") or
			nameLow:find("piano ver") or nameLow:find("piano version") or
			nameLow:find("acoustic ver") or nameLow:find("acoustic version") or
			nameLow:find("orchestral") or nameLow:find("strings ver") or
			nameLow:find("beat only") or nameLow:find("melody only")
		) and true or false
		if isInstrumental then
			if lyricsOverlay and St.lyricsEnabled then
				lyricsOverlay.current.RichText=false
				lyricsOverlay.current.Text="[ Instrumental ]"
				lyricsOverlay.current.TextTransparency=0
				setLyricsStatusText("")
				if lyricsOverlay.refreshUnderline then lyricsOverlay.refreshUnderline() end
			end;return
		end
		local function tryLrclib(artist,title)
			if not title or title=="" then return nil end;local lurls={}
			if artist and artist~="" then table.insert(lurls,"https://lrclib.net/api/get?track_name="..urlEncode(title).."&artist_name="..urlEncode(artist).."&album_name=");table.insert(lurls,"https://lrclib.net/api/search?track_name="..urlEncode(title).."&artist_name="..urlEncode(artist));table.insert(lurls,"https://lrclib.net/api/search?q="..urlEncode(title.." "..artist)) end
			table.insert(lurls,"https://lrclib.net/api/search?q="..urlEncode(title))
			for _,url in ipairs(lurls) do
				if Dat.lyricsFetchGen~=gen then return nil end
				local raw=httpGet(url)
				if raw and #raw>10 and(raw:sub(1,1)=="[" or raw:sub(1,1)=="{") then
					local ok,p=pcall(function() return Svc.HttpService:JSONDecode(raw) end)
					if ok and p then
						local res=type(p)=="table" and(p[1]~=nil and p or{p}) or{}
						for _,e in ipairs(res) do
							if e.instrumental==true then
								return "INSTRUMENTAL"
							end
							if e.syncedLyrics and e.syncedLyrics~="" then local lrc=parseLrcLyrics(e.syncedLyrics);if #lrc>0 then return lrc end end
						end
					end
				end;task.wait(0.06)
			end;return nil
		end
		local sA,sT;do local a,t=name:match("^(.-)%s*[%-%–—]%s*(.+)$");if t and t~="" then sA=cleanTrackName(a);sT=cleanTrackName(t) else sT=cleanTrackName(name);sA=nil end end
		local result={lrc=nil,plain=nil,fpArtist=nil,fpTitle=nil,done=false}
		task.spawn(function() local lrc=tryLrclib(sA,sT);if Dat.lyricsFetchGen~=gen then return end;if lrc=="INSTRUMENTAL" then result.done=true;result.lrc="INSTRUMENTAL" elseif lrc and not result.done then result.lrc=lrc;result.done=true end end)
		local ti=Dat.trackList[St.currentTrackIndex]
		if ti and ti.Type=="mp3" and ti.Path then
			task.spawn(function()
				local w=0;while w<8 do if Dat.lyricsFetchGen~=gen then return end;local s=sound;if s and s.TimeLength and s.TimeLength>1 then break end;task.wait(0.25);w=w+0.25 end
				if Dat.lyricsFetchGen~=gen then return end
				local dur=(sound and sound.TimeLength and sound.TimeLength>1) and sound.TimeLength or 0
				local ff=nil;pcall(function() ff=readfile(ti.Path) end);if not ff or #ff<10000 or dur<5 then return end
				local bps=#ff/dur;local passes={math.max(15,math.min(dur*0.30,90)),math.max(30,math.min(dur*0.55,150)),math.max(10,math.min(dur*0.15,50)),math.max(50,math.min(dur*0.75,200))}
				for _,sk in ipairs(passes) do
					if Dat.lyricsFetchGen~=gen or result.done then break end
					local skipB=math.max(0,math.min(math.floor(sk*bps),#ff-math.min(math.floor(25*bps),200000)-1));local capB=math.min(math.floor(25*bps),200000);local chunk=ff:sub(skipB+1,skipB+capB)
					if #chunk<4000 then continue end;local b64=base64Encode(chunk);if not b64 or #b64==0 then continue end
					local raw=httpPost("https://api.audd.io/","api_token=&return=lyrics&audio="..b64:gsub("+","%%2B"):gsub("/","%%2F"):gsub("=","%%3D"))
					if Dat.lyricsFetchGen~=gen then break end
					if raw and #raw>10 and raw:sub(1,1)=="{" then
						local ok,d=pcall(function() return Svc.HttpService:JSONDecode(raw) end)
						if ok and d and d.status=="success" and d.result then
							local ra,rt=d.result.artist,d.result.title;local lf=d.result.lyrics;local rp=nil
							if type(lf)=="table" then rp=lf.lyrics elseif type(lf)=="string" and lf~="" then rp=lf end
							if rt and rt~="" then result.fpArtist=ra;result.fpTitle=rt;if rp and rp~="" then result.plain=rp end;local fpLrc=tryLrclib(ra,rt);if fpLrc=="INSTRUMENTAL" then result.lrc="INSTRUMENTAL";result.done=true elseif fpLrc and not result.done then result.lrc=fpLrc;result.done=true end;break end
						end
					end;task.wait(0.6)
				end;ff=nil
			end)
		end
		local waited=0;while not result.done and waited<12 do if Dat.lyricsFetchGen~=gen then return end;task.wait(0.15);waited=waited+0.15 end
		if Dat.lyricsFetchGen~=gen then return end
		if result.lrc=="INSTRUMENTAL" then
			if lyricsOverlay and St.lyricsEnabled then
				lyricsOverlay.current.RichText=false;lyricsOverlay.current.Text="[ Instrumental ]"
				lyricsOverlay.current.TextTransparency=0;setLyricsStatusText("")
				if lyricsOverlay.refreshUnderline then lyricsOverlay.refreshUnderline() end
			end;return
		end
		if result.lrc then Dat.currentLyrics=result.lrc;if result.fpTitle and result.fpTitle~="" then Dat.detectedLyricsTitle=(result.fpArtist and result.fpArtist~="" and (result.fpArtist.." - ") or "")..result.fpTitle elseif result.fpTitle=="" or not result.fpTitle then Dat.detectedLyricsTitle=nil end;if lyricsOverlay then setLyricsStatusText("") end;prefetchLyricTranslations(gen);return end
		local pl=result.plain
		if not pl or pl=="" then
			local aus={};if sA and sT then table.insert(aus,"https://api.audd.io/findLyrics/?q="..urlEncode(sA.." "..sT)) end;if sT then table.insert(aus,"https://api.audd.io/findLyrics/?q="..urlEncode(sT)) end;if result.fpArtist and result.fpTitle then table.insert(aus,"https://api.audd.io/findLyrics/?q="..urlEncode(result.fpArtist.." "..result.fpTitle)) end
			for _,url in ipairs(aus) do if Dat.lyricsFetchGen~=gen then return end;local raw=httpGet(url);if raw and #raw>10 and raw:sub(1,1)=="{" then local ok,d=pcall(function() return Svc.HttpService:JSONDecode(raw) end);if ok and d and d.status=="success" and type(d.result)=="table" and #d.result>0 then local h=d.result[1];if h.lyrics and h.lyrics~="" then pl=h.lyrics;break end end end;task.wait(0.07) end
		end
		if Dat.lyricsFetchGen~=gen then return end
		if pl and pl~="" then
			local ls={};for line in pl:gmatch("[^\n\r]+") do local tr=line:match("^%s*(.-)%s*$");if tr~="" then table.insert(ls,tr) end end
			if #ls>0 then if sound and sound.TimeLength and sound.TimeLength>0 then local sp=sound.TimeLength/(#ls+1);local td2={};for i,ln in ipairs(ls) do table.insert(td2,{time=sp*i,text=ln}) end;Dat.currentLyrics=td2;if lyricsOverlay then setLyricsStatusText("") end;prefetchLyricTranslations(gen) else if lyricsOverlay and St.lyricsEnabled then lyricsOverlay.current.Text=ls[1] or "";setLyricsStatusText("♪  unsynced") end end
			else if lyricsOverlay and St.lyricsEnabled then setLyricsStatusText("♪  no lyrics found") end end
		else if lyricsOverlay and St.lyricsEnabled then setLyricsStatusText("♪  no lyrics found") end end
	end)
end
local function animateLyricsTransition(pt,nt,pi,ci,ni)
	if not lyricsOverlay then return end
	if lyricsOverlay.displayedIndices then lyricsOverlay.displayedIndices.prev=pi or 0
lyricsOverlay.displayedIndices.cur=ci or 0
lyricsOverlay.displayedIndices.next=ni or 0 end
	Svc.TweenService:Create(lyricsOverlay.prev,TweenInfo.new(0.10,Enum.EasingStyle.Linear),{TextTransparency=1}):Play()
Svc.TweenService:Create(lyricsOverlay.next,TweenInfo.new(0.10,Enum.EasingStyle.Linear),{TextTransparency=1}):Play()
	task.delay(0.12,function()
		lyricsOverlay.prev.Text=pt;lyricsOverlay.next.Text=nt
		Svc.TweenService:Create(lyricsOverlay.prev,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0.35}):Play();Svc.TweenService:Create(lyricsOverlay.next,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0.35}):Play()
		if lyricsOverlay.refreshUnderline then lyricsOverlay.refreshUnderline() end
	end)
end
local function applyCornerRadius(r,p) local c=Instance.new("UICorner")
c.CornerRadius=UDim.new(0,r)
c.Parent=p end
local function applyStroke(t,col,tr,p) local s=Instance.new("UIStroke")
s.Thickness=t
s.Color=col
s.Transparency=tr
s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
s.Parent=p
return s end
UI.gui=Instance.new("ScreenGui")
UI.gui.Name="MusicControllerGui"
UI.gui.ResetOnSpawn=false
UI.gui.IgnoreGuiInset=true
UI.gui.ZIndexBehavior=Enum.ZIndexBehavior.Global
UI.gui.Parent=pGui
UI.main=Instance.new("Frame")
UI.main.Name="Main"
UI.main.AnchorPoint=Vector2.new(0.5,0.5)
do
	local vp = getViewport()
	if isMobileLayout() then
		-- On narrow screens fill most of the viewport width
		local mobileW = math.min(Cfg.CARD_WIDTH, vp.X - 16)
		UI.main.Size = UDim2.new(0, mobileW, 0, Cfg.BASE_HEIGHT)
	else
		UI.main.Size = UDim2.new(0, Cfg.CARD_WIDTH, 0, Cfg.BASE_HEIGHT)
	end
end
UI.main.Position=UDim2.new(0.5,0,0.5,0)
UI.main.BackgroundColor3=C.BG
UI.main.BackgroundTransparency=0
UI.main.BorderSizePixel=0
UI.main.Visible=true
UI.main.ZIndex=3
UI.main.Parent=UI.gui
applyCornerRadius(16,UI.main)
applyStroke(1,C.BORDER_LIT,0.25,UI.main)
local mg=Instance.new("UIGradient")
mg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(32,26,12)),ColorSequenceKeypoint.new(0.48,Color3.fromRGB(10,8,4)),ColorSequenceKeypoint.new(1,Color3.fromRGB(2,1,0))})
mg.Rotation=135
mg.Parent=UI.main
UI.uiScale=Instance.new("UIScale")
UI.uiScale.Scale = computeUiScale()
UI.uiScale.Parent=UI.main
local function syncShadow() end
syncShadow()
UI.main:GetPropertyChangedSignal("Position"):Connect(syncShadow)
UI.main:GetPropertyChangedSignal("Size"):Connect(syncShadow)
do
	local lg=Instance.new("ScreenGui")
lg.Name="MusicLyricsGui"
lg.ResetOnSpawn=false
lg.IgnoreGuiInset=true
lg.ZIndexBehavior=Enum.ZIndexBehavior.Global
lg.DisplayOrder=2147483647
lg.Parent=pGui
lg.Enabled=false
	local fr=Instance.new("Frame")
fr.AnchorPoint=Vector2.new(0.5,1)
fr.Position=UDim2.new(0.5,0,0.87,0)
fr.Size=UDim2.new(0.96, 0, 0, 120)  -- responsive width
fr.BackgroundTransparency=1
fr.ZIndex=200
fr.Visible=true
fr.Parent=lg
	local pill=Instance.new("Frame")
pill.AnchorPoint=Vector2.new(0.5,0.5)
pill.Position=UDim2.new(0.5,0,0.5,0)
pill.Size=UDim2.new(1,-16,1,0)
pill.BackgroundColor3=C.BG
pill.BackgroundTransparency=0
pill.BorderSizePixel=0
pill.ClipsDescendants=true
pill.ZIndex=200
pill.Parent=fr
applyCornerRadius(28,pill)
applyStroke(1,C.BORDER_LIT,0.25,pill)
	local pg=Instance.new("UIGradient")
pg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C.ELEVATED),ColorSequenceKeypoint.new(1,C.BG)})
pg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,0)})
pg.Rotation=135
pg.Parent=pill
	local function createLyricsLabel(nm,yp,sz,fs,bold) local b=Instance.new("TextButton")
b.Name=nm
b.AnchorPoint=Vector2.new(0.5,0)
b.Position=UDim2.new(0.5,0,0,yp)
b.Size=UDim2.new(sz,0,0,bold and 40 or(nm=="LyricsPrev" and 24 or 22))
b.BackgroundTransparency=1
b.AutoButtonColor=false
b.Font=bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
b.Text=""
b.RichText=bold
b.TextColor3=bold and C.TEXT or C.TEXT2
b.TextTransparency=bold and 0 or 0.35
b.ZIndex=202
b.Parent=pill
if bold then b.TextScaled=true
local tc=Instance.new("UITextSizeConstraint")
tc.MinTextSize=14
tc.MaxTextSize=fs
tc.Parent=b else b.TextSize=fs
b.TextTruncate=Enum.TextTruncate.AtEnd end
return b end
	local prevBtn=createLyricsLabel("LyricsPrev",6,0.92,15,false)
local curBtn=createLyricsLabel("LyricsCurrent",34,0.95,26,true)
	local ul=Instance.new("Frame")
ul.AnchorPoint=Vector2.new(0.5,0)
ul.Position=UDim2.new(0.5,0,0,76)
ul.Size=UDim2.new(0,0,0,2)
ul.BackgroundColor3=C.ACCENT
ul.BackgroundTransparency=0
ul.BorderSizePixel=0
ul.ZIndex=203
ul.Parent=pill
applyCornerRadius(999,ul)
	local ulFL=Instance.new("Frame")
ulFL.Name="FadeL"
ulFL.AnchorPoint=Vector2.new(0,0.5)
ulFL.Position=UDim2.new(0,0,0.5,0)
ulFL.Size=UDim2.new(0.25,0,3,0)
ulFL.BackgroundColor3=C.BG
ulFL.BackgroundTransparency=0
ulFL.BorderSizePixel=0
ulFL.ZIndex=205
ulFL.Parent=ul
local ulFLG=Instance.new("UIGradient")
ulFLG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
ulFLG.Rotation=0
ulFLG.Parent=ulFL
	local ulFR=Instance.new("Frame")
ulFR.Name="FadeR"
ulFR.AnchorPoint=Vector2.new(1,0.5)
ulFR.Position=UDim2.new(1,0,0.5,0)
ulFR.Size=UDim2.new(0.25,0,3,0)
ulFR.BackgroundColor3=C.BG
ulFR.BackgroundTransparency=0
ulFR.BorderSizePixel=0
ulFR.ZIndex=205
ulFR.Parent=ul
local ulFRG=Instance.new("UIGradient")
ulFRG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
ulFRG.Rotation=0
ulFRG.Parent=ulFR
	local nextBtn=createLyricsLabel("LyricsNext",82,0.92,15,false)
	local noRes=Instance.new("TextLabel")
noRes.AnchorPoint=Vector2.new(0.5,0.5)
noRes.Position=UDim2.new(0.5,0,0.46,0)
noRes.Size=UDim2.new(0.92,0,0,20)
noRes.BackgroundTransparency=1
noRes.Font=Enum.Font.GothamMedium
noRes.Text=""
noRes.TextColor3=C.TEXT3
noRes.TextSize=13
noRes.ZIndex=203
noRes.Parent=pill
	local spn=Instance.new("ImageLabel")
spn.AnchorPoint=Vector2.new(0.5,0)
spn.Position=UDim2.new(0.5,0,0.62,0)
spn.Size=UDim2.new(0,32,0,32)
spn.BackgroundTransparency=1
spn.Image="rbxassetid://119441213053262"
spn.ZIndex=204
spn.Visible=false
spn.Parent=pill
	local di={prev=0,cur=0,next=0}
	local eolTitle=Instance.new("TextLabel")
eolTitle.Name="EOLTitle"
eolTitle.AnchorPoint=Vector2.new(0.5,0.5)
eolTitle.Position=UDim2.new(0.5,0,0.5,0)
eolTitle.Size=UDim2.new(0.92,0,0,36)
eolTitle.BackgroundTransparency=1
eolTitle.Font=Enum.Font.GothamBold
eolTitle.Text=""
eolTitle.TextColor3=Color3.fromRGB(90,68,22)
eolTitle.TextSize=20
eolTitle.TextScaled=true
eolTitle.TextTransparency=1
eolTitle.ZIndex=204
eolTitle.Parent=pill
	local eolTitleTC=Instance.new("UITextSizeConstraint")
eolTitleTC.MinTextSize=12
eolTitleTC.MaxTextSize=20
eolTitleTC.Parent=eolTitle
	local function seekLI(idx) if Dat.eolFired then return end
if idx<1 or idx>#Dat.currentLyrics then return end
local s=sound
if not s or not s.TimeLength or s.TimeLength<=0 then return end
pcall(function() s.TimePosition=math.max(0,math.min(Dat.currentLyrics[idx].time,s.TimeLength-0.05)) end) end
	prevBtn.MouseButton1Click:Connect(function() seekLI(di.prev) end)
curBtn.MouseButton1Click:Connect(function() seekLI(di.cur) end)
nextBtn.MouseButton1Click:Connect(function() seekLI(di.next) end)
	prevBtn.MouseEnter:Connect(function() if not Dat.eolFired then prevBtn.TextTransparency=0.10 end end)
prevBtn.MouseLeave:Connect(function() prevBtn.TextTransparency=Dat.eolFired and 1 or 0.35 end)
	curBtn.MouseEnter:Connect(function() if not Dat.eolFired then Svc.TweenService:Create(curBtn,TweenInfo.new(0.12),{TextColor3=C.ACCENT}):Play() end end)
curBtn.MouseLeave:Connect(function() if not Dat.eolFired then Svc.TweenService:Create(curBtn,TweenInfo.new(0.12),{TextColor3=C.TEXT}):Play() end end)
	nextBtn.MouseEnter:Connect(function() if not Dat.eolFired then nextBtn.TextTransparency=0.10 end end)
nextBtn.MouseLeave:Connect(function() nextBtn.TextTransparency=Dat.eolFired and 1 or 0.35 end)
	local translatePillBtn=Instance.new("ImageButton")
translatePillBtn.Name="TranslateBtn"
translatePillBtn.AnchorPoint=Vector2.new(1,0)
translatePillBtn.Position=UDim2.new(1,-34,0,8)
translatePillBtn.Size=UDim2.new(0,22,0,22)
translatePillBtn.BackgroundTransparency=1
translatePillBtn.Image="rbxassetid://123128329656137"
translatePillBtn.ImageColor3=C.TEXT2
translatePillBtn.ZIndex=210
translatePillBtn.Visible=true
translatePillBtn.Parent=pill
	local flagBtn=Instance.new("ImageButton")
flagBtn.Name="FlagBtn"
flagBtn.AnchorPoint=Vector2.new(1,0)
flagBtn.Position=UDim2.new(1,-8,0,8)
flagBtn.Size=UDim2.new(0,22,0,22)
flagBtn.BackgroundTransparency=1
flagBtn.Image="rbxassetid://11379131842"
flagBtn.ImageColor3=C.TEXT2
flagBtn.ZIndex=210
flagBtn.Visible=true
flagBtn.Parent=pill
	local flagTooltip=Instance.new("Frame")
flagTooltip.AnchorPoint=Vector2.new(0,1)
flagTooltip.Size=UDim2.new(0,0,0,22)
flagTooltip.AutomaticSize=Enum.AutomaticSize.X
flagTooltip.BackgroundColor3=C.ELEVATED
flagTooltip.BorderSizePixel=0
flagTooltip.Visible=false
flagTooltip.ZIndex=215
flagTooltip.Parent=lg
applyCornerRadius(6,flagTooltip)
	do local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,8)
p.PaddingRight=UDim.new(0,8)
p.Parent=flagTooltip end
	local flagTooltipLbl=Instance.new("TextLabel")
flagTooltipLbl.Size=UDim2.new(0,0,1,0)
flagTooltipLbl.AutomaticSize=Enum.AutomaticSize.X
flagTooltipLbl.BackgroundTransparency=1
flagTooltipLbl.Font=Enum.Font.GothamMedium
flagTooltipLbl.Text="flag as instrumental"
flagTooltipLbl.TextColor3=C.TEXT
flagTooltipLbl.TextSize=11
flagTooltipLbl.ZIndex=216
flagTooltipLbl.Parent=flagTooltip
	local function updateFlagBtn(active)
		Svc.TweenService:Create(flagBtn,TweenInfo.new(0.15),{ImageColor3=active and C.ACCENT or C.TEXT2}):Play()
		flagTooltipLbl.Text=active and "unflag instrumental" or "flag as instrumental"
	end
	flagBtn.MouseEnter:Connect(function()
		local mp=Svc.UserInput:GetMouseLocation()
		flagTooltip.Position=UDim2.fromOffset(mp.X+14,mp.Y-6)
		flagTooltip.Visible=true
	end)
	flagBtn.MouseLeave:Connect(function() flagTooltip.Visible=false end)
	Svc.UserInput.InputChanged:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseMovement and flagTooltip.Visible then
			local mp=Svc.UserInput:GetMouseLocation()
			flagTooltip.Position=UDim2.fromOffset(mp.X+14,mp.Y-6)
		end
	end)
	local function refTranslatePillBtn()
		Svc.TweenService:Create(translatePillBtn,TweenInfo.new(0.15),{ImageColor3=St.translateEnabled and C.ACCENT or C.TEXT2}):Play()
	end
	refTranslatePillBtn()
	local trTooltip=Instance.new("Frame")
trTooltip.AnchorPoint=Vector2.new(0,1)
trTooltip.Size=UDim2.new(0,0,0,22)
trTooltip.AutomaticSize=Enum.AutomaticSize.X
trTooltip.BackgroundColor3=C.ELEVATED
trTooltip.BorderSizePixel=0
trTooltip.Visible=false
trTooltip.ZIndex=215
trTooltip.Parent=lg
applyCornerRadius(6,trTooltip)
	do local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,8)
p.PaddingRight=UDim.new(0,8)
p.Parent=trTooltip end
	local trTooltipLbl=Instance.new("TextLabel")
trTooltipLbl.Size=UDim2.new(0,0,1,0)
trTooltipLbl.AutomaticSize=Enum.AutomaticSize.X
trTooltipLbl.BackgroundTransparency=1
trTooltipLbl.Font=Enum.Font.GothamMedium
trTooltipLbl.Text="translate lyrics"
trTooltipLbl.TextColor3=C.TEXT
trTooltipLbl.TextSize=11
trTooltipLbl.ZIndex=216
trTooltipLbl.Parent=trTooltip
	translatePillBtn.MouseEnter:Connect(function() trTooltipLbl.Text=St.translateEnabled and "disable translate" or "translate lyrics";local mp=Svc.UserInput:GetMouseLocation();trTooltip.Position=UDim2.fromOffset(mp.X+14,mp.Y-6);trTooltip.Visible=true end)
	translatePillBtn.MouseLeave:Connect(function() trTooltip.Visible=false end)
	Svc.UserInput.InputChanged:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseMovement and trTooltip.Visible then local mp=Svc.UserInput:GetMouseLocation();trTooltip.Position=UDim2.fromOffset(mp.X+14,mp.Y-6) end end)
	translatePillBtn.MouseButton1Click:Connect(function()
		St.translateEnabled=not St.translateEnabled;refTranslatePillBtn();saveUserSettings()
		Dat.translateCache={};Dat.translatePending={};Dat.lastLyricIndex=-1
		if St.translateEnabled then prefetchLyricTranslations(Dat.lyricsFetchGen) end
	end)
	_G.__MCRefTranslatePill=refTranslatePillBtn
	flagBtn.MouseButton1Click:Connect(function()
		local inf=Dat.trackList[St.currentTrackIndex];if not inf then return end
		local nm=inf.DisplayName
		if flaggedInstrumental[nm] then
			flaggedInstrumental[nm]=nil;saveFlaggedInstrumentals();updateFlagBtn(false)
			Dat.lyricsFetchGen=Dat.lyricsFetchGen+1;fetchLyricsForTrack(nm,Dat.lyricsFetchGen)
			showTrackNotification("unflagged: "..nm,false)
		else
			flaggedInstrumental[nm]=true;saveFlaggedInstrumentals();updateFlagBtn(true)
			Dat.lyricsFetchGen=Dat.lyricsFetchGen+1
			clearCurrentLyrics()
			if lyricsOverlay then
				lyricsOverlay.prev.Text="";lyricsOverlay.prev.TextTransparency=0.35
				lyricsOverlay.next.Text="";lyricsOverlay.next.TextTransparency=0.35
				lyricsOverlay.current.RichText=false;lyricsOverlay.current.Text="[ Instrumental ]";lyricsOverlay.current.TextTransparency=0
				setLyricsStatusText("")
				if lyricsOverlay.refreshUnderline then lyricsOverlay.refreshUnderline() end
			end
			showTrackNotification("flagged as instrumental: "..nm,false)
		end
	end)
	lyricsOverlay={gui=lg,frame=fr,pill=pill,pillGrad=pg,prev=prevBtn,current=curBtn,next=nextBtn,underline=ul,noResults=noRes,spinnerImg=spn,displayedIndices=di,eolTitle=eolTitle,flagBtn=flagBtn,updateFlagBtn=updateFlagBtn}
	local function refUL() local txt=curBtn.Text
if txt=="" then Svc.TweenService:Create(ul,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{Size=UDim2.new(0,0,0,2)}):Play()
return end
local ts=game:GetService("TextService"):GetTextSize(txt,26,Enum.Font.GothamBold,Vector2.new(math.huge,math.huge))
Svc.TweenService:Create(ul,TweenInfo.new(0.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,math.min(ts.X,pill.AbsoluteSize.X*0.90),0,2)}):Play() end
	lyricsOverlay.refreshUnderline=refUL
end
local function createSidePanel(nm,sz,pos) local f=Instance.new("Frame")
f.Name=nm
f.Size=sz
f.Position=pos
f.BackgroundColor3=C.BG
f.BorderSizePixel=0
f.Visible=false
f.ZIndex=2
f.Parent=UI.main
applyCornerRadius(14,f)
applyStroke(1,C.BORDER_LIT,0.3,f)
local g=Instance.new("UIGradient")
g.Color=ColorSequence.new(C.CARD_HI,C.CARD_LO)
g.Rotation=145
g.Parent=f
return f end
do
	local panelW = isMobileLayout() and math.min(Cfg.LIST_WIDTH, getViewport().X - 8) or Cfg.LIST_WIDTH
	UI.listPanel = createSidePanel("ListPanel", UDim2.new(0, panelW, 1, 0), UDim2.new(0, 0, 0, 0))
end
local function syncListGlow() end
syncListGlow()
UI.listPanel:GetPropertyChangedSignal("Position"):Connect(syncListGlow)
UI.listPanel:GetPropertyChangedSignal("Size"):Connect(syncListGlow)
UI.listPanel:GetPropertyChangedSignal("Visible"):Connect(syncListGlow)
UI.listTitleBar=Instance.new("Frame")
UI.listTitleBar.Size=UDim2.new(1,0,0,32)
UI.listTitleBar.BackgroundTransparency=1
UI.listTitleBar.ClipsDescendants=false
UI.listTitleBar.ZIndex=2
UI.listTitleBar.Parent=UI.listPanel
UI.listTitle=Instance.new("TextLabel")
UI.listTitle.AnchorPoint=Vector2.new(0,0.5)
UI.listTitle.Position=UDim2.new(0,14,0,16)
UI.listTitle.Size=UDim2.new(1,-140,0,18)
UI.listTitle.BackgroundTransparency=1
UI.listTitle.Font=Enum.Font.GothamSemibold
UI.listTitle.Text="MP3 Files"
UI.listTitle.TextColor3=C.TEXT
UI.listTitle.TextXAlignment=Enum.TextXAlignment.Left
UI.listTitle.TextSize=14
UI.listTitle.ZIndex=2
UI.listTitle.Parent=UI.listTitleBar
UI.searchIconBtn=Instance.new("ImageButton")
UI.searchIconBtn.AnchorPoint=Vector2.new(1,0.5)
UI.searchIconBtn.Position=UDim2.new(1,-110,0,16)
UI.searchIconBtn.Size=UDim2.new(0,22,0,22)
UI.searchIconBtn.BackgroundColor3=C.ELEVATED
UI.searchIconBtn.AutoButtonColor=false
UI.searchIconBtn.BorderSizePixel=0
UI.searchIconBtn.Image="rbxassetid://125682890301992"
UI.searchIconBtn.ImageColor3=C.TEXT2
UI.searchIconBtn.ScaleType=Enum.ScaleType.Fit
UI.searchIconBtn.ZIndex=2
UI.searchIconBtn.Parent=UI.listTitleBar
applyCornerRadius(6,UI.searchIconBtn)
applyStroke(1,C.BORDER_LIT,0.45,UI.searchIconBtn)
UI.searchBox=Instance.new("TextBox")
UI.searchBox.Position=UDim2.new(0,8,0,36)
UI.searchBox.Size=UDim2.new(1,-16,0,22)
UI.searchBox.BackgroundColor3=C.SURFACE
UI.searchBox.BorderSizePixel=0
UI.searchBox.Font=Enum.Font.GothamMedium
UI.searchBox.PlaceholderText="Search tracks…"
UI.searchBox.PlaceholderColor3=C.TEXT3
UI.searchBox.Text=""
UI.searchBox.TextColor3=C.TEXT
UI.searchBox.TextSize=12
UI.searchBox.ClearTextOnFocus=false
UI.searchBox.ZIndex=2
UI.searchBox.Visible=false
UI.searchBox.Parent=UI.listTitleBar
applyCornerRadius(7,UI.searchBox)
applyStroke(1,C.BORDER_LIT,0.4,UI.searchBox)
do local sbPad=Instance.new("UIPadding")
sbPad.PaddingLeft=UDim.new(0,8)
sbPad.PaddingRight=UDim.new(0,8)
sbPad.Parent=UI.searchBox end
UI.searchIconBtn.MouseButton1Click:Connect(function()
	St.searchActive=not St.searchActive
	if St.searchActive then UI.searchBox.Visible=true;Svc.TweenService:Create(UI.listTitleBar,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{Size=UDim2.new(1,0,0,62)}):Play();Svc.TweenService:Create(UI.listScroll,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{Position=UDim2.new(0,10,0,68),Size=UDim2.new(1,-20,1,-76)}):Play();Svc.TweenService:Create(UI.searchIconBtn,TweenInfo.new(0.14),{ImageColor3=C.ACCENT,BackgroundColor3=C.ACCENT_DIM}):Play();UI.searchBox:CaptureFocus()
	else UI.searchBox:ReleaseFocus();UI.searchBox.Text="";St.searchQuery="";St.searchActive=false;UI.searchBox.Visible=false;Svc.TweenService:Create(UI.listTitleBar,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{Size=UDim2.new(1,0,0,32)}):Play();Svc.TweenService:Create(UI.listScroll,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{Position=UDim2.new(0,10,0,38),Size=UDim2.new(1,-20,1,-46)}):Play();Svc.TweenService:Create(UI.searchIconBtn,TweenInfo.new(0.14),{ImageColor3=C.TEXT2,BackgroundColor3=C.ELEVATED}):Play();rebuildTrackListUI() end
end)
UI.addCategoryBtn=Instance.new("TextButton")
UI.addCategoryBtn.AnchorPoint=Vector2.new(1,0.5)
UI.addCategoryBtn.Position=UDim2.new(1,-8,0,16)
UI.addCategoryBtn.Size=UDim2.new(0,96,0,22)
UI.addCategoryBtn.BackgroundColor3=C.ELEVATED
UI.addCategoryBtn.AutoButtonColor=false
UI.addCategoryBtn.Text=""
UI.addCategoryBtn.BorderSizePixel=0
UI.addCategoryBtn.ZIndex=2
UI.addCategoryBtn.Parent=UI.listTitleBar
applyCornerRadius(11,UI.addCategoryBtn)
do
	local acStr=applyStroke(1,C.BORDER_LIT,0.45,UI.addCategoryBtn)
local acIc=Instance.new("Frame")
acIc.AnchorPoint=Vector2.new(0,0.5)
acIc.Position=UDim2.new(0,3,0.5,0)
acIc.Size=UDim2.new(0,16,0,16)
acIc.BackgroundColor3=C.ACCENT
acIc.BorderSizePixel=0
acIc.ZIndex=2
acIc.Parent=UI.addCategoryBtn
applyCornerRadius(999,acIc)
	local acIcL=Instance.new("TextLabel")
acIcL.Size=UDim2.new(1,0,1,0)
acIcL.BackgroundTransparency=1
acIcL.Font=Enum.Font.GothamBold
acIcL.Text="+"
acIcL.TextColor3=AT
acIcL.TextSize=12
acIcL.ZIndex=2
acIcL.Parent=acIc
	local acLbl=Instance.new("TextLabel")
acLbl.AnchorPoint=Vector2.new(0,0.5)
acLbl.Position=UDim2.new(0,24,0.5,0)
acLbl.Size=UDim2.new(1,-28,1,0)
acLbl.BackgroundTransparency=1
acLbl.Font=Enum.Font.GothamMedium
acLbl.Text="new folder"
acLbl.TextColor3=C.TEXT2
acLbl.TextXAlignment=Enum.TextXAlignment.Left
acLbl.TextSize=11
acLbl.ZIndex=2
acLbl.Name="Label"
acLbl.Parent=UI.addCategoryBtn
	UI.addCategoryBtn.MouseEnter:Connect(function() Svc.TweenService:Create(UI.addCategoryBtn,TweenInfo.new(0.14,Enum.EasingStyle.Quad),{BackgroundColor3=C.ACCENT_DIM}):Play();acStr.Transparency=0;acLbl.TextColor3=C.TEXT end)
	UI.addCategoryBtn.MouseLeave:Connect(function() Svc.TweenService:Create(UI.addCategoryBtn,TweenInfo.new(0.14,Enum.EasingStyle.Quad),{BackgroundColor3=C.ELEVATED}):Play();acStr.Transparency=0.45;acLbl.TextColor3=C.TEXT2 end)
end
local function createScrollFrame(parent,pos,size,zi)
	local sf=Instance.new("ScrollingFrame")
sf.Position=pos
sf.Size=size
sf.BackgroundTransparency=1
sf.BorderSizePixel=0
sf.ScrollBarThickness=3
sf.ScrollBarImageColor3=C.ACCENT
sf.CanvasSize=UDim2.new(0,0,0,0)
sf.ZIndex=zi
sf.Parent=parent
	local ul=Instance.new("UIListLayout")
ul.Padding=UDim.new(0,5)
ul.SortOrder=Enum.SortOrder.LayoutOrder
ul.Parent=sf
	ul:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sf.CanvasSize=UDim2.new(0,0,0,ul.AbsoluteContentSize.Y+6) end)
return sf,ul
end
UI.listScroll,UI.listLayout=createScrollFrame(UI.listPanel,UDim2.new(0,10,0,38),UDim2.new(1,-20,1,-46),2)
do
	local panelW = isMobileLayout() and math.min(Cfg.LIST_WIDTH, getViewport().X - 8) or Cfg.LIST_WIDTH
	UI.queuePanel = createSidePanel("QueuePanel", UDim2.new(0, panelW, 1, 0), UDim2.new(1, -panelW, 0, 0))
end
do local qtb=Instance.new("Frame")
qtb.Size=UDim2.new(1,0,0,32)
qtb.BackgroundTransparency=1
qtb.ZIndex=2
qtb.Parent=UI.queuePanel
local qtl=Instance.new("TextLabel")
qtl.AnchorPoint=Vector2.new(0,0.5)
qtl.Position=UDim2.new(0,14,0.5,0)
qtl.Size=UDim2.new(1,-28,1,0)
qtl.BackgroundTransparency=1
qtl.Font=Enum.Font.GothamSemibold
qtl.Text="Queue"
qtl.TextColor3=C.TEXT
qtl.TextXAlignment=Enum.TextXAlignment.Left
qtl.TextSize=14
qtl.ZIndex=2
qtl.Parent=qtb end
UI.queueScroll,UI.queueLayout=createScrollFrame(UI.queuePanel,UDim2.new(0,10,0,38),UDim2.new(1,-20,1,-46),2)
local function createSidePanelToggle(ax,px,py,txt) local b=Instance.new("TextButton")
b.AnchorPoint=Vector2.new(ax,0.5)
b.Position=UDim2.new(px,py,0.5,0)
b.Size=UDim2.new(0,22,0,38)
b.BackgroundColor3=C.ELEVATED
b.AutoButtonColor=false
b.Font=Enum.Font.GothamBold
b.Text=txt
b.TextSize=13
b.TextColor3=C.ACCENT
b.BorderSizePixel=0
b.ZIndex=4
b.Parent=UI.main
applyCornerRadius(7,b)
applyStroke(1,C.BORDER_LIT,0.3,b)
return b end
UI.toggleListBtn=createSidePanelToggle(1,0,-6,">")
UI.toggleQueueBtn=createSidePanelToggle(0,1,6,"<")
local function setReverbPanelVisible(on) Svc.TweenService:Create(UI.main,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,Cfg.CARD_WIDTH,0,Cfg.BASE_HEIGHT+(on and Cfg.REVERB_EXTRA_HEIGHT or 0))}):Play()
if UI.reverbPanel then UI.reverbPanel.Visible=on end end
UI.titleBar=Instance.new("Frame")
UI.titleBar.Size=UDim2.new(1,0,0,34)
UI.titleBar.BackgroundTransparency=1
UI.titleBar.ZIndex=3
UI.titleBar.Parent=UI.main
do local tbord=Instance.new("Frame")
tbord.AnchorPoint=Vector2.new(0,1)
tbord.Position=UDim2.new(0,14,1,0)
tbord.Size=UDim2.new(1,-28,0,1)
tbord.BackgroundColor3=C.BORDER
tbord.BorderSizePixel=0
tbord.ZIndex=2
tbord.Parent=UI.titleBar end
UI.titleLabel=Instance.new("TextLabel")
UI.titleLabel.AnchorPoint=Vector2.new(0,0.5)
UI.titleLabel.Position=UDim2.new(0,14,0.5,0)
UI.titleLabel.Size=UDim2.new(0,200,0,20)
UI.titleLabel.BackgroundTransparency=1
UI.titleLabel.Font=Enum.Font.GothamBold
UI.titleLabel.Text="music controller"
UI.titleLabel.TextColor3=C.TEXT
UI.titleLabel.TextXAlignment=Enum.TextXAlignment.Left
UI.titleLabel.TextSize=14
UI.titleLabel.ZIndex=4
UI.titleLabel.Parent=UI.titleBar
UI.settingsButton=Instance.new("ImageButton")
UI.settingsButton.AnchorPoint=Vector2.new(1,0.5)
UI.settingsButton.Position=UDim2.new(1,-12,0.5,0)
UI.settingsButton.Size=UDim2.new(0,17,0,17)
UI.settingsButton.BackgroundTransparency=1
UI.settingsButton.ZIndex=4
UI.settingsButton.Image="rbxassetid://3687980595"
UI.settingsButton.ImageColor3=C.TEXT2
UI.settingsButton.Parent=UI.titleBar
UI.helpButton=Instance.new("ImageButton")
UI.helpButton.AnchorPoint=Vector2.new(1,0.5)
UI.helpButton.Position=UDim2.new(1,-34,0.5,0)
UI.helpButton.Size=UDim2.new(0,17,0,17)
UI.helpButton.BackgroundTransparency=1
UI.helpButton.ZIndex=220
UI.helpButton.Image="rbxassetid://15765508905"
UI.helpButton.ImageColor3=C.TEXT2
UI.helpButton.Visible=false
UI.helpButton.Parent=UI.titleBar
UI.dragArea=Instance.new("TextButton")
UI.dragArea.BackgroundTransparency=1
UI.dragArea.BorderSizePixel=0
UI.dragArea.Text=""
UI.dragArea.AutoButtonColor=false
UI.dragArea.Size=UDim2.new(1,0,1,0)
UI.dragArea.ZIndex=3
UI.dragArea.Parent=UI.titleBar
UI.toast=Instance.new("Frame")
UI.toast.AnchorPoint=Vector2.new(0.5,1)
UI.toast.Position=UDim2.new(0.5,0,0,-6)
UI.toast.Size=UDim2.new(0,310,0,56)
UI.toast.BackgroundColor3=C.ELEVATED
UI.toast.BorderSizePixel=0
UI.toast.Visible=false
UI.toast.ZIndex=3
UI.toast.Parent=UI.main
applyCornerRadius(14,UI.toast)
applyStroke(1,C.BORDER_LIT,0.35,UI.toast)
UI.toastScale=Instance.new("UIScale")
UI.toastScale.Scale=0
UI.toastScale.Parent=UI.toast
UI.toastBtn=Instance.new("TextButton")
UI.toastBtn.Size=UDim2.new(1,0,1,0)
UI.toastBtn.BackgroundTransparency=1
UI.toastBtn.Text=""
UI.toastBtn.AutoButtonColor=false
UI.toastBtn.ZIndex=3
UI.toastBtn.Parent=UI.toast
UI.toastIconCircle=Instance.new("Frame")
UI.toastIconCircle.AnchorPoint=Vector2.new(0,0.5)
UI.toastIconCircle.Position=UDim2.new(0,14,0.5,0)
UI.toastIconCircle.Size=UDim2.new(0,32,0,32)
UI.toastIconCircle.BackgroundColor3=C.ACCENT
UI.toastIconCircle.BorderSizePixel=0
UI.toastIconCircle.ZIndex=3
UI.toastIconCircle.Parent=UI.toast
applyCornerRadius(999,UI.toastIconCircle)
UI.toastPulse=Instance.new("Frame")
UI.toastPulse.AnchorPoint=Vector2.new(0.5,0.5)
UI.toastPulse.Position=UDim2.new(0.5,0,0.5,0)
UI.toastPulse.Size=UDim2.new(1,0,1,0)
UI.toastPulse.BackgroundColor3=C.TEXT
UI.toastPulse.BackgroundTransparency=1
UI.toastPulse.BorderSizePixel=0
UI.toastPulse.ZIndex=3
UI.toastPulse.Parent=UI.toastIconCircle
applyCornerRadius(999,UI.toastPulse)
UI.toastIcon=Instance.new("TextLabel")
UI.toastIcon.Size=UDim2.new(1,0,1,0)
UI.toastIcon.BackgroundTransparency=1
UI.toastIcon.Font=Enum.Font.GothamBold
UI.toastIcon.Text="+"
UI.toastIcon.TextColor3=C.BG
UI.toastIcon.TextSize=17
UI.toastIcon.ZIndex=3
UI.toastIcon.Parent=UI.toastIconCircle
UI.toastTitle=Instance.new("TextLabel")
UI.toastTitle.AnchorPoint=Vector2.new(0,1)
UI.toastTitle.Position=UDim2.new(0,56,0.5,-2)
UI.toastTitle.Size=UDim2.new(1,-64,0,18)
UI.toastTitle.BackgroundTransparency=1
UI.toastTitle.Font=Enum.Font.GothamSemibold
UI.toastTitle.Text=""
UI.toastTitle.TextColor3=C.TEXT
UI.toastTitle.TextXAlignment=Enum.TextXAlignment.Left
UI.toastTitle.TextSize=13
UI.toastTitle.TextTruncate=Enum.TextTruncate.AtEnd
UI.toastTitle.ZIndex=3
UI.toastTitle.Parent=UI.toast
UI.toastSub=Instance.new("TextLabel")
UI.toastSub.AnchorPoint=Vector2.new(0,0)
UI.toastSub.Position=UDim2.new(0,56,0.5,2)
UI.toastSub.Size=UDim2.new(1,-64,0,14)
UI.toastSub.BackgroundTransparency=1
UI.toastSub.Font=Enum.Font.GothamMedium
UI.toastSub.Text=""
UI.toastSub.TextColor3=C.ACCENT
UI.toastSub.TextXAlignment=Enum.TextXAlignment.Left
UI.toastSub.TextSize=11
UI.toastSub.ZIndex=3
UI.toastSub.Parent=UI.toast
UI.toastProgressTrack=Instance.new("Frame")
UI.toastProgressTrack.AnchorPoint=Vector2.new(0,1)
UI.toastProgressTrack.Position=UDim2.new(0,14,1,-5)
UI.toastProgressTrack.Size=UDim2.new(1,-28,0,3)
UI.toastProgressTrack.BackgroundColor3=C.BG
UI.toastProgressTrack.BorderSizePixel=0
UI.toastProgressTrack.ZIndex=3
UI.toastProgressTrack.Parent=UI.toast
applyCornerRadius(999,UI.toastProgressTrack)
UI.toastProgressFill=Instance.new("Frame")
UI.toastProgressFill.AnchorPoint=Vector2.new(0,0.5)
UI.toastProgressFill.Position=UDim2.new(0,0,0.5,0)
UI.toastProgressFill.Size=UDim2.new(1,0,1,0)
UI.toastProgressFill.BackgroundColor3=C.ACCENT
UI.toastProgressFill.BorderSizePixel=0
UI.toastProgressFill.ZIndex=3
UI.toastProgressFill.Parent=UI.toastProgressTrack
applyCornerRadius(999,UI.toastProgressFill)
UI.content=Instance.new("Frame")
UI.content.Position=UDim2.new(0,14,0,40)
UI.content.Size=UDim2.new(1,-28,1,-52)
UI.content.BackgroundTransparency=1
UI.content.ZIndex=3
UI.content.Parent=UI.main
UI.settingsPage=Instance.new("Frame")
UI.settingsPage.Position=UDim2.new(0,14,0,40)
UI.settingsPage.Size=UDim2.new(1,-28,1,-52)
UI.settingsPage.BackgroundTransparency=1
UI.settingsPage.ClipsDescendants=true
UI.settingsPage.ZIndex=3
UI.settingsPage.Visible=false
UI.settingsPage.Parent=UI.main
UI.settingsTabBar=Instance.new("Frame")
UI.settingsTabBar.Size=UDim2.new(1,0,0,28)
UI.settingsTabBar.BackgroundColor3=C.SURFACE
UI.settingsTabBar.BorderSizePixel=0
UI.settingsTabBar.ZIndex=4
UI.settingsTabBar.Parent=UI.settingsPage
applyCornerRadius(9,UI.settingsTabBar)
applyStroke(1,C.BORDER,0.15,UI.settingsTabBar)
local function createTabButton(nm,pos,txt,act,w) local b=Instance.new("TextButton")
b.Name=nm
b.Position=pos
b.Size=UDim2.new(w or 0.333,0,1,0)
b.BackgroundColor3=act and C.ELEVATED or C.SURFACE
b.AutoButtonColor=false
b.Font=act and Enum.Font.GothamSemibold or Enum.Font.GothamMedium
b.Text=txt
b.TextColor3=act and C.TEXT or C.TEXT2
b.TextSize=10
b.BorderSizePixel=0
b.ZIndex=5
b.Parent=UI.settingsTabBar
applyCornerRadius(9,b)
return b end
UI.settingsMainTabBtn=createTabButton("SettingsTabBtn",UDim2.new(0,0,0,0),"Settings",true,0.333)
UI.settingsDownloaderTabBtn=createTabButton("DownloaderTabBtn",UDim2.new(0.333,0,0,0),"MP3 Downloader",false,0.333)
UI.settingsScSearchTabBtn=createTabButton("ScSearchTabBtn",UDim2.new(0.667,0,0,0),"SC Search",false,0.334)
local tabDiv1=Instance.new("Frame")
tabDiv1.AnchorPoint=Vector2.new(0.5,0.5)
tabDiv1.Position=UDim2.new(0.333,0,0.5,0)
tabDiv1.Size=UDim2.new(0,1,1,-8)
tabDiv1.BackgroundColor3=C.BORDER
tabDiv1.BorderSizePixel=0
tabDiv1.ZIndex=6
tabDiv1.Parent=UI.settingsTabBar
local tabDiv2=Instance.new("Frame")
tabDiv2.AnchorPoint=Vector2.new(0.5,0.5)
tabDiv2.Position=UDim2.new(0.667,0,0.5,0)
tabDiv2.Size=UDim2.new(0,1,1,-8)
tabDiv2.BackgroundColor3=C.BORDER
tabDiv2.BorderSizePixel=0
tabDiv2.ZIndex=6
tabDiv2.Parent=UI.settingsTabBar
local tabInd=Instance.new("Frame")
tabInd.AnchorPoint=Vector2.new(0,1)
tabInd.Position=UDim2.new(0,6,1,-2)
tabInd.Size=UDim2.new(0.333,-12,0,2)
tabInd.BackgroundColor3=C.ACCENT
tabInd.BorderSizePixel=0
tabInd.ZIndex=6
tabInd.Parent=UI.settingsTabBar
applyCornerRadius(999,tabInd)
UI.settingsMainScroll=Instance.new("ScrollingFrame")
UI.settingsMainScroll.Position=UDim2.new(0,0,0,32)
UI.settingsMainScroll.Size=UDim2.new(1,0,1,-32)
UI.settingsMainScroll.BackgroundTransparency=1
UI.settingsMainScroll.BorderSizePixel=0
UI.settingsMainScroll.ScrollBarThickness=3
UI.settingsMainScroll.ScrollBarImageColor3=C.ACCENT
UI.settingsMainScroll.CanvasSize=UDim2.new(0,0,0,200)
UI.settingsMainScroll.ScrollingDirection=Enum.ScrollingDirection.Y
UI.settingsMainScroll.ClipsDescendants=true
UI.settingsMainScroll.ZIndex=3
UI.settingsMainScroll.Visible=true
UI.settingsMainScroll.Parent=UI.settingsPage
UI.settingsDownloaderScroll=Instance.new("ScrollingFrame")
UI.settingsDownloaderScroll.Position=UDim2.new(0,0,0,32)
UI.settingsDownloaderScroll.Size=UDim2.new(1,0,1,-32)
UI.settingsDownloaderScroll.BackgroundTransparency=1
UI.settingsDownloaderScroll.BorderSizePixel=0
UI.settingsDownloaderScroll.ScrollBarThickness=3
UI.settingsDownloaderScroll.ScrollBarImageColor3=C.ACCENT
UI.settingsDownloaderScroll.CanvasSize=UDim2.new(0,0,0,300)
UI.settingsDownloaderScroll.ScrollingDirection=Enum.ScrollingDirection.Y
UI.settingsDownloaderScroll.ClipsDescendants=true
UI.settingsDownloaderScroll.ZIndex=3
UI.settingsDownloaderScroll.Visible=false
UI.settingsDownloaderScroll.Parent=UI.settingsPage
UI.settingsScSearchScroll=Instance.new("ScrollingFrame")
UI.settingsScSearchScroll.Position=UDim2.new(0,0,0,32)
UI.settingsScSearchScroll.Size=UDim2.new(1,0,1,-32)
UI.settingsScSearchScroll.BackgroundTransparency=1
UI.settingsScSearchScroll.BorderSizePixel=0
UI.settingsScSearchScroll.ScrollBarThickness=3
UI.settingsScSearchScroll.ScrollBarImageColor3=C.ACCENT
UI.settingsScSearchScroll.CanvasSize=UDim2.new(0,0,0,400)
UI.settingsScSearchScroll.ScrollingDirection=Enum.ScrollingDirection.Y
UI.settingsScSearchScroll.ClipsDescendants=true
UI.settingsScSearchScroll.ZIndex=3
UI.settingsScSearchScroll.Visible=false
UI.settingsScSearchScroll.Parent=UI.settingsPage
local resetDownloader
local function switchSettingsTab(tab)
	St.settingsActiveTab=tab
local ct=TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local it=TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
	UI.settingsMainScroll.Visible=(tab=="main")
UI.settingsDownloaderScroll.Visible=(tab=="downloader")
UI.settingsScSearchScroll.Visible=(tab=="soundcloudSearch")
	local function ta(btn,act) Svc.TweenService:Create(btn,ct,{BackgroundColor3=act and C.ELEVATED or C.SURFACE,TextColor3=act and C.TEXT or C.TEXT2}):Play() end
	ta(UI.settingsMainTabBtn,tab=="main")
ta(UI.settingsDownloaderTabBtn,tab=="downloader")
ta(UI.settingsScSearchTabBtn,tab=="soundcloudSearch")
	local indPos=tab=="main" and UDim2.new(0,6,1,-2) or tab=="downloader" and UDim2.new(0.333,6,1,-2) or UDim2.new(0.667,6,1,-2)
	Svc.TweenService:Create(tabInd,it,{Position=indPos}):Play()
	if tab=="downloader" then task.defer(function() if resetDownloader then resetDownloader() end end) end
end
UI.settingsMainTabBtn.MouseButton1Click:Connect(function() if St.settingsActiveTab~="main" then switchSettingsTab("main") end end)
UI.settingsDownloaderTabBtn.MouseButton1Click:Connect(function() if St.settingsActiveTab~="downloader" then switchSettingsTab("downloader") end end)
UI.settingsScSearchTabBtn.MouseButton1Click:Connect(function() if St.settingsActiveTab~="soundcloudSearch" then switchSettingsTab("soundcloudSearch") end end)
UI.settingsMainTabBtn.MouseEnter:Connect(function() if St.settingsActiveTab~="main" then UI.settingsMainTabBtn.TextColor3=C.TEXT end end)
UI.settingsMainTabBtn.MouseLeave:Connect(function() if St.settingsActiveTab~="main" then UI.settingsMainTabBtn.TextColor3=C.TEXT2 end end)
UI.settingsDownloaderTabBtn.MouseEnter:Connect(function() if St.settingsActiveTab~="downloader" then UI.settingsDownloaderTabBtn.TextColor3=C.TEXT end end)
UI.settingsDownloaderTabBtn.MouseLeave:Connect(function() if St.settingsActiveTab~="downloader" then UI.settingsDownloaderTabBtn.TextColor3=C.TEXT2 end end)
UI.settingsScSearchTabBtn.MouseEnter:Connect(function() if St.settingsActiveTab~="soundcloudSearch" then UI.settingsScSearchTabBtn.TextColor3=C.TEXT end end)
UI.settingsScSearchTabBtn.MouseLeave:Connect(function() if St.settingsActiveTab~="soundcloudSearch" then UI.settingsScSearchTabBtn.TextColor3=C.TEXT2 end end)
local function createSettingRow(yp,lbl,par) local row=Instance.new("Frame")
row.Position=UDim2.new(0,0,0,yp)
row.Size=UDim2.new(1,0,0,26)
row.BackgroundTransparency=1
row.ZIndex=3
row.Parent=par
local l=Instance.new("TextLabel")
l.Position=UDim2.new(0,0,0,0)
l.Size=UDim2.new(0.58,0,1,0)
l.BackgroundTransparency=1
l.Font=Enum.Font.Gotham
l.Text=lbl
l.TextColor3=C.TEXT2
l.TextXAlignment=Enum.TextXAlignment.Left
l.TextSize=13
l.ZIndex=3
l.Parent=row
return row end
local function createSettingControl(par,isBox) local c
if isBox then c=Instance.new("TextBox") else c=Instance.new("TextButton")
c.AutoButtonColor=false end
c.AnchorPoint=Vector2.new(1,0.5)
c.Position=UDim2.new(1,0,0.5,0)
c.Size=UDim2.new(0,82,0,24)
c.BackgroundColor3=C.SURFACE
c.BorderSizePixel=0
c.Font=Enum.Font.GothamMedium
c.TextSize=12
c.TextColor3=C.TEXT2
c.ZIndex=3
c.Parent=par
applyCornerRadius(9,c)
applyStroke(1,C.BORDER,0.2,c)
return c end
local shakeOC,crossRow,lyrRow,cinematicRow,notifRow,muteRow
local themeExp=false
local stopCinematicOverlay
local kbPanelExp=false
local function updateSettingsCanvas() local shx=St.screenShakeEnabled and Cfg.SHAKE_PANEL_HEIGHT or 0
local thh=themeExp and Cfg.THEME_PANEL_EXPANDED_HEIGHT or Cfg.THEME_PANEL_COLLAPSED_HEIGHT
local lyx=St.lyricsEnabled and 28 or 0
local kbh=kbPanelExp and (Cfg.THEME_PANEL_COLLAPSED_HEIGHT+10*(Cfg.THEME_ROW_HEIGHT+4)+8) or Cfg.THEME_PANEL_COLLAPSED_HEIGHT
UI.settingsMainScroll.CanvasSize=UDim2.new(0,0,0,154+lyx+shx+thh+6+kbh+16) end
local shakeRowUI=createSettingRow(8,"Screen Shake (Visualizer)",UI.settingsMainScroll)
UI.shakeToggle=createSettingControl(shakeRowUI,false)
UI.shakeToggle.Text=""
local function refreshShakeToggle()
	local ct=TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local ti=TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	if St.screenShakeEnabled then Svc.TweenService:Create(UI.shakeToggle,ct,{BackgroundColor3=C.ACCENT}):Play()
Svc.TweenService:Create(UI.shakeToggle,ct,{TextColor3=AT}):Play()
UI.shakeToggle.Text="on"
	else Svc.TweenService:Create(UI.shakeToggle,ct,{BackgroundColor3=C.SURFACE}):Play()
Svc.TweenService:Create(UI.shakeToggle,ct,{TextColor3=C.TEXT3}):Play()
UI.shakeToggle.Text="off" end
	local off=St.screenShakeEnabled and Cfg.SHAKE_PANEL_HEIGHT or 0
	if shakeOC then Svc.TweenService:Create(shakeOC,ti,{Size=UDim2.new(1,0,0,St.screenShakeEnabled and Cfg.SHAKE_PANEL_HEIGHT or 0)}):Play() end
	if crossRow then Svc.TweenService:Create(crossRow,ti,{Position=UDim2.new(0,0,0,40+off)}):Play() end
	if lyrRow then Svc.TweenService:Create(lyrRow,ti,{Position=UDim2.new(0,0,0,68+off)}):Play() end
	if cinematicRow then
		local cv=St.lyricsEnabled and 1 or 0
		Svc.TweenService:Create(cinematicRow,ti,{Position=UDim2.new(0,0,0,96+off),Size=UDim2.new(1,0,0,26*cv)}):Play()
	end
	if notifRow then Svc.TweenService:Create(notifRow,ti,{Position=UDim2.new(0,0,0,(St.lyricsEnabled and 124 or 96)+off)}):Play() end
	if muteRow then Svc.TweenService:Create(muteRow,ti,{Position=UDim2.new(0,0,0,(St.lyricsEnabled and 152 or 124)+off)}):Play() end
	if UI.themePanel then Svc.TweenService:Create(UI.themePanel,ti,{Position=UDim2.new(0,0,0,(St.lyricsEnabled and 182 or 154)+off)}):Play() end
	if UI.kbPanel then local thH=themeExp and Cfg.THEME_PANEL_EXPANDED_HEIGHT or Cfg.THEME_PANEL_COLLAPSED_HEIGHT
local lyx=St.lyricsEnabled and 28 or 0
Svc.TweenService:Create(UI.kbPanel,ti,{Position=UDim2.new(0,0,0,154+lyx+off+thH+6)}):Play() end
	updateSettingsCanvas()
end
UI.shakeToggle.MouseButton1Click:Connect(function() St.screenShakeEnabled=not St.screenShakeEnabled;shakeVal.Value=St.screenShakeEnabled;refreshShakeToggle();saveUserSettings() end)
shakeVal.Changed:Connect(function(v) if St.screenShakeEnabled~=v then St.screenShakeEnabled=v;refreshShakeToggle() end end)
shakeOC=Instance.new("Frame")
shakeOC.Position=UDim2.new(0,0,0,40)
shakeOC.Size=UDim2.new(1,0,0,0)
shakeOC.BackgroundTransparency=1
shakeOC.ClipsDescendants=true
shakeOC.ZIndex=3
shakeOC.Parent=UI.settingsMainScroll
local siRow=createSettingRow(2,"Shake Intensity",shakeOC)
UI.shakeIntensityBox=createSettingControl(siRow,true)
UI.shakeIntensityBox.Text=tostring(St.shakeIntensity)
UI.shakeIntensityBox.ClearTextOnFocus=false
UI.shakeIntensityBox.Focused:Connect(function() UI.shakeIntensityBox.Text="" end)
UI.shakeIntensityBox.FocusLost:Connect(function() local n=tonumber(UI.shakeIntensityBox.Text);if n and n>=0 and n<=5 then St.shakeIntensity=n;UI.shakeIntensityBox.Text=tostring(n);saveUserSettings() else UI.shakeIntensityBox.Text=tostring(St.shakeIntensity) end end)
local fiRow=createSettingRow(30,"FOV Intensity",shakeOC)
UI.fovIntensityBox=createSettingControl(fiRow,true)
UI.fovIntensityBox.Text=tostring(St.fovIntensity)
UI.fovIntensityBox.ClearTextOnFocus=false
UI.fovIntensityBox.Focused:Connect(function() UI.fovIntensityBox.Text="" end)
UI.fovIntensityBox.FocusLost:Connect(function() local n=tonumber(UI.fovIntensityBox.Text);if n and n>=0 and n<=5 then St.fovIntensity=n;UI.fovIntensityBox.Text=tostring(n);saveUserSettings() else UI.fovIntensityBox.Text=tostring(St.fovIntensity) end end)
if kbRow then end
crossRow=createSettingRow(40,"Crossfade Tracks",UI.settingsMainScroll)
UI.crossToggle=createSettingControl(crossRow,false)
UI.crossToggle.Text=""
local function refreshCrossfadeToggle() local ct=TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
if St.crossfadeEnabled then Svc.TweenService:Create(UI.crossToggle,ct,{BackgroundColor3=C.ACCENT}):Play()
Svc.TweenService:Create(UI.crossToggle,ct,{TextColor3=AT}):Play()
UI.crossToggle.Text="on" else Svc.TweenService:Create(UI.crossToggle,ct,{BackgroundColor3=C.SURFACE}):Play()
Svc.TweenService:Create(UI.crossToggle,ct,{TextColor3=C.TEXT3}):Play()
UI.crossToggle.Text="off" end end
UI.crossToggle.MouseButton1Click:Connect(function() St.crossfadeEnabled=not St.crossfadeEnabled;refreshCrossfadeToggle();saveUserSettings() end)
lyrRow=createSettingRow(68,"Show Synced Lyrics",UI.settingsMainScroll)
UI.lyricsToggleBtn=createSettingControl(lyrRow,false)
UI.lyricsToggleBtn.Text="off"
local function refreshLyricsToggle()
	local ct=TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	if St.lyricsEnabled then Svc.TweenService:Create(UI.lyricsToggleBtn,ct,{BackgroundColor3=C.ACCENT}):Play()
Svc.TweenService:Create(UI.lyricsToggleBtn,ct,{TextColor3=AT}):Play()
UI.lyricsToggleBtn.Text="on"
	else Svc.TweenService:Create(UI.lyricsToggleBtn,ct,{BackgroundColor3=C.SURFACE}):Play()
Svc.TweenService:Create(UI.lyricsToggleBtn,ct,{TextColor3=C.TEXT3}):Play()
UI.lyricsToggleBtn.Text="off" end
end
local refreshCinematicToggle
local _lyricsTween=nil
local showLyricsPanel,hideLyricsPanel
showLyricsPanel=function()
	if not lyricsOverlay or not lyricsOverlay.gui or not lyricsOverlay.frame then return end
	if _lyricsTween then _lyricsTween:Cancel()
_lyricsTween=nil end
	lyricsOverlay.gui.Enabled=true
	lyricsOverlay.frame.Position=UDim2.new(0.5,0,1.3,0)
	_lyricsTween=Svc.TweenService:Create(lyricsOverlay.frame,TweenInfo.new(0.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,0,0.87,0)})
	_lyricsTween:Play()
end
hideLyricsPanel=function(onDone)
	if not lyricsOverlay or not lyricsOverlay.frame then return end
	if _lyricsTween then _lyricsTween:Cancel()
_lyricsTween=nil end
	_lyricsTween=Svc.TweenService:Create(lyricsOverlay.frame,TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(0.5,0,1.3,0)})
	_lyricsTween.Completed:Connect(function(s)
		if s==Enum.TweenStatus.Completed then
			if lyricsOverlay and lyricsOverlay.gui then lyricsOverlay.gui.Enabled=false end
			if onDone then onDone() end
		end
	end)
	_lyricsTween:Play()
end
UI.lyricsToggleBtn.MouseButton1Click:Connect(function()
	St.lyricsEnabled=not St.lyricsEnabled;refreshLyricsToggle();saveUserSettings()
	if St.lyricsEnabled then
		local inf=Dat.trackList[St.currentTrackIndex];if inf then Dat.lyricsFetchGen=Dat.lyricsFetchGen+1;fetchLyricsForTrack(inf.DisplayName,Dat.lyricsFetchGen) end
		refreshCinematicToggle()
		if St.cinematicMode then
			if lyricsOverlay and lyricsOverlay.gui then lyricsOverlay.gui.Enabled=false end
			task.defer(function() startCinematicOverlay() end)
		else showLyricsPanel() end
	else
		clearCurrentLyrics()
		if St.cinematicMode then St.cinematicMode=false;stopCinematicOverlay();refreshCinematicToggle();saveUserSettings()
		else hideLyricsPanel() end
	end
	local ti=TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	if cinematicRow then Svc.TweenService:Create(cinematicRow,ti,{Size=UDim2.new(1,0,0,St.lyricsEnabled and 26 or 0)}):Play() end
	local off=St.screenShakeEnabled and Cfg.SHAKE_PANEL_HEIGHT or 0
	local extra=St.lyricsEnabled and 28 or 0
	if notifRow then Svc.TweenService:Create(notifRow,ti,{Position=UDim2.new(0,0,0,96+extra+off)}):Play() end
	if muteRow then Svc.TweenService:Create(muteRow,ti,{Position=UDim2.new(0,0,0,124+extra+off)}):Play() end
	if UI.themePanel then Svc.TweenService:Create(UI.themePanel,ti,{Position=UDim2.new(0,0,0,154+extra+off)}):Play() end
	if UI.kbPanel then local thH=themeExp and Cfg.THEME_PANEL_EXPANDED_HEIGHT or Cfg.THEME_PANEL_COLLAPSED_HEIGHT;Svc.TweenService:Create(UI.kbPanel,ti,{Position=UDim2.new(0,0,0,154+extra+off+thH+6)}):Play() end
	updateSettingsCanvas()
end)
cinematicRow=createSettingRow(96,"Cinematic Mode",UI.settingsMainScroll)
cinematicRow.Size=UDim2.new(1,0,0,St.lyricsEnabled and 26 or 0)
cinematicRow.ClipsDescendants=true
UI.cinematicBtn=createSettingControl(cinematicRow,false)
UI.cinematicBtn.Text="off"
stopCinematicOverlay=function()
	St.cinematicMode=false
_cinLocked=false
	if not _cinGui then
		if St.lyricsEnabled then showLyricsPanel() end
return
	end
	local sg=_cinGui
_cinGui=nil
	for _,ch in ipairs(sg:GetChildren()) do
		if ch:IsA("TextLabel") then
			Svc.TweenService:Create(ch,TweenInfo.new(0.35,Enum.EasingStyle.Quad),{TextTransparency=1}):Play()
		end
	end
	local topBar=sg:FindFirstChild("TopCinBar")
local botBar=sg:FindFirstChild("BotCinBar")
	local exitTI=TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.In)
	task.delay(0.3,function()
		if topBar then Svc.TweenService:Create(topBar,exitTI,{Position=UDim2.new(0,0,-0.6,0)}):Play() end
		if botBar then Svc.TweenService:Create(botBar,exitTI,{Position=UDim2.new(0,0,1.6,0)}):Play() end
	end)
	task.delay(1.0,function()
		if St.lyricsEnabled then showLyricsPanel() end
	end)
	task.delay(1.6,function() pcall(function() sg:Destroy() end) end)
end
local function startCinematicOverlay()
	if not St.lyricsEnabled or not lyricsOverlay then return end
	St.cinematicMode=true
	if _lyricsTween then _lyricsTween:Cancel()
_lyricsTween=nil end
	_lyricsTween=Svc.TweenService:Create(lyricsOverlay.frame,TweenInfo.new(1.0,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(0.5,0,1.3,0)})
	_lyricsTween:Play()
	task.delay(1.0,function()
		if not St.cinematicMode then return end
		lyricsOverlay.gui.Enabled=false
		local sg=Instance.new("ScreenGui");sg.Name="CinematicModeGui";sg.IgnoreGuiInset=true;sg.ResetOnSpawn=false;sg.DisplayOrder=2147483646;sg.Parent=pGui;_cinGui=sg
		local topBar=Instance.new("Frame");topBar.Name="TopCinBar";topBar.Size=UDim2.new(1,0,0.12,0);topBar.Position=UDim2.new(0,0,-0.12,0);topBar.BackgroundColor3=Color3.new(0,0,0);topBar.BorderSizePixel=0;topBar.ZIndex=100;topBar.Parent=sg
		local botBar=Instance.new("Frame");botBar.Name="BotCinBar";botBar.Size=UDim2.new(1,0,0.12,0);botBar.Position=UDim2.new(0,0,1.12,0);botBar.AnchorPoint=Vector2.new(0,1);botBar.BackgroundColor3=Color3.new(0,0,0);botBar.BorderSizePixel=0;botBar.ZIndex=100;botBar.Parent=sg
		local si=TweenInfo.new(0.9,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
		Svc.TweenService:Create(topBar,si,{Position=UDim2.new(0,0,0,0)}):Play()
		Svc.TweenService:Create(botBar,si,{Position=UDim2.new(0,0,1,0)}):Play()
		local lastShownLine=-1
		local cinConn;cinConn=Svc.RunService.Heartbeat:Connect(function()
			if not St.cinematicMode or not _cinGui or not _cinGui.Parent then cinConn:Disconnect();return end
			local lyr=Dat.currentLyrics;if #lyr==0 then return end
			local s=sound;if not s or not s.IsPlaying then return end
			local pos=s.TimePosition
			local ci2=0
			for i,e in ipairs(lyr) do if pos>=e.time then ci2=i else break end end
			if ci2==0 or ci2==lastShownLine then return end
			lastShownLine=ci2
			local entry=lyr[ci2];if not entry then return end
			local text=St.translateEnabled and (Dat.translateCache[entry.text] or entry.text) or entry.text
			for _,ch in ipairs(sg:GetChildren()) do if ch:IsA("TextLabel") then pcall(function() ch:Destroy() end) end end
			local vp=Svc.Workspace.CurrentCamera and Svc.Workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
			local xPos={0.04,0.12,0.35,0.52,0.65};local yPos={0.22,0.32,0.44,0.54,0.63}
			local xi=((ci2-1)%#xPos)+1;local yi=((ci2*3)%#yPos)+1
			local maxW=math.floor(vp.X*0.90);local startX=math.max(20,math.floor(xPos[xi]*vp.X))
			if startX+maxW>vp.X-20 then startX=math.max(20,math.floor(vp.X-maxW-20)) end
			local lbl=Instance.new("TextLabel");lbl.Size=UDim2.new(0,maxW,0,200);lbl.Position=UDim2.fromOffset(startX,math.floor(yPos[yi]*vp.Y));lbl.AnchorPoint=Vector2.new(0,0)
			lbl.BackgroundTransparency=1;lbl.Font=Enum.Font.GothamBold;lbl.Text=text;lbl.TextColor3=C.TEXT;lbl.TextSize = math.clamp(math.floor(54 * computeUiScale()), 18, 54);lbl.RichText=false;lbl.TextXAlignment=Enum.TextXAlignment.Left;lbl.TextTransparency=1;lbl.TextStrokeTransparency=1;lbl.TextStrokeColor3=C.BG;lbl.ZIndex=101;lbl.TextWrapped=true;lbl.Parent=sg
			Svc.TweenService:Create(lbl,TweenInfo.new(0.15),{TextTransparency=0,TextStrokeTransparency=0.4}):Play()
			local lineEnd=(ci2<#lyr) and lyr[ci2+1].time or (s.TimeLength or (entry.time+3))
			local dur=math.max(0.5,(lineEnd-entry.time)-0.2)
			task.delay(dur,function() if lbl and lbl.Parent then local tw=Svc.TweenService:Create(lbl,TweenInfo.new(0.25),{TextTransparency=1,TextStrokeTransparency=1});tw.Completed:Connect(function() pcall(function() lbl:Destroy() end) end);tw:Play() end end)
		end)
	end)
end
refreshCinematicToggle=function()
	local ct=TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	if St.cinematicMode then Svc.TweenService:Create(UI.cinematicBtn,ct,{BackgroundColor3=C.ACCENT}):Play()
Svc.TweenService:Create(UI.cinematicBtn,ct,{TextColor3=AT}):Play()
UI.cinematicBtn.Text="on"
	else Svc.TweenService:Create(UI.cinematicBtn,ct,{BackgroundColor3=C.SURFACE}):Play()
Svc.TweenService:Create(UI.cinematicBtn,ct,{TextColor3=C.TEXT3}):Play()
UI.cinematicBtn.Text="off" end
end
local _cinLocked=false
UI.cinematicBtn.MouseButton1Click:Connect(function()
	if not St.lyricsEnabled or _cinLocked then return end
	_cinLocked=true
	St.cinematicMode=not St.cinematicMode;refreshCinematicToggle();saveUserSettings()
	if St.cinematicMode then
		startCinematicOverlay()
		task.delay(2.2,function() _cinLocked=false end)
	else
		stopCinematicOverlay()
		task.delay(2.8,function() _cinLocked=false end)
	end
end)
refreshCinematicToggle()
refreshCrossfadeToggle()
refreshShakeToggle()
refreshLyricsToggle()
notifRow=createSettingRow(96,"Notification Volume",UI.settingsMainScroll)
UI.notifVolumeBox=createSettingControl(notifRow,true)
UI.notifVolumeBox.Text=tostring(St.notifVolume)
UI.notifVolumeBox.ClearTextOnFocus=false
UI.notifVolumeBox.Focused:Connect(function() UI.notifVolumeBox.Text="" end)
UI.notifVolumeBox.FocusLost:Connect(function() local n=tonumber(UI.notifVolumeBox.Text);if n and n>=0 and n<=1 then St.notifVolume=n;UI.notifVolumeBox.Text=tostring(n);saveUserSettings() else UI.notifVolumeBox.Text=tostring(St.notifVolume) end end)
muteRow=createSettingRow(124,"Mute In-Game Sounds",UI.settingsMainScroll)
UI.muteGameBtn=createSettingControl(muteRow,false)
UI.muteGameBtn.Text="off"
do
	local savedVols={}
local muteConns={}
local muteDescConn=nil
	local function muteOne(s) if not s or not s:IsA("Sound") then return end
if s.Parent and s.Parent.Name=="MusicControllerSounds" then return end
if savedVols[s] then return end
savedVols[s]=s.Volume
pcall(function() s.Volume=0 end)
local conn=s:GetPropertyChangedSignal("Volume"):Connect(function() if St.muteGameSounds and s.Volume~=0 then pcall(function() s.Volume=0 end) end end)
table.insert(muteConns,conn) end
	local function muteAllNow() for _,s in ipairs(game:GetDescendants()) do if s:IsA("Sound") and (not s.Parent or s.Parent.Name~="MusicControllerSounds") then muteOne(s) end end
muteDescConn=game.DescendantAdded:Connect(function(obj) if obj:IsA("Sound") then task.defer(function() muteOne(obj) end) end end)
_G.__MCMuteCleanup=function() if muteDescConn then muteDescConn:Disconnect()
muteDescConn=nil end
for _,c in ipairs(muteConns) do pcall(function() c:Disconnect() end) end
muteConns={}
savedVols={} end end
	local function restoreAll() if muteDescConn then muteDescConn:Disconnect()
muteDescConn=nil end
for _,c in ipairs(muteConns) do pcall(function() c:Disconnect() end) end
muteConns={}
for s,vol in pairs(savedVols) do pcall(function() if s and s.Parent then s.Volume=vol end end) end
savedVols={}
_G.__MCMuteCleanup=nil end
	local function refMuteBtn() local ct=TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
if St.muteGameSounds then Svc.TweenService:Create(UI.muteGameBtn,ct,{BackgroundColor3=C.ACCENT}):Play()
Svc.TweenService:Create(UI.muteGameBtn,ct,{TextColor3=AT}):Play()
UI.muteGameBtn.Text="on"
task.spawn(muteAllNow) else Svc.TweenService:Create(UI.muteGameBtn,ct,{BackgroundColor3=C.SURFACE}):Play()
Svc.TweenService:Create(UI.muteGameBtn,ct,{TextColor3=C.TEXT3}):Play()
UI.muteGameBtn.Text="off"
restoreAll() end end
	UI.muteGameBtn.MouseButton1Click:Connect(function() St.muteGameSounds=not St.muteGameSounds;refMuteBtn();saveUserSettings() end)
refMuteBtn()
	_G.__MCRefMute=refMuteBtn
end
local function refreshTranslateToggle()
	if _G.__MCRefTranslatePill then _G.__MCRefTranslatePill() end
end
refreshTranslateToggle()
local TCOLS={{key="ACCENT",label="Accent"},{key="ACCENT_DIM",label="Accent Dim"},{key="BG",label="Background"},{key="SURFACE",label="Surface"},{key="ELEVATED",label="Elevated"},{key="BORDER",label="Border"},{key="BORDER_LIT",label="Border Lit"},{key="TEXT",label="Text"},{key="TEXT2",label="Text Secondary"},{key="TEXT3",label="Text Muted"},{key="SUCCESS",label="Success"},{key="DANGER",label="Danger"}}
Cfg.THEME_PANEL_EXPANDED_HEIGHT=Cfg.THEME_PANEL_COLLAPSED_HEIGHT+#TCOLS*(Cfg.THEME_ROW_HEIGHT+4)+8
local function h2c3(h) h=h:gsub("^#",""):gsub("^0x","")
if #h~=6 then return nil end
local r,g,b=tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16)
if not(r and g and b) then return nil end
return Color3.fromRGB(r,g,b) end
local function c32h(c) return string.format("%02X%02X%02X",math.floor(c.R*255+0.5),math.floor(c.G*255+0.5),math.floor(c.B*255+0.5)) end
local function applyThemeColors()
	if UI.main then applyStroke(1,C.BORDER_LIT,0.25,UI.main) end
	for _,p in ipairs({UI.listPanel,UI.queuePanel}) do if p then for _,ch in ipairs(p:GetChildren()) do if ch:IsA("UIStroke") then ch.Color=C.BORDER_LIT end end end end
	for _,sf in ipairs({UI.listScroll,UI.queueScroll,UI.settingsMainScroll,UI.settingsDownloaderScroll,UI.settingsScSearchScroll}) do if sf then sf.ScrollBarImageColor3=C.ACCENT end end
	for _,b in ipairs({UI.toggleListBtn,UI.toggleQueueBtn}) do if b then b.BackgroundColor3=C.ELEVATED
b.TextColor3=C.ACCENT end end
	if UI.addCategoryBtn then UI.addCategoryBtn.BackgroundColor3=C.ELEVATED
local lb=UI.addCategoryBtn:FindFirstChild("Label")
if lb then lb.TextColor3=C.TEXT2 end end
	if UI.titleLabel then UI.titleLabel.TextColor3=C.TEXT end
if UI.settingsButton then UI.settingsButton.ImageColor3=C.TEXT2 end
	if UI.searchIconBtn then UI.searchIconBtn.ImageColor3=St.searchActive and C.ACCENT or C.TEXT2
UI.searchIconBtn.BackgroundColor3=St.searchActive and C.ACCENT_DIM or C.ELEVATED end
	if UI.searchBox then UI.searchBox.BackgroundColor3=C.SURFACE
UI.searchBox.TextColor3=C.TEXT
UI.searchBox.PlaceholderColor3=C.TEXT3 end
	if UI.currentTrackButton then UI.currentTrackButton.TextColor3=C.TEXT end
if UI.nextTrackLabel then UI.nextTrackLabel.TextColor3=C.TEXT end
	if UI.playPauseBtn then if St.isPaused then UI.playPauseBtn.BackgroundColor3=C.ACCENT
UI.playPauseBtn.TextColor3=AT else UI.playPauseBtn.BackgroundColor3=C.ELEVATED
UI.playPauseBtn.TextColor3=C.TEXT end end
	for _,b in ipairs({UI.prevBtn,UI.nextBtn}) do if b then b.BackgroundColor3=C.SURFACE
b.TextColor3=C.TEXT2 end end
	if UI.repeatToggle then UI.repeatToggle.RefreshTheme() end
if UI.shuffleToggle then UI.shuffleToggle.RefreshTheme() end
	if UI.progressBar then UI.progressBar.BackgroundColor3=C.ELEVATED end
if UI.progressFill then UI.progressFill.BackgroundColor3=C.ACCENT end
	if UI.timeDisplay then UI.timeDisplay.TextColor3=C.TEXT3 end
if UI.nextTimeDisplay then UI.nextTimeDisplay.TextColor3=C.TEXT3 end
	for _,b in ipairs(Dat.meterBars) do b.BackgroundColor3=C.ACCENT end
	if UI.themePanel then UI.themePanel.BackgroundColor3=C.SURFACE end
	if UI.settingsTabBar then UI.settingsTabBar.BackgroundColor3=C.SURFACE end
if tabInd then tabInd.BackgroundColor3=C.ACCENT end
	if UI.dlButton then UI.dlButton.BackgroundColor3=C.ACCENT
UI.dlButton.TextColor3=AT end
	if UI.scSearchBtn then UI.scSearchBtn.BackgroundColor3=C.ACCENT
UI.scSearchBtn.TextColor3=AT end
	if UI.cinematicBtn then if St.cinematicMode then UI.cinematicBtn.BackgroundColor3=C.ACCENT
UI.cinematicBtn.TextColor3=AT else UI.cinematicBtn.BackgroundColor3=C.SURFACE
UI.cinematicBtn.TextColor3=C.TEXT3 end end
	if lyricsOverlay then
		lyricsOverlay.pill.BackgroundColor3=C.BG
for _,s in ipairs(lyricsOverlay.pill:GetChildren()) do if s:IsA("UIStroke") then s.Color=C.BORDER_LIT end end
		if lyricsOverlay.pillGrad then lyricsOverlay.pillGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C.ELEVATED),ColorSequenceKeypoint.new(1,C.BG)}) end
		lyricsOverlay.prev.TextColor3=C.TEXT2
lyricsOverlay.current.TextColor3=C.TEXT
lyricsOverlay.next.TextColor3=C.TEXT2
lyricsOverlay.underline.BackgroundColor3=C.ACCENT
lyricsOverlay.noResults.TextColor3=C.TEXT3
		local fl=lyricsOverlay.underline:FindFirstChild("FadeL")
if fl then fl.BackgroundColor3=C.BG end
local fr2=lyricsOverlay.underline:FindFirstChild("FadeR")
if fr2 then fr2.BackgroundColor3=C.BG end
	end
end
UI.themePanel=Instance.new("Frame")
UI.themePanel.Position=UDim2.new(0,0,0,154)
UI.themePanel.Size=UDim2.new(1,0,0,Cfg.THEME_PANEL_COLLAPSED_HEIGHT)
UI.themePanel.BackgroundColor3=C.SURFACE
UI.themePanel.BorderSizePixel=0
UI.themePanel.ClipsDescendants=true
UI.themePanel.ZIndex=3
UI.themePanel.Parent=UI.settingsMainScroll
applyCornerRadius(10,UI.themePanel)
applyStroke(1,C.BORDER,0.15,UI.themePanel)
local thHdr=Instance.new("TextButton")
thHdr.Size=UDim2.new(1,0,0,Cfg.THEME_PANEL_COLLAPSED_HEIGHT)
thHdr.BackgroundTransparency=1
thHdr.AutoButtonColor=false
thHdr.Font=Enum.Font.GothamMedium
thHdr.Text=""
thHdr.ZIndex=4
thHdr.Parent=UI.themePanel
local thHL=Instance.new("TextLabel")
thHL.AnchorPoint=Vector2.new(0,0.5)
thHL.Position=UDim2.new(0,12,0.5,0)
thHL.Size=UDim2.new(0.6,0,1,0)
thHL.BackgroundTransparency=1
thHL.Font=Enum.Font.GothamMedium
thHL.Text="Theme Colors"
thHL.TextColor3=C.TEXT2
thHL.TextXAlignment=Enum.TextXAlignment.Left
thHL.TextSize=13
thHL.ZIndex=4
thHL.Parent=thHdr
local thCh=Instance.new("TextLabel")
thCh.AnchorPoint=Vector2.new(1,0.5)
thCh.Position=UDim2.new(1,-12,0.5,0)
thCh.Size=UDim2.new(0,20,1,0)
thCh.BackgroundTransparency=1
thCh.Font=Enum.Font.GothamBold
thCh.Text="v"
thCh.TextColor3=C.TEXT3
thCh.TextXAlignment=Enum.TextXAlignment.Right
thCh.TextSize=12
thCh.ZIndex=4
thCh.Parent=thHdr
local thSep=Instance.new("Frame")
thSep.Position=UDim2.new(0,10,0,Cfg.THEME_PANEL_COLLAPSED_HEIGHT-1)
thSep.Size=UDim2.new(1,-20,0,1)
thSep.BackgroundColor3=C.BORDER
thSep.BorderSizePixel=0
thSep.ZIndex=3
thSep.Parent=UI.themePanel
local thScr=Instance.new("ScrollingFrame")
thScr.Position=UDim2.new(0,0,0,Cfg.THEME_PANEL_COLLAPSED_HEIGHT+2)
thScr.Size=UDim2.new(1,0,1,-(Cfg.THEME_PANEL_COLLAPSED_HEIGHT+2))
thScr.BackgroundTransparency=1
thScr.BorderSizePixel=0
thScr.ScrollBarThickness=3
thScr.ScrollBarImageColor3=C.ACCENT
thScr.CanvasSize=UDim2.new(0,0,0,0)
thScr.ZIndex=3
thScr.Parent=UI.themePanel
local thRL=Instance.new("UIListLayout")
thRL.Padding=UDim.new(0,4)
thRL.SortOrder=Enum.SortOrder.LayoutOrder
thRL.Parent=thScr
local thRP=Instance.new("UIPadding")
thRP.PaddingTop=UDim.new(0,4)
thRP.PaddingLeft=UDim.new(0,8)
thRP.PaddingRight=UDim.new(0,8)
thRP.Parent=thScr
thRL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() thScr.CanvasSize=UDim2.new(0,0,0,thRL.AbsoluteContentSize.Y+10) end)
for i,cd in ipairs(TCOLS) do
	local row=Instance.new("Frame")
row.Size=UDim2.new(1,0,0,Cfg.THEME_ROW_HEIGHT)
row.BackgroundColor3=C.ELEVATED
row.BorderSizePixel=0
row.LayoutOrder=i
row.ZIndex=3
row.Parent=thScr
applyCornerRadius(7,row)
	local sw=Instance.new("Frame")
sw.AnchorPoint=Vector2.new(0,0.5)
sw.Position=UDim2.new(0,8,0.5,0)
sw.Size=UDim2.new(0,16,0,16)
sw.BackgroundColor3=C[cd.key]
sw.BorderSizePixel=0
sw.ZIndex=4
sw.Parent=row
applyCornerRadius(5,sw)
applyStroke(1,C.BORDER,0.2,sw)
	local rl=Instance.new("TextLabel")
rl.AnchorPoint=Vector2.new(0,0.5)
rl.Position=UDim2.new(0,32,0.5,0)
rl.Size=UDim2.new(0,90,1,0)
rl.BackgroundTransparency=1
rl.Font=Enum.Font.GothamMedium
rl.Text=cd.label
rl.TextColor3=C.TEXT2
rl.TextXAlignment=Enum.TextXAlignment.Left
rl.TextSize=12
rl.ZIndex=4
rl.Parent=row
	local hb=Instance.new("TextBox")
hb.AnchorPoint=Vector2.new(1,0.5)
hb.Position=UDim2.new(1,-8,0.5,0)
hb.Size=UDim2.new(0,80,0,20)
hb.BackgroundColor3=C.SURFACE
hb.BorderSizePixel=0
hb.Font=Enum.Font.GothamMedium
hb.Text="#"..c32h(C[cd.key])
hb.PlaceholderText="#RRGGBB"
hb.PlaceholderColor3=C.TEXT3
hb.TextColor3=C.ACCENT
hb.TextXAlignment=Enum.TextXAlignment.Center
hb.TextSize=11
hb.ClearTextOnFocus=false
hb.ZIndex=4
hb.Parent=row
applyCornerRadius(6,hb)
applyStroke(1,C.BORDER,0.25,hb)
	local k=cd.key
hb.Focused:Connect(function() hb.Text=hb.Text:gsub("^#","") end)
	hb.FocusLost:Connect(function() local raw=hb.Text:gsub("^#",""):gsub("%s","");local nc=h2c3(raw);if nc then C[k]=nc;sw.BackgroundColor3=nc;hb.Text="#"..c32h(nc);hb.TextColor3=C.ACCENT;applyThemeColors() else hb.Text="#"..c32h(C[k]);hb.TextColor3=C.DANGER;task.delay(1.2,function() hb.TextColor3=C.ACCENT end) end end)
end
local thAnim=false
thHdr.MouseButton1Click:Connect(function()
	if thAnim then return end;thAnim=true;themeExp=not themeExp;thCh.Text=themeExp and "^" or "v";local th=themeExp and Cfg.THEME_PANEL_EXPANDED_HEIGHT or Cfg.THEME_PANEL_COLLAPSED_HEIGHT
	local ti=TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	local tw=Svc.TweenService:Create(UI.themePanel,ti,{Size=UDim2.new(1,0,0,th)})
	tw.Completed:Connect(function() thAnim=false;updateSettingsCanvas() end);tw:Play()
	if UI.kbPanel then
		local shx=St.screenShakeEnabled and Cfg.SHAKE_PANEL_HEIGHT or 0;local lyx=St.lyricsEnabled and 28 or 0
		Svc.TweenService:Create(UI.kbPanel,ti,{Position=UDim2.new(0,0,0,154+lyx+shx+th+6)}):Play()
	end
end)
thHdr.MouseEnter:Connect(function() thHL.TextColor3=C.TEXT end)
thHdr.MouseLeave:Connect(function() thHL.TextColor3=C.TEXT2 end)
do
local KB_ROWS=10
local KBCH=Cfg.THEME_PANEL_COLLAPSED_HEIGHT
local KBEH=KBCH+KB_ROWS*(Cfg.THEME_ROW_HEIGHT+4)+8
local function getKbPanelY() local shx=St.screenShakeEnabled and Cfg.SHAKE_PANEL_HEIGHT or 0
local lyx=St.lyricsEnabled and 28 or 0
return 154+lyx+shx+(themeExp and Cfg.THEME_PANEL_EXPANDED_HEIGHT or Cfg.THEME_PANEL_COLLAPSED_HEIGHT)+6 end
UI.kbPanel=Instance.new("Frame")
UI.kbPanel.Position=UDim2.new(0,0,0,getKbPanelY())
UI.kbPanel.Size=UDim2.new(1,0,0,KBCH)
UI.kbPanel.BackgroundColor3=C.SURFACE
UI.kbPanel.BorderSizePixel=0
UI.kbPanel.ClipsDescendants=true
UI.kbPanel.ZIndex=3
UI.kbPanel.Parent=UI.settingsMainScroll
applyCornerRadius(10,UI.kbPanel)
applyStroke(1,C.BORDER,0.15,UI.kbPanel)
local kbHdr=Instance.new("TextButton")
kbHdr.Size=UDim2.new(1,0,0,KBCH)
kbHdr.BackgroundTransparency=1
kbHdr.AutoButtonColor=false
kbHdr.Font=Enum.Font.GothamMedium
kbHdr.Text=""
kbHdr.ZIndex=4
kbHdr.Parent=UI.kbPanel
local kbHL=Instance.new("TextLabel")
kbHL.AnchorPoint=Vector2.new(0,0.5)
kbHL.Position=UDim2.new(0,12,0.5,0)
kbHL.Size=UDim2.new(0.6,0,1,0)
kbHL.BackgroundTransparency=1
kbHL.Font=Enum.Font.GothamMedium
kbHL.Text="Keybinds"
kbHL.TextColor3=C.TEXT2
kbHL.TextXAlignment=Enum.TextXAlignment.Left
kbHL.TextSize=13
kbHL.ZIndex=4
kbHL.Parent=kbHdr
local kbCh=Instance.new("TextLabel")
kbCh.AnchorPoint=Vector2.new(1,0.5)
kbCh.Position=UDim2.new(1,-12,0.5,0)
kbCh.Size=UDim2.new(0,20,1,0)
kbCh.BackgroundTransparency=1
kbCh.Font=Enum.Font.GothamBold
kbCh.Text="v"
kbCh.TextColor3=C.TEXT3
kbCh.TextXAlignment=Enum.TextXAlignment.Right
kbCh.TextSize=12
kbCh.ZIndex=4
kbCh.Parent=kbHdr
local kbSep=Instance.new("Frame")
kbSep.Position=UDim2.new(0,10,0,KBCH-1)
kbSep.Size=UDim2.new(1,-20,0,1)
kbSep.BackgroundColor3=C.BORDER
kbSep.BorderSizePixel=0
kbSep.ZIndex=3
kbSep.Parent=UI.kbPanel
local kbScr=Instance.new("ScrollingFrame")
kbScr.Position=UDim2.new(0,0,0,KBCH+2)
kbScr.Size=UDim2.new(1,0,1,-(KBCH+2))
kbScr.BackgroundTransparency=1
kbScr.BorderSizePixel=0
kbScr.ScrollBarThickness=3
kbScr.ScrollBarImageColor3=C.ACCENT
kbScr.CanvasSize=UDim2.new(0,0,0,0)
kbScr.ZIndex=3
kbScr.Parent=UI.kbPanel
local kbRL=Instance.new("UIListLayout")
kbRL.Padding=UDim.new(0,4)
kbRL.SortOrder=Enum.SortOrder.LayoutOrder
kbRL.Parent=kbScr
local kbRP=Instance.new("UIPadding")
kbRP.PaddingTop=UDim.new(0,4)
kbRP.PaddingLeft=UDim.new(0,8)
kbRP.PaddingRight=UDim.new(0,8)
kbRP.Parent=kbScr
kbRL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() kbScr.CanvasSize=UDim2.new(0,0,0,kbRL.AbsoluteContentSize.Y+10) end)
local KBDefs={
	{label="Toggle Controller", field="kbToggle"},
	{label="Previous Track",    field="kbPrev"},
	{label="Play / Pause",      field="kbPlay"},
	{label="Next Track",        field="kbNext"},
	{label="Repeat",            field="kbRepeat"},
	{label="Shuffle",           field="kbShuffle"},
	{label="Synced Lyrics",     field="kbLyrics"},
	{label="Translate Lyrics",  field="kbTranslate"},
	{label="Mute Game Sounds",  field="kbMute"},
	{label="Cinematic Mode",    field="kbCinematic"},
}
local kbCapturing=nil
for i,kd in ipairs(KBDefs) do
	local row=Instance.new("Frame")
row.Size=UDim2.new(1,0,0,Cfg.THEME_ROW_HEIGHT)
row.BackgroundColor3=C.ELEVATED
row.BorderSizePixel=0
row.LayoutOrder=i
row.ZIndex=3
row.Parent=kbScr
applyCornerRadius(7,row)
	local rl=Instance.new("TextLabel")
rl.AnchorPoint=Vector2.new(0,0.5)
rl.Position=UDim2.new(0,10,0.5,0)
rl.Size=UDim2.new(0.58,0,1,0)
rl.BackgroundTransparency=1
rl.Font=Enum.Font.GothamMedium
rl.Text=kd.label
rl.TextColor3=C.TEXT2
rl.TextXAlignment=Enum.TextXAlignment.Left
rl.TextSize=12
rl.ZIndex=4
rl.Parent=row
	local kb=Instance.new("TextButton")
kb.AnchorPoint=Vector2.new(1,0.5)
kb.Position=UDim2.new(1,-8,0.5,0)
kb.Size=UDim2.new(0,88,0,20)
kb.BackgroundColor3=C.SURFACE
kb.AutoButtonColor=false
kb.Font=Enum.Font.GothamMedium
kb.TextSize=11
kb.TextColor3=C.ACCENT
kb.BorderSizePixel=0
kb.ZIndex=4
kb.Parent=row
applyCornerRadius(6,kb)
applyStroke(1,C.BORDER,0.25,kb)
	local field=kd.field
	local function refreshBtn()
		local kc=field=="kbToggle" and curKC or St[field]
		kb.Text=kc and kc.Name or "—"
		kb.TextColor3=(kbCapturing==field) and C.TEXT or C.ACCENT
		kb.BackgroundColor3=(kbCapturing==field) and C.ACCENT_DIM or C.SURFACE
	end
	refreshBtn()
	kb.MouseButton1Click:Connect(function()
		if kbCapturing==field then kbCapturing=nil;refreshBtn();return end
		kbCapturing=field
		for _,ch in ipairs(kbScr:GetChildren()) do
			if ch:IsA("Frame") then for _,cb in ipairs(ch:GetChildren()) do if cb:IsA("TextButton") then cb.BackgroundColor3=C.SURFACE;cb.TextColor3=C.ACCENT end end end
		end
		kb.Text="press…";kb.BackgroundColor3=C.ACCENT_DIM;kb.TextColor3=C.TEXT
	end)
	row.Name="KBRow_"..field
end

-- On mobile, toggling with a keybind is not practical.
-- Expose a tap target (the title bar) to show/hide the controller.
if isMobileDevice() then
	UI.dragArea.MouseButton1Click:Connect(function()
		if St.guiOpen then hideController() else showController() end
	end)
end

Svc.UserInput.InputBegan:Connect(function(inp,gp)
	if not kbCapturing then return end
	if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
	local kc=inp.KeyCode;if kc==Enum.KeyCode.Unknown then return end
	if kbCapturing=="kbToggle" then curKC=kc;kbVal.Value=kc.Name
	else St[kbCapturing]=kc end
	saveUserSettings()
	local rowName="KBRow_"..kbCapturing;kbCapturing=nil
	local r=kbScr:FindFirstChild(rowName);if r then for _,cb in ipairs(r:GetChildren()) do if cb:IsA("TextButton") then cb.Text=kc.Name;cb.BackgroundColor3=C.SURFACE;cb.TextColor3=C.ACCENT end end end
end)
local kbAnim2=false
kbHdr.MouseButton1Click:Connect(function()
	if kbAnim2 then return end;kbAnim2=true;kbPanelExp=not kbPanelExp;kbCh.Text=kbPanelExp and "^" or "v"
	local th2=kbPanelExp and KBEH or KBCH
	local tw2=Svc.TweenService:Create(UI.kbPanel,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(1,0,0,th2)})
	tw2.Completed:Connect(function() kbAnim2=false;updateSettingsCanvas() end);tw2:Play()
end)
kbHdr.MouseEnter:Connect(function() kbHL.TextColor3=C.TEXT end)
kbHdr.MouseLeave:Connect(function() kbHL.TextColor3=C.TEXT2 end)
end
do
local dlL=Instance.new("UIListLayout")
dlL.Padding=UDim.new(0,9)
dlL.SortOrder=Enum.SortOrder.LayoutOrder
dlL.HorizontalAlignment=Enum.HorizontalAlignment.Center
dlL.Parent=UI.settingsDownloaderScroll
dlL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() UI.settingsDownloaderScroll.CanvasSize=UDim2.new(0,0,0,dlL.AbsoluteContentSize.Y+20) end)
local dlPad=Instance.new("UIPadding")
dlPad.PaddingBottom=UDim.new(0,8)
dlPad.Parent=UI.settingsDownloaderScroll
local function dlLbl(t,lo) local l=Instance.new("TextLabel")
l.Size=UDim2.new(1,0,0,13)
l.BackgroundTransparency=1
l.Font=Enum.Font.GothamMedium
l.Text=t
l.TextColor3=C.TEXT2
l.TextXAlignment=Enum.TextXAlignment.Left
l.TextSize=11
l.LayoutOrder=lo
l.ZIndex=3
l.Parent=UI.settingsDownloaderScroll
local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,4)
p.PaddingRight=UDim.new(0,4)
p.Parent=l
return l end
local function dlInp(ph,lo) local b=Instance.new("TextBox")
b.Size=UDim2.new(1,0,0,32)
b.BackgroundColor3=C.ELEVATED
b.BorderSizePixel=0
b.Font=Enum.Font.Gotham
b.PlaceholderText=ph
b.Text=""
b.TextColor3=C.TEXT
b.PlaceholderColor3=C.TEXT3
b.TextSize=12
b.ClearTextOnFocus=false
b.LayoutOrder=lo
b.ZIndex=3
b.Parent=UI.settingsDownloaderScroll
applyCornerRadius(8,b)
applyStroke(1,C.BORDER_LIT,0.45,b)
local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,14)
p.PaddingRight=UDim.new(0,14)
p.Parent=b
return b end
local dsh=Instance.new("TextLabel")
dsh.Size=UDim2.new(1,0,0,13)
dsh.BackgroundTransparency=1
dsh.Font=Enum.Font.GothamMedium
dsh.Text="SOUNDCLOUD DOWNLOADER"
dsh.TextColor3=C.TEXT3
dsh.TextXAlignment=Enum.TextXAlignment.Left
dsh.TextSize=9
dsh.LayoutOrder=1
dsh.ZIndex=3
dsh.Parent=UI.settingsDownloaderScroll
do local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,4)
p.Parent=dsh end
local scBtn=Instance.new("TextButton")
scBtn.AnchorPoint=Vector2.new(1,0.5)
scBtn.Position=UDim2.new(1,-4,0.5,0)
scBtn.Size=UDim2.new(0,72,0,18)
scBtn.BackgroundColor3=C.ACCENT_DIM
scBtn.AutoButtonColor=false
scBtn.Font=Enum.Font.GothamSemibold
scBtn.Text="🔗 open"
scBtn.TextColor3=C.ACCENT
scBtn.TextSize=10
scBtn.BorderSizePixel=0
scBtn.ZIndex=4
scBtn.Parent=dsh
applyCornerRadius(5,scBtn)
scBtn.MouseEnter:Connect(function() Svc.TweenService:Create(scBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT,TextColor3=AT}):Play() end)
scBtn.MouseLeave:Connect(function() Svc.TweenService:Create(scBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT_DIM,TextColor3=C.ACCENT}):Play() end)
scBtn.MouseButton1Click:Connect(function()
	local SC_URL="https://soundcloud.com";local opened=false
	if not opened then pcall(function() if typeof(open_url)=="function" then open_url(SC_URL);opened=true end end) end
	if not opened then pcall(function() if typeof(OpenBrowser)=="function" then OpenBrowser(SC_URL);opened=true end end) end
	if not opened then pcall(function() setclipboard(SC_URL) end);local orig=scBtn.Text;scBtn.Text="copied!";scBtn.TextColor3=C.SUCCESS;Svc.TweenService:Create(scBtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(30,60,30)}):Play();task.delay(2,function() scBtn.Text=orig;scBtn.TextColor3=C.ACCENT;Svc.TweenService:Create(scBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT_DIM}):Play() end) end
end)
local ddiv=Instance.new("Frame")
ddiv.Size=UDim2.new(1,0,0,1)
ddiv.BackgroundColor3=C.BORDER
ddiv.BorderSizePixel=0
ddiv.LayoutOrder=2
ddiv.ZIndex=3
ddiv.Parent=UI.settingsDownloaderScroll
UI.dlArtFrame=Instance.new("Frame")
UI.dlArtFrame.Size=UDim2.new(1,0,0,172)
UI.dlArtFrame.BackgroundColor3=Color3.fromRGB(8,6,4)
UI.dlArtFrame.BackgroundTransparency=0
UI.dlArtFrame.BorderSizePixel=0
UI.dlArtFrame.LayoutOrder=3
UI.dlArtFrame.ZIndex=3
UI.dlArtFrame.ClipsDescendants=true
UI.dlArtFrame.Parent=UI.settingsDownloaderScroll
applyCornerRadius(10,UI.dlArtFrame)
UI.dlArtImage=Instance.new("ImageLabel")
UI.dlArtImage.AnchorPoint=Vector2.new(0.5,0.5)
UI.dlArtImage.Position=UDim2.new(0.5,0,0.5,0)
UI.dlArtImage.Size=UDim2.new(1,2,1,2)
UI.dlArtImage.BackgroundTransparency=1
UI.dlArtImage.Image=""
UI.dlArtImage.ScaleType=Enum.ScaleType.Crop
UI.dlArtImage.ImageTransparency=1
UI.dlArtImage.ZIndex=4
UI.dlArtImage.Parent=UI.dlArtFrame
local dlArtGrad=Instance.new("Frame")
dlArtGrad.AnchorPoint=Vector2.new(0,1)
dlArtGrad.Position=UDim2.new(0,0,1,0)
dlArtGrad.Size=UDim2.new(1,0,0.55,0)
dlArtGrad.BackgroundColor3=Color3.new(0,0,0)
dlArtGrad.BackgroundTransparency=0
dlArtGrad.BorderSizePixel=0
dlArtGrad.ZIndex=5
dlArtGrad.Visible=false
dlArtGrad.Parent=UI.dlArtFrame
local dlArtGradG=Instance.new("UIGradient")
dlArtGradG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
dlArtGradG.Rotation=90
dlArtGradG.Parent=dlArtGrad
UI.dlArtTitle=Instance.new("TextLabel")
UI.dlArtTitle.AnchorPoint=Vector2.new(0,1)
UI.dlArtTitle.Position=UDim2.new(0,10,1,-8)
UI.dlArtTitle.Size=UDim2.new(1,-16,0,32)
UI.dlArtTitle.BackgroundTransparency=1
UI.dlArtTitle.Font=Enum.Font.GothamBold
UI.dlArtTitle.Text=""
UI.dlArtTitle.TextColor3=Color3.fromRGB(255,255,255)
UI.dlArtTitle.TextXAlignment=Enum.TextXAlignment.Left
UI.dlArtTitle.TextSize=13
UI.dlArtTitle.TextTruncate=Enum.TextTruncate.AtEnd
UI.dlArtTitle.TextTransparency=1
UI.dlArtTitle.ZIndex=6
UI.dlArtTitle.Parent=UI.dlArtFrame
UI.dlArtPlaceholder=Instance.new("ImageLabel")
UI.dlArtPlaceholder.AnchorPoint=Vector2.new(0.5,0.5)
UI.dlArtPlaceholder.Position=UDim2.new(0.5,0,0.5,0)
UI.dlArtPlaceholder.Size=UDim2.new(1,2,1,2)
UI.dlArtPlaceholder.BackgroundTransparency=1
UI.dlArtPlaceholder.Image="rbxassetid://119441213053262"
UI.dlArtPlaceholder.ScaleType=Enum.ScaleType.Crop
UI.dlArtPlaceholder.ImageTransparency=1
UI.dlArtPlaceholder.ZIndex=4
UI.dlArtPlaceholder.Visible=false
UI.dlArtPlaceholder.Parent=UI.dlArtFrame
UI.dlArtStatusText=Instance.new("TextLabel")
UI.dlArtStatusText.AnchorPoint=Vector2.new(0.5,1)
UI.dlArtStatusText.Position=UDim2.new(0.5,0,1,-8)
UI.dlArtStatusText.Size=UDim2.new(1,-16,0,16)
UI.dlArtStatusText.BackgroundTransparency=1
UI.dlArtStatusText.Font=Enum.Font.GothamMedium
UI.dlArtStatusText.Text=""
UI.dlArtStatusText.TextColor3=Color3.fromRGB(160,140,100)
UI.dlArtStatusText.TextSize=11
UI.dlArtStatusText.ZIndex=6
UI.dlArtStatusText.Parent=UI.dlArtFrame
UI.dlArtHint=Instance.new("TextLabel")
UI.dlArtHint.AnchorPoint=Vector2.new(0.5,0.5)
UI.dlArtHint.Position=UDim2.new(0.5,0,0.5,0)
UI.dlArtHint.Size=UDim2.new(1,-24,0,36)
UI.dlArtHint.BackgroundTransparency=1
UI.dlArtHint.Font=Enum.Font.GothamMedium
UI.dlArtHint.Text="paste a SoundCloud URL\nto load the album cover"
UI.dlArtHint.TextColor3=Color3.fromRGB(80,65,38)
UI.dlArtHint.TextSize=12
UI.dlArtHint.TextWrapped=true
UI.dlArtHint.ZIndex=4
UI.dlArtHint.Parent=UI.dlArtFrame
local dlArtFetchGen=0
local function clearDlArt()
	dlArtFetchGen=dlArtFetchGen+1
UI.dlArtImage.Image=""
	Svc.TweenService:Create(UI.dlArtImage,TweenInfo.new(0.15),{ImageTransparency=1}):Play()
Svc.TweenService:Create(UI.dlArtTitle,TweenInfo.new(0.12),{TextTransparency=1}):Play()
	dlArtGrad.Visible=false
UI.dlArtPlaceholder.Visible=false
UI.dlArtPlaceholder.ImageTransparency=1
UI.dlArtStatusText.Text=""
UI.dlArtHint.Visible=true
end
local function fetchDlArt(url)
	if not url or url:match("^%s*$") then clearDlArt()
return end
	dlArtFetchGen=dlArtFetchGen+1
local gen=dlArtFetchGen
	UI.dlArtImage.Image=""
UI.dlArtImage.ImageTransparency=1
UI.dlArtTitle.TextTransparency=1
dlArtGrad.Visible=false
	UI.dlArtPlaceholder.Visible=true
UI.dlArtPlaceholder.ImageTransparency=0.5
UI.dlArtStatusText.Text="loading…"
UI.dlArtHint.Visible=false
	task.spawn(function()
		local cid,cerr=getSoundCloudClientId();if not cid or gen~=dlArtFetchGen then if gen==dlArtFetchGen then UI.dlArtPlaceholder.Visible=false;UI.dlArtStatusText.Text="could not load artwork" end;return end
		local ok,rr=pcall(function() return request({Url="https://api-v2.soundcloud.com/resolve?url="..stripQ(url).."&client_id="..cid,Method="GET",Headers={["Accept"]="application/json"}}) end)
		if not ok or not rr or rr.StatusCode~=200 or gen~=dlArtFetchGen then if gen==dlArtFetchGen then UI.dlArtPlaceholder.Visible=false;UI.dlArtStatusText.Text="could not load artwork" end;return end
		local ok2,td=pcall(function() return Svc.HttpService:JSONDecode(rr.Body) end)
		if not ok2 or not td or gen~=dlArtFetchGen then if gen==dlArtFetchGen then UI.dlArtPlaceholder.Visible=false;UI.dlArtStatusText.Text="could not load artwork" end;return end
		local artUrl=td.artwork_url or (td.user and td.user.avatar_url) or nil;local trackTitle=td.title or ""
		if not artUrl then UI.dlArtPlaceholder.Visible=false;UI.dlArtStatusText.Text="no artwork found";return end
		artUrl=artUrl:gsub("-large$","-t500x500"):gsub("-large%.jpg","-t500x500.jpg"):gsub("-large%.png","-t500x500.png")
		local iok,imgData=pcall(function() return request({Url=artUrl,Method="GET"}) end)
		if not iok or not imgData or (imgData.StatusCode~=200) or gen~=dlArtFetchGen then if gen==dlArtFetchGen then UI.dlArtPlaceholder.Visible=false;UI.dlArtStatusText.Text="artwork download failed" end;return end
		local body=imgData.Body or "";if #body<100 then UI.dlArtPlaceholder.Visible=false;UI.dlArtStatusText.Text="artwork download failed";return end
		local ext="jpg";if artUrl:lower():find("%.png") then ext="png" end
		local tmpPath="Music Workspace/Configs/dl_art_"..gen.."."..ext
		if not isfolder(Cfg.configsPath) then makefolder(Cfg.configsPath) end
		local wok=safeCall(function() writefile(tmpPath,body) end, "writefile")
		if not wok or gen~=dlArtFetchGen then if gen==dlArtFetchGen then UI.dlArtPlaceholder.Visible=false;UI.dlArtStatusText.Text="artwork save failed" end;return end
		local aok,assetId=pcall(function() return getcustomasset(tmpPath) end)
		if not aok or not assetId or gen~=dlArtFetchGen then if gen==dlArtFetchGen then UI.dlArtPlaceholder.Visible=false;UI.dlArtStatusText.Text="artwork load failed" end;return end
		UI.dlArtImage.Image=assetId;UI.dlArtImage.ImageTransparency=1;UI.dlArtTitle.Text=trackTitle;UI.dlArtTitle.TextTransparency=1;dlArtGrad.Visible=true;UI.dlArtStatusText.Text=""
		Svc.TweenService:Create(UI.dlArtPlaceholder,TweenInfo.new(0.25),{ImageTransparency=1}):Play();task.delay(0.25,function() UI.dlArtPlaceholder.Visible=false end)
		Svc.TweenService:Create(UI.dlArtImage,TweenInfo.new(0.35,Enum.EasingStyle.Quad),{ImageTransparency=0}):Play()
		if trackTitle~="" then Svc.TweenService:Create(UI.dlArtTitle,TweenInfo.new(0.25),{TextTransparency=0}):Play() end
		if trackTitle~="" then UI.dlNameBox.Text=trackTitle end
	end)
end
dlLbl("SoundCloud URL",4)
UI.dlUrlBox=dlInp("https://soundcloud.com/artist/track-name",5)
dlLbl("File Name  (no extension)",6)
UI.dlNameBox=dlInp("e.g.  my_favorite_song",7)
UI.dlStatusPill=Instance.new("Frame")
UI.dlStatusPill.Size=UDim2.new(1,0,0,28)
UI.dlStatusPill.BackgroundColor3=C.SURFACE
UI.dlStatusPill.BorderSizePixel=0
UI.dlStatusPill.LayoutOrder=8
UI.dlStatusPill.ZIndex=3
UI.dlStatusPill.Parent=UI.settingsDownloaderScroll
applyCornerRadius(8,UI.dlStatusPill)
applyStroke(1,C.BORDER,0.25,UI.dlStatusPill)
local dlSD=Instance.new("Frame")
dlSD.AnchorPoint=Vector2.new(0,0.5)
dlSD.Position=UDim2.new(0,10,0.5,0)
dlSD.Size=UDim2.new(0,6,0,6)
dlSD.BackgroundColor3=C.TEXT3
dlSD.BorderSizePixel=0
dlSD.ZIndex=4
dlSD.Parent=UI.dlStatusPill
applyCornerRadius(999,dlSD)
UI.dlStatusLabel=Instance.new("TextLabel")
UI.dlStatusLabel.AnchorPoint=Vector2.new(0,0.5)
UI.dlStatusLabel.Position=UDim2.new(0,24,0.5,0)
UI.dlStatusLabel.Size=UDim2.new(1,-32,1,0)
UI.dlStatusLabel.BackgroundTransparency=1
UI.dlStatusLabel.Font=Enum.Font.GothamMedium
UI.dlStatusLabel.Text="Ready to download"
UI.dlStatusLabel.TextColor3=C.TEXT3
UI.dlStatusLabel.TextXAlignment=Enum.TextXAlignment.Left
UI.dlStatusLabel.TextSize=11
UI.dlStatusLabel.TextTruncate=Enum.TextTruncate.AtEnd
UI.dlStatusLabel.ZIndex=4
UI.dlStatusLabel.Parent=UI.dlStatusPill
UI.dlButton=Instance.new("TextButton")
UI.dlButton.Size=UDim2.new(1,0,0,36)
UI.dlButton.BackgroundColor3=C.ACCENT
UI.dlButton.AutoButtonColor=false
UI.dlButton.Font=Enum.Font.GothamSemibold
UI.dlButton.Text="⬇  Download & Add to Library"
UI.dlButton.TextColor3=AT
UI.dlButton.TextSize=13
UI.dlButton.BorderSizePixel=0
UI.dlButton.LayoutOrder=9
UI.dlButton.ZIndex=3
UI.dlButton.Parent=UI.settingsDownloaderScroll
applyCornerRadius(10,UI.dlButton)
UI.dlButton.MouseEnter:Connect(function() Svc.TweenService:Create(UI.dlButton,TweenInfo.new(0.12),{BackgroundColor3=C.BORDER_LIT}):Play() end)
UI.dlButton.MouseLeave:Connect(function() Svc.TweenService:Create(UI.dlButton,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT}):Play() end)
local dlNote=Instance.new("TextLabel")
dlNote.Size=UDim2.new(1,0,0,28)
dlNote.BackgroundTransparency=1
dlNote.Font=Enum.Font.Gotham
dlNote.Text="Saves to  Music Workspace/Musics/  and appears\nautomatically in your library within ~2 seconds."
dlNote.TextColor3=C.TEXT3
dlNote.TextXAlignment=Enum.TextXAlignment.Left
dlNote.TextSize=10
dlNote.TextWrapped=true
dlNote.LayoutOrder=10
dlNote.ZIndex=3
dlNote.Parent=UI.settingsDownloaderScroll
local function setDlSt(msg,col,dc) UI.dlStatusLabel.Text=msg
UI.dlStatusLabel.TextColor3=col or C.TEXT3
dlSD.BackgroundColor3=dc or col or C.TEXT3 end
local dlBusy=false
UI.dlUrlBox.FocusLost:Connect(function()
	local url=UI.dlUrlBox.Text:match("^%s*(.-)%s*$")
	if url~="" and url:lower():find("soundcloud.com",1,true) then fetchDlArt(url) elseif url=="" then clearDlArt();UI.dlNameBox.Text="" end
end)
UI.dlUrlBox:GetPropertyChangedSignal("Text"):Connect(function() local url=UI.dlUrlBox.Text:match("^%s*(.-)%s*$");if url=="" then UI.dlNameBox.Text="";clearDlArt() end end)
resetDownloader=function()
	if dlBusy then return end
	local ft=TweenInfo.new(0.18,Enum.EasingStyle.Quad)
	Svc.TweenService:Create(UI.dlUrlBox,ft,{TextTransparency=1}):Play()
	Svc.TweenService:Create(UI.dlNameBox,ft,{TextTransparency=1}):Play()
	task.delay(0.18,function()
		UI.dlUrlBox.Text="";UI.dlNameBox.Text=""
		Svc.TweenService:Create(UI.dlUrlBox,ft,{TextTransparency=0}):Play()
		Svc.TweenService:Create(UI.dlNameBox,ft,{TextTransparency=0}):Play()
	end)
	Svc.TweenService:Create(UI.dlButton,TweenInfo.new(0.15),{BackgroundColor3=C.ACCENT}):Play()
	UI.dlButton.Text="⬇  Download & Add to Library"
	setDlSt("Ready to download",C.TEXT3,C.TEXT3)
clearDlArt()
end
UI.dlButton.MouseButton1Click:Connect(function()
	if dlBusy then return end
	local url=UI.dlUrlBox.Text:match("^%s*(.-)%s*$");if url=="" then setDlSt("⚠  Please paste a SoundCloud URL",C.DANGER);return end
	if not url:lower():find("soundcloud.com",1,true) then setDlSt("⚠  Only SoundCloud links are supported",C.DANGER);return end
	local nameHint=UI.dlNameBox.Text:match("^%s*(.-)%s*$");dlBusy=true
	Svc.TweenService:Create(UI.dlButton,TweenInfo.new(0.15),{BackgroundColor3=C.ACCENT_DIM}):Play();UI.dlButton.Text="Downloading…"
	task.spawn(function()
		local function dlDone() Svc.TweenService:Create(UI.dlButton,TweenInfo.new(0.15),{BackgroundColor3=C.ACCENT}):Play();UI.dlButton.Text="⬇  Download & Add to Library";dlBusy=false end
		local ad,err,scTitle=downloadSoundCloudTrack(url,function(msg) setDlSt(msg,C.ACCENT,C.ACCENT) end)
		if not ad then setDlSt("✗  "..(err or "Unknown error"),C.DANGER,C.DANGER);dlDone();return end
		local name=nameHint;if name=="" then name=(scTitle and scTitle~="") and scTitle or "untitled_track";UI.dlNameBox.Text=name end
		local safeName=makeSafeFilename(name);local candidate=safeName;local counter=1
		while isfile(Cfg.workspacePath.."/"..candidate..".mp3") do candidate=safeName.."_"..counter;counter=counter+1 end;safeName=candidate
		local op=Cfg.workspacePath.."/"..safeName..".mp3";local newFileName=safeName..".mp3";dlDone()
		setDlSt("Saving to disk…",C.ACCENT,C.ACCENT)
		local wok,we=safeCall(function() writefile(op,ad) end, "writefile")
		if not wok then setDlSt("✗  Save failed: "..tostring(we),C.DANGER,C.DANGER);return end
		setDlSt("✓  "..name.."  saved!",C.SUCCESS,C.SUCCESS);showTrackNotification(name,false)
		task.delay(2,function() setDlSt("Ready to download",C.TEXT3,C.TEXT3);UI.dlUrlBox.Text="";UI.dlNameBox.Text="";clearDlArt() end)
		displayNamesMap[safeName]=name;saveDisplayNameMap();Dat.suppressAutoNotify[newFileName]=true;Dat.lastMp3Files=scanMusicDirectory()
		local alreadyIn=false;for _,t in ipairs(Dat.trackList) do if t.FileName==newFileName then alreadyIn=true;break end end
		if not alreadyIn then
			local newIdx=#Dat.trackList+1;table.insert(Dat.trackList,{Path=op,DisplayName=name,FullName=name,FileName=newFileName,Type="mp3"});table.insert(Dat.createdSounds,false)
			if Dat.rebuildTrackListUI then Dat.rebuildTrackListUI() end
			task.defer(function()
					local ref=Dat.listButtonRefs[newFileName];local btn=ref and ref.btn
					if btn and btn.Parent then
						local btnY=btn.AbsolutePosition.Y-UI.listScroll.AbsolutePosition.Y+UI.listScroll.CanvasPosition.Y
						local targetY=math.max(0,math.min(btnY-UI.listScroll.AbsoluteSize.Y+38,UI.listScroll.CanvasSize.Y.Offset-UI.listScroll.AbsoluteSize.Y))
						UI.listScroll.CanvasPosition=Vector2.new(0,targetY)
						local tw=Svc.TweenService:Create(btn,TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{BackgroundColor3=C.ACCENT});tw:Play()
						local done=false;local cc;cc=btn.MouseButton1Click:Connect(function() if not done then done=true;cc:Disconnect();tw:Cancel();if btn.Parent then Svc.TweenService:Create(btn,TweenInfo.new(0.3),{BackgroundColor3=C.SURFACE}):Play() end end end)
						task.delay(5,function() if not done then done=true;pcall(function() cc:Disconnect() end);tw:Cancel();if btn.Parent then Svc.TweenService:Create(btn,TweenInfo.new(0.3),{BackgroundColor3=C.SURFACE}):Play() end end end)
					end
				end)
			task.spawn(function()
				local ns=Instance.new("Sound");ns.Name=name;local ok,au=pcall(function() return getcustomasset(op) end)
				if not ok or not au or au=="" then task.wait(1);ok,au=pcall(function() return getcustomasset(op) end) end
				if ok and au and au~="" then ns.SoundId=au;ns.Volume=St.currentVolume;ns.PlaybackSpeed=(St.currentSpeed<=0) and 0.01 or St.currentSpeed;ns.Looped=false;ns.Parent=soundsFolder;Dat.createdSounds[newIdx]=ns;attachVolumeGuard(ns);if Dat.rebuildTrackListUI then Dat.rebuildTrackListUI() end
				else ns:Destroy();pcall(function() loadAllMusicTracks(true);rebuildCategoryTrackIndices();saveCategoriesToDisk();for _,s in ipairs(Dat.createdSounds) do if s and s~=false then attachVolumeGuard(s) end end;Dat.lastMp3Files=scanMusicDirectory() end);if Dat.rebuildTrackListUI then Dat.rebuildTrackListUI() end end
			end)
		else if Dat.rebuildTrackListUI then Dat.rebuildTrackListUI() end end
	end)
end)
end
do
local scSL=Instance.new("UIListLayout")
scSL.Padding=UDim.new(0,9)
scSL.SortOrder=Enum.SortOrder.LayoutOrder
scSL.HorizontalAlignment=Enum.HorizontalAlignment.Center
scSL.Parent=UI.settingsScSearchScroll
scSL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() UI.settingsScSearchScroll.CanvasSize=UDim2.new(0,0,0,scSL.AbsoluteContentSize.Y+20) end)
local scSPad=Instance.new("UIPadding")
scSPad.PaddingBottom=UDim.new(0,8)
scSPad.Parent=UI.settingsScSearchScroll
local scHdrRow=Instance.new("Frame")
scHdrRow.Size=UDim2.new(1,0,0,13)
scHdrRow.BackgroundTransparency=1
scHdrRow.LayoutOrder=1
scHdrRow.ZIndex=3
scHdrRow.Parent=UI.settingsScSearchScroll
local scHdrL=Instance.new("TextLabel")
scHdrL.Size=UDim2.new(1,-4,1,0)
scHdrL.Position=UDim2.new(0,4,0,0)
scHdrL.BackgroundTransparency=1
scHdrL.Font=Enum.Font.GothamMedium
scHdrL.Text="SOUNDCLOUD SEARCH"
scHdrL.TextColor3=C.TEXT3
scHdrL.TextXAlignment=Enum.TextXAlignment.Left
scHdrL.TextSize=9
scHdrL.ZIndex=3
scHdrL.Parent=scHdrRow
local scDivider=Instance.new("Frame")
scDivider.Size=UDim2.new(1,0,0,1)
scDivider.BackgroundColor3=C.BORDER
scDivider.BorderSizePixel=0
scDivider.LayoutOrder=2
scDivider.ZIndex=3
scDivider.Parent=UI.settingsScSearchScroll
local scNavRow=Instance.new("Frame")
scNavRow.Size=UDim2.new(1,0,0,32)
scNavRow.BackgroundTransparency=1
scNavRow.LayoutOrder=3
scNavRow.ZIndex=3
scNavRow.Parent=UI.settingsScSearchScroll
UI.scPrevBtn=Instance.new("TextButton")
UI.scPrevBtn.Size=UDim2.new(0,80,1,-2)
UI.scPrevBtn.AnchorPoint=Vector2.new(0,0.5)
UI.scPrevBtn.Position=UDim2.new(0,0,0.5,0)
UI.scPrevBtn.BackgroundColor3=C.SURFACE
UI.scPrevBtn.AutoButtonColor=false
UI.scPrevBtn.Font=Enum.Font.GothamSemibold
UI.scPrevBtn.Text="← Prev"
UI.scPrevBtn.TextColor3=C.TEXT2
UI.scPrevBtn.TextSize=12
UI.scPrevBtn.BorderSizePixel=0
UI.scPrevBtn.ZIndex=3
UI.scPrevBtn.Parent=scNavRow
applyCornerRadius(8,UI.scPrevBtn)
applyStroke(1,C.BORDER,0.2,UI.scPrevBtn)
UI.scCounterLabel=Instance.new("TextLabel")
UI.scCounterLabel.AnchorPoint=Vector2.new(0.5,0.5)
UI.scCounterLabel.Position=UDim2.new(0.5,0,0.5,0)
UI.scCounterLabel.Size=UDim2.new(0,100,1,0)
UI.scCounterLabel.BackgroundTransparency=1
UI.scCounterLabel.Font=Enum.Font.GothamSemibold
UI.scCounterLabel.Text="0 / 0"
UI.scCounterLabel.TextColor3=C.TEXT3
UI.scCounterLabel.TextSize=13
UI.scCounterLabel.ZIndex=3
UI.scCounterLabel.Parent=scNavRow
UI.scNextBtn=Instance.new("TextButton")
UI.scNextBtn.Size=UDim2.new(0,80,1,-2)
UI.scNextBtn.AnchorPoint=Vector2.new(1,0.5)
UI.scNextBtn.Position=UDim2.new(1,0,0.5,0)
UI.scNextBtn.BackgroundColor3=C.SURFACE
UI.scNextBtn.AutoButtonColor=false
UI.scNextBtn.Font=Enum.Font.GothamSemibold
UI.scNextBtn.Text="Next →"
UI.scNextBtn.TextColor3=C.TEXT2
UI.scNextBtn.TextSize=12
UI.scNextBtn.BorderSizePixel=0
UI.scNextBtn.ZIndex=3
UI.scNextBtn.Parent=scNavRow
applyCornerRadius(8,UI.scNextBtn)
applyStroke(1,C.BORDER,0.2,UI.scNextBtn)
for _,b in ipairs({UI.scPrevBtn,UI.scNextBtn}) do
	b.MouseEnter:Connect(function() if #St.scResults>0 then Svc.TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=C.ELEVATED,TextColor3=C.TEXT}):Play() end end)
	b.MouseLeave:Connect(function() Svc.TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=C.SURFACE,TextColor3=C.TEXT2}):Play() end)
end
UI.scArtFrame=Instance.new("Frame")
UI.scArtFrame.Size=UDim2.new(1,0,0,172)
UI.scArtFrame.BackgroundColor3=Color3.fromRGB(8,6,4)
UI.scArtFrame.BorderSizePixel=0
UI.scArtFrame.LayoutOrder=4
UI.scArtFrame.ZIndex=3
UI.scArtFrame.ClipsDescendants=true
UI.scArtFrame.Parent=UI.settingsScSearchScroll
applyCornerRadius(10,UI.scArtFrame)
UI.scArtImage=Instance.new("ImageLabel")
UI.scArtImage.AnchorPoint=Vector2.new(0.5,0.5)
UI.scArtImage.Position=UDim2.new(0.5,0,0.5,0)
UI.scArtImage.Size=UDim2.new(1,2,1,2)
UI.scArtImage.BackgroundTransparency=1
UI.scArtImage.Image=""
UI.scArtImage.ScaleType=Enum.ScaleType.Crop
UI.scArtImage.ImageTransparency=1
UI.scArtImage.ZIndex=4
UI.scArtImage.Parent=UI.scArtFrame
local scArtGrad=Instance.new("Frame")
scArtGrad.AnchorPoint=Vector2.new(0,1)
scArtGrad.Position=UDim2.new(0,0,1,0)
scArtGrad.Size=UDim2.new(1,0,0.55,0)
scArtGrad.BackgroundColor3=Color3.new(0,0,0)
scArtGrad.BackgroundTransparency=0
scArtGrad.BorderSizePixel=0
scArtGrad.ZIndex=5
scArtGrad.Visible=false
scArtGrad.Parent=UI.scArtFrame
local scArtGradG=Instance.new("UIGradient")
scArtGradG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
scArtGradG.Rotation=90
scArtGradG.Parent=scArtGrad
UI.scArtTitleLabel=Instance.new("TextLabel")
UI.scArtTitleLabel.AnchorPoint=Vector2.new(0,1)
UI.scArtTitleLabel.Position=UDim2.new(0,10,1,-8)
UI.scArtTitleLabel.Size=UDim2.new(1,-16,0,32)
UI.scArtTitleLabel.BackgroundTransparency=1
UI.scArtTitleLabel.Font=Enum.Font.GothamBold
UI.scArtTitleLabel.Text=""
UI.scArtTitleLabel.TextColor3=Color3.fromRGB(255,255,255)
UI.scArtTitleLabel.TextXAlignment=Enum.TextXAlignment.Left
UI.scArtTitleLabel.TextSize=13
UI.scArtTitleLabel.TextTruncate=Enum.TextTruncate.AtEnd
UI.scArtTitleLabel.TextTransparency=1
UI.scArtTitleLabel.ZIndex=6
UI.scArtTitleLabel.Parent=UI.scArtFrame
local scArtPlaceholder=Instance.new("ImageLabel")
scArtPlaceholder.AnchorPoint=Vector2.new(0.5,0.5)
scArtPlaceholder.Position=UDim2.new(0.5,0,0.5,0)
scArtPlaceholder.Size=UDim2.new(1,2,1,2)
scArtPlaceholder.BackgroundTransparency=1
scArtPlaceholder.Image="rbxassetid://119441213053262"
scArtPlaceholder.ScaleType=Enum.ScaleType.Crop
scArtPlaceholder.ImageTransparency=1
scArtPlaceholder.ZIndex=4
scArtPlaceholder.Visible=false
scArtPlaceholder.Parent=UI.scArtFrame
UI.scArtStatus=Instance.new("TextLabel")
UI.scArtStatus.AnchorPoint=Vector2.new(0.5,1)
UI.scArtStatus.Position=UDim2.new(0.5,0,1,-8)
UI.scArtStatus.Size=UDim2.new(1,-16,0,16)
UI.scArtStatus.BackgroundTransparency=1
UI.scArtStatus.Font=Enum.Font.GothamMedium
UI.scArtStatus.Text=""
UI.scArtStatus.TextColor3=Color3.fromRGB(160,140,100)
UI.scArtStatus.TextSize=11
UI.scArtStatus.ZIndex=6
UI.scArtStatus.Parent=UI.scArtFrame
local scArtHint=Instance.new("TextLabel")
scArtHint.AnchorPoint=Vector2.new(0.5,0.5)
scArtHint.Position=UDim2.new(0.5,0,0.5,0)
scArtHint.Size=UDim2.new(1,-24,0,36)
scArtHint.BackgroundTransparency=1
scArtHint.Font=Enum.Font.GothamMedium
scArtHint.Text="type a song title and press Search\nto find it on SoundCloud"
scArtHint.TextColor3=Color3.fromRGB(80,65,38)
scArtHint.TextSize=12
scArtHint.TextWrapped=true
scArtHint.ZIndex=4
scArtHint.Parent=UI.scArtFrame
local scQLbl=Instance.new("TextLabel")
scQLbl.Size=UDim2.new(1,0,0,13)
scQLbl.BackgroundTransparency=1
scQLbl.Font=Enum.Font.GothamMedium
scQLbl.Text="Song Title"
scQLbl.TextColor3=C.TEXT2
scQLbl.TextXAlignment=Enum.TextXAlignment.Left
scQLbl.TextSize=11
scQLbl.LayoutOrder=5
scQLbl.ZIndex=3
scQLbl.Parent=UI.settingsScSearchScroll
do local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,4)
p.PaddingRight=UDim.new(0,4)
p.Parent=scQLbl end
local scQueryRow=Instance.new("Frame")
scQueryRow.Size=UDim2.new(1,0,0,32)
scQueryRow.BackgroundTransparency=1
scQueryRow.LayoutOrder=6
scQueryRow.ZIndex=3
scQueryRow.Parent=UI.settingsScSearchScroll
UI.scQueryBox=Instance.new("TextBox")
UI.scQueryBox.Size=UDim2.new(1,-82,1,0)
UI.scQueryBox.BackgroundColor3=C.ELEVATED
UI.scQueryBox.BorderSizePixel=0
UI.scQueryBox.Font=Enum.Font.Gotham
UI.scQueryBox.PlaceholderText="e.g.  Bohemian Rhapsody"
UI.scQueryBox.Text=""
UI.scQueryBox.TextColor3=C.TEXT
UI.scQueryBox.PlaceholderColor3=C.TEXT3
UI.scQueryBox.TextSize=12
UI.scQueryBox.ClearTextOnFocus=false
UI.scQueryBox.ZIndex=3
UI.scQueryBox.Parent=scQueryRow
applyCornerRadius(8,UI.scQueryBox)
applyStroke(1,C.BORDER_LIT,0.45,UI.scQueryBox)
do local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,14)
p.PaddingRight=UDim.new(0,8)
p.Parent=UI.scQueryBox end
UI.scSearchBtn=Instance.new("TextButton")
UI.scSearchBtn.AnchorPoint=Vector2.new(1,0.5)
UI.scSearchBtn.Position=UDim2.new(1,0,0.5,0)
UI.scSearchBtn.Size=UDim2.new(0,76,1,-2)
UI.scSearchBtn.BackgroundColor3=C.ACCENT
UI.scSearchBtn.AutoButtonColor=false
UI.scSearchBtn.Font=Enum.Font.GothamSemibold
UI.scSearchBtn.Text="Search"
UI.scSearchBtn.TextColor3=AT
UI.scSearchBtn.TextSize=12
UI.scSearchBtn.BorderSizePixel=0
UI.scSearchBtn.ZIndex=3
UI.scSearchBtn.Parent=scQueryRow
applyCornerRadius(8,UI.scSearchBtn)
UI.scSearchBtn.MouseEnter:Connect(function() Svc.TweenService:Create(UI.scSearchBtn,TweenInfo.new(0.12),{BackgroundColor3=C.BORDER_LIT}):Play() end)
UI.scSearchBtn.MouseLeave:Connect(function() Svc.TweenService:Create(UI.scSearchBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT}):Play() end)
UI.scStatusPill=Instance.new("Frame")
UI.scStatusPill.Size=UDim2.new(1,0,0,28)
UI.scStatusPill.BackgroundColor3=C.SURFACE
UI.scStatusPill.BorderSizePixel=0
UI.scStatusPill.LayoutOrder=7
UI.scStatusPill.ZIndex=3
UI.scStatusPill.Parent=UI.settingsScSearchScroll
applyCornerRadius(8,UI.scStatusPill)
applyStroke(1,C.BORDER,0.25,UI.scStatusPill)
UI.scSDot=Instance.new("Frame")
UI.scSDot.AnchorPoint=Vector2.new(0,0.5)
UI.scSDot.Position=UDim2.new(0,10,0.5,0)
UI.scSDot.Size=UDim2.new(0,6,0,6)
UI.scSDot.BackgroundColor3=C.TEXT3
UI.scSDot.BorderSizePixel=0
UI.scSDot.ZIndex=4
UI.scSDot.Parent=UI.scStatusPill
applyCornerRadius(999,UI.scSDot)
UI.scStatusLabel=Instance.new("TextLabel")
UI.scStatusLabel.AnchorPoint=Vector2.new(0,0.5)
UI.scStatusLabel.Position=UDim2.new(0,24,0.5,0)
UI.scStatusLabel.Size=UDim2.new(1,-32,1,0)
UI.scStatusLabel.BackgroundTransparency=1
UI.scStatusLabel.Font=Enum.Font.GothamMedium
UI.scStatusLabel.Text="Enter a song title to search"
UI.scStatusLabel.TextColor3=C.TEXT3
UI.scStatusLabel.TextXAlignment=Enum.TextXAlignment.Left
UI.scStatusLabel.TextSize=11
UI.scStatusLabel.TextTruncate=Enum.TextTruncate.AtEnd
UI.scStatusLabel.ZIndex=4
UI.scStatusLabel.Parent=UI.scStatusPill
local scUrlLbl=Instance.new("TextLabel")
scUrlLbl.Size=UDim2.new(1,0,0,13)
scUrlLbl.BackgroundTransparency=1
scUrlLbl.Font=Enum.Font.GothamMedium
scUrlLbl.Text="SoundCloud URL"
scUrlLbl.TextColor3=C.TEXT2
scUrlLbl.TextXAlignment=Enum.TextXAlignment.Left
scUrlLbl.TextSize=11
scUrlLbl.LayoutOrder=8
scUrlLbl.ZIndex=3
scUrlLbl.Parent=UI.settingsScSearchScroll
do local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,4)
p.PaddingRight=UDim.new(0,4)
p.Parent=scUrlLbl end
UI.scUrlRow=Instance.new("Frame")
UI.scUrlRow.Size=UDim2.new(1,0,0,32)
UI.scUrlRow.BackgroundTransparency=1
UI.scUrlRow.LayoutOrder=9
UI.scUrlRow.ZIndex=3
UI.scUrlRow.Parent=UI.settingsScSearchScroll
UI.scUrlBox=Instance.new("TextBox")
UI.scUrlBox.Size=UDim2.new(1,-82,1,0)
UI.scUrlBox.BackgroundColor3=C.ELEVATED
UI.scUrlBox.BorderSizePixel=0
UI.scUrlBox.Font=Enum.Font.Gotham
UI.scUrlBox.PlaceholderText="search result will appear here"
UI.scUrlBox.Text=""
UI.scUrlBox.TextColor3=C.ACCENT
UI.scUrlBox.PlaceholderColor3=C.TEXT3
UI.scUrlBox.TextSize=11
UI.scUrlBox.ClearTextOnFocus=false
UI.scUrlBox.TextEditable=false
UI.scUrlBox.TextTruncate=Enum.TextTruncate.AtEnd
UI.scUrlBox.ClipsDescendants=true
UI.scUrlBox.ZIndex=3
UI.scUrlBox.Parent=UI.scUrlRow
applyCornerRadius(8,UI.scUrlBox)
applyStroke(1,C.BORDER_LIT,0.45,UI.scUrlBox)
do local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,10)
p.PaddingRight=UDim.new(0,8)
p.Parent=UI.scUrlBox end
UI.scCopyBtn=Instance.new("TextButton")
UI.scCopyBtn.AnchorPoint=Vector2.new(1,0.5)
UI.scCopyBtn.Position=UDim2.new(1,0,0.5,0)
UI.scCopyBtn.Size=UDim2.new(0,76,1,-2)
UI.scCopyBtn.BackgroundColor3=C.ELEVATED
UI.scCopyBtn.AutoButtonColor=false
UI.scCopyBtn.Font=Enum.Font.GothamSemibold
UI.scCopyBtn.Text="Copy"
UI.scCopyBtn.TextColor3=C.TEXT2
UI.scCopyBtn.TextSize=12
UI.scCopyBtn.BorderSizePixel=0
UI.scCopyBtn.ZIndex=3
UI.scCopyBtn.Parent=UI.scUrlRow
applyCornerRadius(8,UI.scCopyBtn)
applyStroke(1,C.BORDER_LIT,0.3,UI.scCopyBtn)
UI.scCopyBtn.MouseEnter:Connect(function() Svc.TweenService:Create(UI.scCopyBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT_DIM,TextColor3=C.ACCENT}):Play() end)
UI.scCopyBtn.MouseLeave:Connect(function() Svc.TweenService:Create(UI.scCopyBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ELEVATED,TextColor3=C.TEXT2}):Play() end)
UI.scCopyBtn.MouseButton1Click:Connect(function()
	local url=UI.scUrlBox.Text;if url=="" then return end
	pcall(function() setclipboard(url) end)
	local orig=UI.scCopyBtn.Text;UI.scCopyBtn.Text="Copied!";UI.scCopyBtn.TextColor3=C.SUCCESS
	Svc.TweenService:Create(UI.scCopyBtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(20,50,20)}):Play()
	task.delay(1.8,function() UI.scCopyBtn.Text=orig;UI.scCopyBtn.TextColor3=C.TEXT2;Svc.TweenService:Create(UI.scCopyBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ELEVATED}):Play() end)
end)
local function setSoundCloudStatus(msg,col)
	UI.scStatusLabel.Text=msg
local c=col or C.TEXT3
UI.scStatusLabel.TextColor3=c
if UI.scSDot then UI.scSDot.BackgroundColor3=c end
end
local function clearSoundCloudArtwork()
	St.scArtGen=St.scArtGen+1
UI.scArtImage.Image=""
	Svc.TweenService:Create(UI.scArtImage,TweenInfo.new(0.15),{ImageTransparency=1}):Play()
	Svc.TweenService:Create(UI.scArtTitleLabel,TweenInfo.new(0.12),{TextTransparency=1}):Play()
	scArtGrad.Visible=false
scArtPlaceholder.Visible=false
UI.scArtStatus.Text=""
scArtHint.Visible=true
end
local function fetchSoundCloudArtwork(result)
	if not result then clearSoundCloudArtwork()
return end
	St.scArtGen=St.scArtGen+1
local gen=St.scArtGen
	UI.scArtImage.Image=""
UI.scArtImage.ImageTransparency=1
UI.scArtTitleLabel.TextTransparency=1
	scArtGrad.Visible=false
scArtPlaceholder.Visible=true
scArtPlaceholder.ImageTransparency=0.5
UI.scArtStatus.Text="loading art…"
scArtHint.Visible=false
	local trackTitle=result.title or ""
local artUrl=result.artwork_url or (result.user and result.user.avatar_url) or nil
	if not artUrl then
		scArtPlaceholder.Visible=false
UI.scArtStatus.Text="no artwork"
		if trackTitle~="" then UI.scArtTitleLabel.Text=trackTitle
scArtGrad.Visible=true
Svc.TweenService:Create(UI.scArtTitleLabel,TweenInfo.new(0.25),{TextTransparency=0}):Play() end
		return
	end
	artUrl=artUrl:gsub("-large$","-t500x500"):gsub("-large%.jpg","-t500x500.jpg"):gsub("-large%.png","-t500x500.png")
	task.spawn(function()
		local iok,imgData=pcall(function() return request({Url=artUrl,Method="GET"}) end)
		if not iok or not imgData or imgData.StatusCode~=200 or gen~=St.scArtGen then
			if gen==St.scArtGen then scArtPlaceholder.Visible=false;UI.scArtStatus.Text="art unavailable" end;return
		end
		local body=imgData.Body or "";if #body<100 then scArtPlaceholder.Visible=false;UI.scArtStatus.Text="art unavailable";return end
		local ext="jpg";if artUrl:lower():find("%.png") then ext="png" end
		local tmpPath="Music Workspace/Configs/sc_art_"..gen.."_"..math.floor(tick())%99999 .."."..ext
		if not isfolder(Cfg.configsPath) then makefolder(Cfg.configsPath) end
		local wok=safeCall(function() writefile(tmpPath,body) end, "writefile")
		if not wok or gen~=St.scArtGen then if gen==St.scArtGen then scArtPlaceholder.Visible=false;UI.scArtStatus.Text="art save failed" end;return end
		local aok,assetId=pcall(function() return getcustomasset(tmpPath) end)
		if not aok or not assetId or gen~=St.scArtGen then if gen==St.scArtGen then scArtPlaceholder.Visible=false;UI.scArtStatus.Text="art load failed" end;return end
		UI.scArtImage.Image=assetId;UI.scArtImage.ImageTransparency=1
		if trackTitle~="" then UI.scArtTitleLabel.Text=trackTitle;scArtGrad.Visible=true;UI.scArtTitleLabel.TextTransparency=1 end
		UI.scArtStatus.Text=""
		Svc.TweenService:Create(scArtPlaceholder,TweenInfo.new(0.25),{ImageTransparency=1}):Play();task.delay(0.25,function() scArtPlaceholder.Visible=false end)
		Svc.TweenService:Create(UI.scArtImage,TweenInfo.new(0.35,Enum.EasingStyle.Quad),{ImageTransparency=0}):Play()
		if trackTitle~="" then scArtGrad.Visible=true;Svc.TweenService:Create(UI.scArtTitleLabel,TweenInfo.new(0.25),{TextTransparency=0}):Play() end
	end)
end
local function updateSoundCloudResultDisplay()
	local total=#St.scResults
	if total==0 then UI.scCounterLabel.Text="0 / 0"
UI.scUrlBox.Text=""
clearSoundCloudArtwork()
return end
	local idx=St.scIdx
local result=St.scResults[idx]
	UI.scCounterLabel.Text=idx.." / "..total
UI.scCounterLabel.TextColor3=C.ACCENT
	UI.scUrlBox.Text=result.permalink_url or ""
	local policy=(result.policy or ""):upper()
	local isSnipped=policy=="SNIPPED" or (result.duration and result.full_duration and result.full_duration>0 and result.duration<result.full_duration and result.duration<=31000)
	if isSnipped then setSoundCloudStatus("GO+ track — 30s preview only",C.DANGER) else setSoundCloudStatus("",C.TEXT3) end
	fetchSoundCloudArtwork(result)
	UI.scPrevBtn.TextColor3=(idx>1) and C.TEXT2 or C.TEXT3
UI.scNextBtn.TextColor3=(idx<total) and C.TEXT2 or C.TEXT3
end
local function executeSoundCloudSearch()
	local query=UI.scQueryBox.Text:match("^%s*(.-)%s*$")
if query=="" then setSoundCloudStatus("Enter a song title first",C.DANGER)
return end
	if St.scBusy then return end
St.scBusy=true
St.scGen=St.scGen+1
local gen=St.scGen
	setSoundCloudStatus("Fetching client_id…",C.ACCENT)
UI.scSearchBtn.Text="…"
UI.scSearchBtn.BackgroundColor3=C.ACCENT_DIM
	clearSoundCloudArtwork()
St.scResults={}
St.scIdx=1
UI.scCounterLabel.Text="…"
UI.scUrlBox.Text=""
	task.spawn(function()
		local cid=St.scCid
		if not cid then
			local newCid,err=getSoundCloudClientId()
			if not newCid or gen~=St.scGen then
				if gen==St.scGen then setSoundCloudStatus("client_id error: "..(err or "?"),C.DANGER);UI.scSearchBtn.Text="Search";UI.scSearchBtn.BackgroundColor3=C.ACCENT;UI.scCounterLabel.Text="0 / 0" end
				St.scBusy=false;return
			end
			St.scCid=newCid;cid=newCid
		end
		if gen~=St.scGen then St.scBusy=false;return end
		setSoundCloudStatus("Searching…",C.ACCENT)
		local encQ=urlEncode(query)
		local searchUrl="https://api-v2.soundcloud.com/search/tracks?q="..encQ.."&client_id="..cid.."&limit=20&linked_partitioning=1"
		local ok,resp=pcall(function() return request({Url=searchUrl,Method="GET",Headers={["Accept"]="application/json",["User-Agent"]="Mozilla/5.0"}}) end)
		if gen~=St.scGen then St.scBusy=false;return end
		if not ok or not resp then
			St.scCid=nil;setSoundCloudStatus("Retrying with fresh client_id…",C.ACCENT)
			local newCid2,err2=getSoundCloudClientId()
			if not newCid2 or gen~=St.scGen then
				if gen==St.scGen then setSoundCloudStatus("Search failed: "..(err2 or "?"),C.DANGER);UI.scSearchBtn.Text="Search";UI.scSearchBtn.BackgroundColor3=C.ACCENT;UI.scCounterLabel.Text="0 / 0" end
				St.scBusy=false;return
			end
			St.scCid=newCid2;cid=newCid2
			ok,resp=pcall(function() return request({Url="https://api-v2.soundcloud.com/search/tracks?q="..encQ.."&client_id="..cid.."&limit=20",Method="GET",Headers={["Accept"]="application/json",["User-Agent"]="Mozilla/5.0"}}) end)
			if gen~=St.scGen then St.scBusy=false;return end
		end
		if not ok or not resp or (resp.StatusCode~=200 and resp.StatusCode~=0) then
			local code=resp and tostring(resp.StatusCode) or "?";setSoundCloudStatus("HTTP error "..code,C.DANGER)
			UI.scSearchBtn.Text="Search";UI.scSearchBtn.BackgroundColor3=C.ACCENT;UI.scCounterLabel.Text="0 / 0";St.scBusy=false;return
		end
		local pok,data=pcall(function() return Svc.HttpService:JSONDecode(resp.Body or resp.body or "") end)
		if not pok or not data then setSoundCloudStatus("Parse error",C.DANGER);UI.scSearchBtn.Text="Search";UI.scSearchBtn.BackgroundColor3=C.ACCENT;UI.scCounterLabel.Text="0 / 0";St.scBusy=false;return end
		if gen~=St.scGen then St.scBusy=false;return end
		local collection=data.collection or {}
		if #collection==0 then
			setSoundCloudStatus("No results found for \""..query.."\"",C.TEXT3);UI.scSearchBtn.Text="Search";UI.scSearchBtn.BackgroundColor3=C.ACCENT;UI.scCounterLabel.Text="0 / 0";clearSoundCloudArtwork();St.scBusy=false;return
		end
		St.scResults=collection;St.scIdx=1
		setSoundCloudStatus("Found "..#collection.." result"..(#collection==1 and "" or "s"),C.SUCCESS)
		UI.scSearchBtn.Text="Search";UI.scSearchBtn.BackgroundColor3=C.ACCENT
		updateSoundCloudResultDisplay();St.scBusy=false
	end)
end
UI.scSearchBtn.MouseButton1Click:Connect(function() executeSoundCloudSearch() end)
local function clearSoundCloudResultsAnimated()
	local ct=TweenInfo.new(0.2,Enum.EasingStyle.Quad)
	Svc.TweenService:Create(UI.scUrlBox,ct,{TextTransparency=1}):Play()
	Svc.TweenService:Create(UI.scCounterLabel,ct,{TextTransparency=1}):Play()
	if UI.scSearchBtn then Svc.TweenService:Create(UI.scSearchBtn,ct,{TextTransparency=0.5}):Play() end
	St.scResults={}
St.scIdx=1
clearSoundCloudArtwork()
	task.delay(0.2,function()
		UI.scUrlBox.Text="";UI.scCounterLabel.Text="0 / 0"
		Svc.TweenService:Create(UI.scUrlBox,ct,{TextTransparency=0}):Play()
		Svc.TweenService:Create(UI.scCounterLabel,ct,{TextTransparency=0}):Play()
		UI.scCounterLabel.TextColor3=C.TEXT3
		if UI.scSearchBtn then Svc.TweenService:Create(UI.scSearchBtn,ct,{TextTransparency=0}):Play() end
	end)
	setSoundCloudStatus("Enter a song title to search",C.TEXT3)
end
UI.scQueryBox.FocusLost:Connect(function(ep)
	local q=UI.scQueryBox.Text:match("^%s*(.-)%s*$")
	if ep and q~="" then executeSoundCloudSearch()
	elseif q=="" then clearSoundCloudResultsAnimated() end
end)
UI.scQueryBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q=UI.scQueryBox.Text:match("^%s*(.-)%s*$")
	if q=="" then clearSoundCloudResultsAnimated() end
end)
UI.scPrevBtn.MouseButton1Click:Connect(function()
	if #St.scResults==0 then return end
	St.scIdx=St.scIdx-1;if St.scIdx<1 then St.scIdx=#St.scResults end
	updateSoundCloudResultDisplay()
end)
UI.scNextBtn.MouseButton1Click:Connect(function()
	if #St.scResults==0 then return end
	St.scIdx=St.scIdx+1;if St.scIdx>#St.scResults then St.scIdx=1 end
	updateSoundCloudResultDisplay()
end)
end
local function getInc() return St.currentIncrement end
local function shortenText(t,m) if #t<=m then return t end
return t:sub(1,m-3).."..." end
do
	local TDT=1.0
local MAX_TOASTS=3
	local toastPool={}
	local activeToasts={}
	local function stripExt(n) return tostring(n):gsub("%.[^%.%s]+%s*$",""):gsub("%s+$","") end
	local function playNotifSnd() local ns=Instance.new("Sound")
ns.SoundId="rbxassetid://140172825268473"
ns.Volume=St.notifVolume
ns.RollOffMode=Enum.RollOffMode.InverseTapered
ns.Parent=soundsFolder
ns:Play()
Svc.Debris:AddItem(ns,6) end
	local function makeToastSlot(idx)
		if idx==0 then
			return {frame=UI.toast,scale=UI.toastScale,title=UI.toastTitle,sub=UI.toastSub,icon=UI.toastIcon,iconCircle=UI.toastIconCircle,pulse=UI.toastPulse,btn=UI.toastBtn,progressFill=UI.toastProgressFill,dismiss=false}
		end
		local f=Instance.new("Frame")
f.AnchorPoint=Vector2.new(0.5,1)
f.Position=UDim2.new(0.5,0,0,-6)
f.Size=UDim2.new(0,310,0,56)
f.BackgroundColor3=C.ELEVATED
f.BorderSizePixel=0
f.Visible=false
f.ZIndex=3
f.Parent=UI.main
applyCornerRadius(14,f)
applyStroke(1,C.BORDER_LIT,0.35,f)
		local sc=Instance.new("UIScale")
sc.Scale=0
sc.Parent=f
		local tb=Instance.new("TextButton")
tb.Size=UDim2.new(1,0,1,0)
tb.BackgroundTransparency=1
tb.Text=""
tb.AutoButtonColor=false
tb.ZIndex=3
tb.Parent=f
		local ic=Instance.new("Frame")
ic.AnchorPoint=Vector2.new(0,0.5)
ic.Position=UDim2.new(0,14,0.5,0)
ic.Size=UDim2.new(0,32,0,32)
ic.BackgroundColor3=C.ACCENT
ic.BorderSizePixel=0
ic.ZIndex=3
ic.Parent=f
applyCornerRadius(999,ic)
		local pu=Instance.new("Frame")
pu.AnchorPoint=Vector2.new(0.5,0.5)
pu.Position=UDim2.new(0.5,0,0.5,0)
pu.Size=UDim2.new(1,0,1,0)
pu.BackgroundColor3=C.TEXT
pu.BackgroundTransparency=1
pu.BorderSizePixel=0
pu.ZIndex=3
pu.Parent=ic
applyCornerRadius(999,pu)
		local il=Instance.new("TextLabel")
il.Size=UDim2.new(1,0,1,0)
il.BackgroundTransparency=1
il.Font=Enum.Font.GothamBold
il.Text="+"
il.TextColor3=C.BG
il.TextSize=17
il.ZIndex=3
il.Parent=ic
		local tt=Instance.new("TextLabel")
tt.AnchorPoint=Vector2.new(0,1)
tt.Position=UDim2.new(0,56,0.5,-2)
tt.Size=UDim2.new(1,-64,0,18)
tt.BackgroundTransparency=1
tt.Font=Enum.Font.GothamSemibold
tt.Text=""
tt.TextColor3=C.TEXT
tt.TextXAlignment=Enum.TextXAlignment.Left
tt.TextSize=13
tt.TextTruncate=Enum.TextTruncate.AtEnd
tt.ZIndex=3
tt.Parent=f
		local ts=Instance.new("TextLabel")
ts.AnchorPoint=Vector2.new(0,0)
ts.Position=UDim2.new(0,56,0.5,2)
ts.Size=UDim2.new(1,-64,0,14)
ts.BackgroundTransparency=1
ts.Font=Enum.Font.GothamMedium
ts.Text=""
ts.TextColor3=C.ACCENT
ts.TextXAlignment=Enum.TextXAlignment.Left
ts.TextSize=11
ts.ZIndex=3
ts.Parent=f
		local pt=Instance.new("Frame")
pt.AnchorPoint=Vector2.new(0,1)
pt.Position=UDim2.new(0,14,1,-5)
pt.Size=UDim2.new(1,-28,0,3)
pt.BackgroundColor3=C.BG
pt.BorderSizePixel=0
pt.ZIndex=3
pt.Parent=f
applyCornerRadius(999,pt)
		local pf=Instance.new("Frame")
pf.Size=UDim2.new(1,0,1,0)
pf.BackgroundColor3=C.ACCENT
pf.BorderSizePixel=0
pf.ZIndex=4
pf.Parent=pt
applyCornerRadius(999,pf)
		return {frame=f,scale=sc,title=tt,sub=ts,icon=il,iconCircle=ic,pulse=pu,btn=tb,progressFill=pf,dismiss=false}
	end
	for i=0,MAX_TOASTS-1 do toastPool[i]=makeToastSlot(i) end
	local function getToastY(slotInStack)
		return UDim2.new(0.5,0,0,-(6 + slotInStack*62))
	end
	local function repositionToasts(animated)
		for i,slot in ipairs(activeToasts) do
			local target=getToastY(i-1)
			if animated then Svc.TweenService:Create(slot.frame,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{Position=target}):Play()
			else slot.frame.Position=target end
		end
	end
	local function dismissToast(slot)
		slot.dismiss=true
	end
	local function showNextFromQueue()
		if #Dat.notificationQueue==0 then return end
		if #activeToasts>=MAX_TOASTS then return end
		local poolSlot=nil
		for i=0,MAX_TOASTS-1 do
			local inUse=false
for _,as in ipairs(activeToasts) do if as==toastPool[i] then inUse=true
break end end
			if not inUse then poolSlot=toastPool[i]
break end
		end
		if not poolSlot then return end
		local n=table.remove(Dat.notificationQueue,1)
		local ac=n.isRemoval and C.ACCENT_DIM or C.ACCENT
		poolSlot.title.Text=stripExt(n.text)
poolSlot.sub.Text=n.isRemoval and "track removed" or "track loaded"
poolSlot.sub.TextColor3=ac
		poolSlot.icon.Text=n.isRemoval and "−" or "+"
poolSlot.iconCircle.BackgroundColor3=ac
		poolSlot.progressFill.BackgroundColor3=ac
poolSlot.progressFill.Size=UDim2.new(1,0,1,0)
		poolSlot.pulse.BackgroundTransparency=1
poolSlot.dismiss=false
		table.insert(activeToasts,1,poolSlot)
		repositionToasts(true)
		poolSlot.scale.Scale=0
poolSlot.frame.Visible=true
		Svc.TweenService:Create(poolSlot.scale,TweenInfo.new(0.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
		playNotifSnd()
		local cc
cc=poolSlot.btn.MouseButton1Click:Connect(function()
			poolSlot.pulse.BackgroundTransparency=0
			Svc.TweenService:Create(poolSlot.pulse,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=1}):Play()
			poolSlot.dismiss=true;cc:Disconnect()
		end)
		task.spawn(function()
			local pbTween=Svc.TweenService:Create(poolSlot.progressFill,TweenInfo.new(TDT,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,1,0)});pbTween:Play()
			local el=0;while el<TDT and not poolSlot.dismiss do task.wait(0.05);el=el+0.05 end
			pbTween:Cancel()
			for i=#activeToasts,1,-1 do if activeToasts[i]==poolSlot then table.remove(activeToasts,i);break end end
			Svc.TweenService:Create(poolSlot.scale,TweenInfo.new(0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Scale=0}):Play()
			task.wait(0.16);poolSlot.frame.Visible=false;poolSlot.frame.Position=getToastY(0)
			repositionToasts(true)
			task.wait(0.05);showNextFromQueue()
		end)
	end
	showTrackNotification=function(msg,isRem)
		local dn=stripExt(msg)
table.insert(Dat.notificationQueue,{text=dn,isRemoval=isRem})
		if #activeToasts<MAX_TOASTS then showNextFromQueue() end
	end
end
local function formatTime(s) if s~=s then return "0:00" end
s=math.max(0,s)
return string.format("%d:%02d",math.floor(s/60),math.floor(s%60)) end
task.spawn(function() while true do task.wait(1);if UI.timeDisplayContainer then local lg={[UI.timeDisplay]=true,[UI.nextTimeDisplay]=true};for _,c in ipairs(UI.timeDisplayContainer:GetChildren()) do if c:IsA("TextLabel") and not lg[c] then c:Destroy() end end end end end)
local function animTrack(dn,fn)
	if Dat.currentTrackAnimationTween then Dat.currentTrackAnimationTween:Cancel()
Dat.currentTrackAnimationTween=nil
UI.currentTrackButton.TextTransparency=0
UI.nextTrackLabel.TextTransparency=1 end
	Dat.trackAnimGen=(Dat.trackAnimGen or 0)+1
local mg=Dat.trackAnimGen
	UI.nextTrackLabel.Text=dn
UI.tooltipText.Text=fn
	local fo=Svc.TweenService:Create(UI.currentTrackButton,TweenInfo.new(0.25,Enum.EasingStyle.Quad),{TextTransparency=1})
	local fi=Svc.TweenService:Create(UI.nextTrackLabel,TweenInfo.new(0.25,Enum.EasingStyle.Quad),{TextTransparency=0})
	Dat.currentTrackAnimationTween=fo
	fo.Completed:Connect(function(st) if Dat.trackAnimGen~=mg then return end;if st~=Enum.TweenStatus.Completed then return end;UI.currentTrackButton.Text=dn;UI.currentTrackButton.TextTransparency=0;UI.nextTrackLabel.TextTransparency=1;Dat.currentTrackAnimationTween=nil end)
	fo:Play()
fi:Play()
end
local function animateTimeDisplay(t) UI.timeDisplay.TextTransparency=0
UI.nextTimeDisplay.TextTransparency=1
UI.timeDisplay.Text=t
St.lastDisplayedTime=t end
local function updateTrackDisplay(dn,fn) animTrack(dn,fn) end
local function mkSlider(par,lbl,yo,mn,mx,def,dec,giFn,sv,st2,cb)
	local sf=Instance.new("Frame")
sf.Size=UDim2.new(1,0,0,44)
sf.Position=UDim2.new(0,0,0,yo)
sf.BackgroundTransparency=1
sf.ZIndex=3
sf.Parent=par
	local l=Instance.new("TextLabel")
l.Position=UDim2.new(0,0,0,0)
l.Size=UDim2.new(0.55,0,0,16)
l.BackgroundTransparency=1
l.Font=Enum.Font.GothamMedium
l.Text=lbl
l.TextColor3=C.TEXT2
l.TextXAlignment=Enum.TextXAlignment.Left
l.TextSize=13
l.ZIndex=3
l.Parent=sf
	local vb=Instance.new("TextBox")
vb.AnchorPoint=Vector2.new(1,0)
vb.Position=UDim2.new(1,0,0,0)
vb.Size=UDim2.new(0,52,0,16)
vb.BackgroundTransparency=1
vb.Font=Enum.Font.GothamMedium
vb.Text=tostring(def)
vb.TextColor3=C.ACCENT
vb.TextXAlignment=Enum.TextXAlignment.Right
vb.TextSize=13
vb.ClearTextOnFocus=false
vb.ZIndex=3
vb.Parent=sf
	local bar=Instance.new("Frame")
bar.AnchorPoint=Vector2.new(0,0.5)
bar.Position=UDim2.new(0,0,0,32)
bar.Size=UDim2.new(1,0,0,4)
bar.BackgroundColor3=C.ELEVATED
bar.BorderSizePixel=0
bar.ZIndex=3
bar.Parent=sf
applyCornerRadius(999,bar)
	local fill=Instance.new("Frame")
fill.AnchorPoint=Vector2.new(0,0.5)
fill.Position=UDim2.new(0,0,0.5,0)
fill.Size=UDim2.new(0,0,1,0)
fill.BackgroundColor3=C.ACCENT
fill.BorderSizePixel=0
fill.ZIndex=4
fill.Parent=bar
applyCornerRadius(999,fill)
	local hdl=Instance.new("TextButton")
hdl.AnchorPoint=Vector2.new(0.5,0.5)
hdl.Position=UDim2.new(0,0,0.5,0)
hdl.Size=UDim2.new(0,13,0,13)
hdl.BackgroundColor3=C.HANDLE
hdl.BorderSizePixel=0
hdl.Text=""
hdl.AutoButtonColor=false
hdl.ZIndex=5
hdl.Parent=bar
applyCornerRadius(999,hdl)
	local hit=Instance.new("TextButton")
hit.AnchorPoint=Vector2.new(0,0.5)
hit.Position=UDim2.new(0,0,0,32)
hit.Size=UDim2.new(1,0,0,24)
hit.BackgroundTransparency=1
hit.BorderSizePixel=0
hit.Text=""
hit.AutoButtonColor=false
hit.ZIndex=6
hit.Parent=sf
	local drag=false
local cv=def
local hovering=false
	local function cl01(x) return x<0 and 0 or(x>1 and 1 or x) end
	local function quant(v)
		local inc=giFn and giFn() or 0
if inc and inc>0 then local steps=math.floor(v/inc+0.5+1e-9)
v=steps*inc
local pl=math.max(0,math.ceil(-math.log(inc)/math.log(10)+0.5))
local m=10^pl
v=math.floor(v*m+0.5)/m end
		if v<mn then v=mn elseif v>mx then v=mx end
return v
	end
	local function applyV(v,byp)
		if byp then if v<mn then v=mn elseif v>mx then v=mx end
		else v=quant(v)
if sv~=nil and st2~=nil then local inc=giFn and giFn() or 0
local et=(inc>0) and math.min(st2,inc*0.5) or st2
if math.abs(v-sv)<=et then v=sv end end end
		cv=v
local al=mx~=mn and cl01((v-mn)/(mx-mn)) or 0
		if bar.AbsoluteSize.X>0 then fill.Size=UDim2.new(al,0,1,0)
hdl.Position=UDim2.new(al,0,0.5,0) end
		local mt=10^(dec or 0)
vb.Text=tostring(math.floor(v*mt+0.5)/mt)
if cb then cb(v) end
	end
	local function fromX(x) applyV(mn+(mx-mn)*cl01((x-hit.AbsolutePosition.X)/(hit.AbsoluteSize.X>0 and hit.AbsoluteSize.X or 1))) end
	local function fromM() fromX(Svc.UserInput:GetMouseLocation().X) end
	hit.MouseButton1Down:Connect(function() drag=true;fromM() end)
hdl.MouseButton1Down:Connect(function() drag=true;fromM() end)
	Svc.UserInput.InputChanged:Connect(function(inp) if drag and inp.UserInputType==Enum.UserInputType.MouseMovement then fromM() end end)
	Svc.UserInput.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
	vb.Focused:Connect(function() vb.Text="" end)
vb.FocusLost:Connect(function() local n=tonumber(vb.Text);if n then applyV(n,true) else vb.Text=tostring(cv) end end)
	hit.MouseEnter:Connect(function() hovering=true end)
hit.MouseLeave:Connect(function() hovering=false end)
	Svc.UserInput.InputChanged:Connect(function(inp)
		if not hovering then return end
		if inp.UserInputType==Enum.UserInputType.MouseWheel then
			local delta=inp.Position.Z
			applyV(cv+delta*0.1,false)
		end
	end)
	task.defer(function() applyV(def) end)
return {SetValue=applyV,GetValue=function() return cv end,ValueBox=vb,SetHover=function(v) hovering=v end}
end
local function mkToggle(par,txt,xo,cb)
	local btn=Instance.new("TextButton")
btn.Size=UDim2.new(0,78,0,26)
btn.Position=UDim2.new(0,xo,0,0)
btn.BackgroundColor3=C.SURFACE
btn.AutoButtonColor=false
btn.Text=txt
btn.Font=Enum.Font.GothamMedium
btn.TextSize=12
btn.TextColor3=C.TEXT3
btn.BorderSizePixel=0
btn.ZIndex=3
btn.Parent=par
applyCornerRadius(8,btn)
	local str=applyStroke(1,C.BORDER,0.2,btn)
local act=false
	local function ref() if act then btn.BackgroundColor3=C.ACCENT
btn.TextColor3=AT
str.Transparency=1 else btn.BackgroundColor3=C.SURFACE
btn.TextColor3=C.TEXT3
str.Transparency=0.2 end end
	btn.MouseButton1Click:Connect(function() act=not act;ref();if cb then cb(act) end end)
ref()
	return {Button=btn,GetActive=function() return act end,SetActive=function(s) act=s and true or false;ref();if cb then cb(act) end end}
end
UI.trackRow=Instance.new("Frame")
UI.trackRow.Size=UDim2.new(1,0,0,68)
UI.trackRow.BackgroundTransparency=1
UI.trackRow.ZIndex=3
UI.trackRow.Parent=UI.content
do local npL=Instance.new("TextLabel")
npL.Position=UDim2.new(0,0,0,30)
npL.Size=UDim2.new(1,-36,0,12)
npL.BackgroundTransparency=1
npL.Font=Enum.Font.GothamMedium
npL.Text="NOW PLAYING"
npL.TextColor3=C.TEXT3
npL.TextXAlignment=Enum.TextXAlignment.Left
npL.TextSize=9
npL.ZIndex=3
npL.Parent=UI.trackRow end
UI.trackNameContainer=Instance.new("Frame")
UI.trackNameContainer.Position=UDim2.new(0,0,0,43)
UI.trackNameContainer.Size=UDim2.new(1,-46,0,22)
UI.trackNameContainer.BackgroundTransparency=1
UI.trackNameContainer.ClipsDescendants=true
UI.trackNameContainer.ZIndex=3
UI.trackNameContainer.Parent=UI.trackRow
UI.currentTrackButton=Instance.new("TextButton")
UI.currentTrackButton.Size=UDim2.new(1,0,1,0)
UI.currentTrackButton.BackgroundTransparency=1
UI.currentTrackButton.Font=Enum.Font.GothamMedium
UI.currentTrackButton.Text=""
UI.currentTrackButton.TextColor3=C.TEXT
UI.currentTrackButton.TextXAlignment=Enum.TextXAlignment.Left
UI.currentTrackButton.TextSize=14
UI.currentTrackButton.AutoButtonColor=false
UI.currentTrackButton.TextTransparency=0
UI.currentTrackButton.TextTruncate=Enum.TextTruncate.AtEnd
UI.currentTrackButton.ZIndex=4
UI.currentTrackButton.Parent=UI.trackNameContainer
UI.nextTrackLabel=Instance.new("TextLabel")
UI.nextTrackLabel.Size=UDim2.new(1,0,1,0)
UI.nextTrackLabel.BackgroundTransparency=1
UI.nextTrackLabel.Font=Enum.Font.GothamMedium
UI.nextTrackLabel.Text=""
UI.nextTrackLabel.TextColor3=C.TEXT
UI.nextTrackLabel.TextXAlignment=Enum.TextXAlignment.Left
UI.nextTrackLabel.TextSize=14
UI.nextTrackLabel.TextTransparency=1
UI.nextTrackLabel.TextTruncate=Enum.TextTruncate.AtEnd
UI.nextTrackLabel.ZIndex=3
UI.nextTrackLabel.Parent=UI.trackNameContainer
UI.tooltip=Instance.new("Frame")
UI.tooltip.AnchorPoint=Vector2.new(0,1)
UI.tooltip.Size=UDim2.new(0,0,0,22)
UI.tooltip.AutomaticSize=Enum.AutomaticSize.X
UI.tooltip.BackgroundColor3=C.ELEVATED
UI.tooltip.BorderSizePixel=0
UI.tooltip.Visible=false
UI.tooltip.ZIndex=20
UI.tooltip.Parent=UI.main
applyCornerRadius(6,UI.tooltip)
applyStroke(1,C.BORDER_LIT,0.3,UI.tooltip)
do local tp=Instance.new("UIPadding")
tp.PaddingLeft=UDim.new(0,8)
tp.PaddingRight=UDim.new(0,8)
tp.Parent=UI.tooltip end
UI.tooltipText=Instance.new("TextLabel")
UI.tooltipText.Size=UDim2.new(0,0,1,0)
UI.tooltipText.AutomaticSize=Enum.AutomaticSize.X
UI.tooltipText.BackgroundTransparency=1
UI.tooltipText.Font=Enum.Font.Gotham
UI.tooltipText.Text=""
UI.tooltipText.TextColor3=C.TEXT
UI.tooltipText.TextXAlignment=Enum.TextXAlignment.Left
UI.tooltipText.TextSize=11
UI.tooltipText.TextTruncate=Enum.TextTruncate.None
UI.tooltipText.ZIndex=21
UI.tooltipText.Parent=UI.tooltip
local ctrlC=Instance.new("Frame")
ctrlC.Size=UDim2.new(1,0,0,32)
ctrlC.BackgroundTransparency=1
ctrlC.ZIndex=3
ctrlC.Parent=UI.trackRow
local cL=Instance.new("UIListLayout")
cL.FillDirection=Enum.FillDirection.Horizontal
cL.HorizontalAlignment=Enum.HorizontalAlignment.Center
cL.VerticalAlignment=Enum.VerticalAlignment.Center
cL.SortOrder=Enum.SortOrder.LayoutOrder
cL.Padding=UDim.new(0,6)
cL.Parent=ctrlC
local function mkITBtn(nm,sym,lo,cb,cw)
	local btn=Instance.new("TextButton")
btn.Name=nm
btn.Size=UDim2.new(0,cw or 48,0,26)
btn.BackgroundColor3=C.SURFACE
btn.AutoButtonColor=false
btn.Font=Enum.Font.GothamBold
btn.Text=sym
btn.TextSize=11
btn.TextColor3=C.TEXT2
btn.BorderSizePixel=0
btn.LayoutOrder=lo
btn.ZIndex=3
btn.Parent=ctrlC
applyCornerRadius(8,btn)
	local str=applyStroke(1,C.BORDER,0.2,btn)
local dot=Instance.new("Frame")
dot.AnchorPoint=Vector2.new(0.5,0)
dot.Position=UDim2.new(0.5,0,1,3)
dot.Size=UDim2.new(0,20,0,2)
dot.BackgroundColor3=C.ACCENT
dot.BackgroundTransparency=1
dot.BorderSizePixel=0
dot.ZIndex=4
dot.Parent=btn
applyCornerRadius(999,dot)
	local act=false
	local function ref() local ct=TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
if act then Svc.TweenService:Create(btn,ct,{BackgroundColor3=C.ACCENT}):Play()
Svc.TweenService:Create(btn,ct,{TextColor3=AT}):Play()
str.Transparency=1
dot.BackgroundTransparency=0 else Svc.TweenService:Create(btn,ct,{BackgroundColor3=C.SURFACE}):Play()
Svc.TweenService:Create(btn,ct,{TextColor3=C.TEXT2}):Play()
str.Transparency=0.2
dot.BackgroundTransparency=1 end end
	btn.MouseButton1Click:Connect(function() act=not act;ref();if cb then cb(act) end end)
	btn.MouseEnter:Connect(function() if not act then btn.TextColor3=C.TEXT end end)
btn.MouseLeave:Connect(ref)
ref()
	return {Button=btn,Dot=dot,GetActive=function() return act end,SetActive=function(s) act=s and true or false;ref();if cb then cb(act) end end,SetActiveSilent=function(s) act=s and true or false;ref() end,RefreshTheme=function() str.Color=C.BORDER;dot.BackgroundColor3=C.ACCENT;ref() end}
end
UI.prevBtn=Instance.new("TextButton")
UI.prevBtn.Size=UDim2.new(0,36,0,26)
UI.prevBtn.BackgroundColor3=C.SURFACE
UI.prevBtn.AutoButtonColor=false
UI.prevBtn.Font=Enum.Font.GothamBold
UI.prevBtn.Text="<<"
UI.prevBtn.TextSize=11
UI.prevBtn.TextColor3=C.TEXT2
UI.prevBtn.BorderSizePixel=0
UI.prevBtn.LayoutOrder=1
UI.prevBtn.ZIndex=3
UI.prevBtn.Parent=ctrlC
applyCornerRadius(8,UI.prevBtn)
applyStroke(1,C.BORDER,0.2,UI.prevBtn)
UI.repeatToggle=mkITBtn("RepeatButton","repeat",2,function(on) St.repeatEnabled=on;if on and UI.shuffleToggle and UI.shuffleToggle.GetActive() then UI.shuffleToggle.SetActiveSilent(false);St.shuffleEnabled=false end;saveUserSettings() end,48)
UI.playPauseBtn=Instance.new("TextButton")
UI.playPauseBtn.Size=UDim2.new(0,88,0,28)
UI.playPauseBtn.BackgroundColor3=C.ACCENT
UI.playPauseBtn.AutoButtonColor=false
UI.playPauseBtn.Font=Enum.Font.GothamSemibold
UI.playPauseBtn.TextSize=13
UI.playPauseBtn.TextColor3=AT
UI.playPauseBtn.Text="play"
UI.playPauseBtn.BorderSizePixel=0
UI.playPauseBtn.LayoutOrder=3
UI.playPauseBtn.ZIndex=3
UI.playPauseBtn.Parent=ctrlC
applyCornerRadius(9,UI.playPauseBtn)
UI.shuffleToggle=mkITBtn("ShuffleButton","shuffle",4,function(on) St.shuffleEnabled=on;if on and UI.repeatToggle and UI.repeatToggle.GetActive() then UI.repeatToggle.SetActiveSilent(false);St.repeatEnabled=false end;saveUserSettings() end,48)
UI.nextBtn=Instance.new("TextButton")
UI.nextBtn.Size=UDim2.new(0,36,0,26)
UI.nextBtn.BackgroundColor3=C.SURFACE
UI.nextBtn.AutoButtonColor=false
UI.nextBtn.Font=Enum.Font.GothamBold
UI.nextBtn.Text=">>"
UI.nextBtn.TextSize=11
UI.nextBtn.TextColor3=C.TEXT2
UI.nextBtn.BorderSizePixel=0
UI.nextBtn.LayoutOrder=5
UI.nextBtn.ZIndex=3
UI.nextBtn.Parent=ctrlC
applyCornerRadius(8,UI.nextBtn)
applyStroke(1,C.BORDER,0.2,UI.nextBtn)
UI.meterFrame=Instance.new("Frame")
UI.meterFrame.AnchorPoint=Vector2.new(1,0.5)
UI.meterFrame.Position=UDim2.new(1,0,0,47)
UI.meterFrame.Size=UDim2.new(0,28,0,18)
UI.meterFrame.BackgroundTransparency=1
UI.meterFrame.ZIndex=5
UI.meterFrame.Parent=UI.trackRow
local function mkMBar(x) local b=Instance.new("Frame")
b.AnchorPoint=Vector2.new(0.5,1)
b.Position=UDim2.new(0,x,1,0)
b.Size=UDim2.new(0,3,0.18,0)
b.BackgroundColor3=C.ACCENT
b.BackgroundTransparency=0.5
b.BorderSizePixel=0
b.ZIndex=5
b.Parent=UI.meterFrame
applyCornerRadius(999,b)
table.insert(Dat.meterBars,b) end
mkMBar(5)
mkMBar(13)
mkMBar(21)
UI.progressBar=Instance.new("TextButton")
UI.progressBar.Position=UDim2.new(0,0,0,74)
UI.progressBar.Size=UDim2.new(1,0,0,5)
UI.progressBar.BackgroundColor3=C.ELEVATED
UI.progressBar.BorderSizePixel=0
UI.progressBar.ZIndex=3
UI.progressBar.Text=""
UI.progressBar.AutoButtonColor=false
UI.progressBar.Parent=UI.content
applyCornerRadius(999,UI.progressBar)
UI.progressFill=Instance.new("Frame")
UI.progressFill.AnchorPoint=Vector2.new(0,0.5)
UI.progressFill.Position=UDim2.new(0,0,0.5,0)
UI.progressFill.Size=UDim2.new(0,0,1,0)
UI.progressFill.BackgroundColor3=C.ACCENT
UI.progressFill.BorderSizePixel=0
UI.progressFill.ZIndex=4
UI.progressFill.Parent=UI.progressBar
applyCornerRadius(999,UI.progressFill)
UI.timeDisplayContainer=Instance.new("Frame")
UI.timeDisplayContainer.AnchorPoint=Vector2.new(0.5,0)
UI.timeDisplayContainer.Position=UDim2.new(0.5,0,1,4)
UI.timeDisplayContainer.Size=UDim2.new(0,110,0,12)
UI.timeDisplayContainer.BackgroundTransparency=1
UI.timeDisplayContainer.ClipsDescendants=true
UI.timeDisplayContainer.ZIndex=5
UI.timeDisplayContainer.Parent=UI.progressBar
local function mkTL(nm,tr) local l=Instance.new("TextLabel")
l.Name=nm
l.AnchorPoint=Vector2.new(0.5,0)
l.Position=UDim2.new(0.5,0,0,0)
l.Size=UDim2.new(1,0,1,0)
l.BackgroundTransparency=1
l.Font=Enum.Font.GothamMedium
l.Text="0:00 / 0:00"
l.TextColor3=C.TEXT3
l.TextSize=10
l.TextTransparency=tr
l.ZIndex=6
l.Parent=UI.timeDisplayContainer
return l end
UI.timeDisplay=mkTL("TimeDisplay",0)
UI.nextTimeDisplay=mkTL("NextTimeDisplay",1)
local function updProgX(x) if not sound or not sound.TimeLength or sound.TimeLength==0 then return end
local a=math.clamp((x-UI.progressBar.AbsolutePosition.X)/UI.progressBar.AbsoluteSize.X,0,1)
UI.progressFill.Size=UDim2.new(a,0,1,0)
pcall(function() sound.TimePosition=math.min(a*sound.TimeLength,math.max(0,sound.TimeLength-0.1)) end) end
local function updProgM() updProgX(Svc.UserInput:GetMouseLocation().X) end
UI.progressBar.MouseButton1Down:Connect(function() if not sound then return end;St.draggingProgress=true;St.wasPlayingBeforeDrag=sound.IsPlaying;if sound.IsPlaying then pcall(function() sound:Pause() end) end;updProgM() end)
Svc.UserInput.InputChanged:Connect(function(inp) if St.draggingProgress and inp.UserInputType==Enum.UserInputType.MouseMovement then updProgM() end end)
Svc.UserInput.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 and St.draggingProgress then St.draggingProgress=false;if St.wasPlayingBeforeDrag and sound and not sound.IsPlaying then pcall(function() sound:Resume() end);if not sound.IsPlaying then sound:Play() end end end end)
do
	local ptip=Instance.new("Frame")
ptip.Name="ProgressTooltip"
ptip.AnchorPoint=Vector2.new(0.5,1)
ptip.Size=UDim2.new(0,48,0,18)
ptip.BackgroundColor3=C.ELEVATED
ptip.BorderSizePixel=0
ptip.ZIndex=10
ptip.Visible=false
ptip.Parent=UI.progressBar
applyCornerRadius(6,ptip)
applyStroke(1,C.BORDER_LIT,0.3,ptip)
	local ptipL=Instance.new("TextLabel")
ptipL.Size=UDim2.new(1,0,1,0)
ptipL.BackgroundTransparency=1
ptipL.Font=Enum.Font.GothamMedium
ptipL.Text="0:00"
ptipL.TextColor3=C.TEXT
ptipL.TextSize=11
ptipL.ZIndex=11
ptipL.Parent=ptip
	UI.progressBar.MouseEnter:Connect(function() if sound and sound.TimeLength and sound.TimeLength>0 then ptip.Visible=true end end)
	UI.progressBar.MouseLeave:Connect(function() ptip.Visible=false end)
	Svc.UserInput.InputChanged:Connect(function(inp)
		if inp.UserInputType~=Enum.UserInputType.MouseMovement then return end
		if not ptip.Visible then return end
		if not sound or not sound.TimeLength or sound.TimeLength==0 then ptip.Visible=false;return end
		local mx=Svc.UserInput:GetMouseLocation().X
		local barX=UI.progressBar.AbsolutePosition.X;local barW=UI.progressBar.AbsoluteSize.X
		local frac=math.clamp((mx-barX)/barW,0,1)
		local secs=math.floor(frac*sound.TimeLength+0.5)
		ptipL.Text=string.format("%d:%02d",math.floor(secs/60),secs%60)
		local relX=math.clamp(mx-barX,0,barW)
		ptip.Position=UDim2.new(0,relX,0,-4)
	end)
end
do local sep1=Instance.new("Frame")
sep1.Position=UDim2.new(0,0,0,88)
sep1.Size=UDim2.new(1,0,0,1)
sep1.BackgroundColor3=C.BORDER
sep1.BorderSizePixel=0
sep1.ZIndex=2
sep1.Parent=UI.content end
mkSlider(UI.content,"volume",92,Cfg.SLIDER_MIN,Cfg.SLIDER_MAX,St.currentVolume,2,getInc,Cfg.SNAP_VALUE,Cfg.SNAP_THRESHOLD,function(v) St.currentVolume=v;if sound then sound.Volume=math.max(0,v) end;saveUserSettings() end)
mkSlider(UI.content,"speed",140,Cfg.SLIDER_MIN,Cfg.SLIDER_MAX,St.currentSpeed,2,getInc,Cfg.SNAP_VALUE,Cfg.SNAP_THRESHOLD,function(v) St.currentSpeed=v;if sound then sound.PlaybackSpeed=(v<=0) and 0.01 or v end;saveUserSettings() end)
do local sep2=Instance.new("Frame")
sep2.Position=UDim2.new(0,0,0,186)
sep2.Size=UDim2.new(1,0,0,1)
sep2.BackgroundColor3=C.BORDER
sep2.BorderSizePixel=0
sep2.ZIndex=2
sep2.Parent=UI.content end
do local fxL=Instance.new("TextLabel")
fxL.Position=UDim2.new(0,0,0,191)
fxL.Size=UDim2.new(1,0,0,14)
fxL.BackgroundTransparency=1
fxL.Font=Enum.Font.GothamMedium
fxL.Text="EFFECTS"
fxL.TextColor3=C.TEXT3
fxL.TextXAlignment=Enum.TextXAlignment.Left
fxL.TextSize=9
fxL.ZIndex=3
fxL.Parent=UI.content
end
local fxRow=Instance.new("Frame")
fxRow.Position=UDim2.new(0,0,0,208)
fxRow.Size=UDim2.new(1,0,0,26)
fxRow.BackgroundTransparency=1
fxRow.ZIndex=3
fxRow.Parent=UI.content
mkToggle(fxRow,"reverb",0,function(on) reverb.Enabled=on;setReverbPanelVisible(on) end)
mkToggle(fxRow,"distort",88,function(on) distortion.Enabled=on end)
mkToggle(fxRow,"equalizer",176,function(on) equalizer.Enabled=on end)
mkToggle(fxRow,"chorus",264,function(on) chorus.Enabled=on end)
do local sep3=Instance.new("Frame")
sep3.Position=UDim2.new(0,0,0,238)
sep3.Size=UDim2.new(1,0,0,1)
sep3.BackgroundColor3=C.BORDER
sep3.BorderSizePixel=0
sep3.ZIndex=2
sep3.Parent=UI.content end
local incRow=Instance.new("Frame")
incRow.Position=UDim2.new(0,0,0,243)
incRow.Size=UDim2.new(1,0,0,20)
incRow.BackgroundTransparency=1
incRow.ZIndex=3
incRow.Parent=UI.content
do local incL=Instance.new("TextLabel")
incL.Position=UDim2.new(0,0,0,0)
incL.Size=UDim2.new(0.5,0,1,0)
incL.BackgroundTransparency=1
incL.Font=Enum.Font.GothamMedium
incL.Text="increment"
incL.TextColor3=C.TEXT2
incL.TextXAlignment=Enum.TextXAlignment.Left
incL.TextSize=13
incL.ZIndex=3
incL.Parent=incRow end
UI.incrementBox=Instance.new("TextBox")
UI.incrementBox.AnchorPoint=Vector2.new(1,0.5)
UI.incrementBox.Position=UDim2.new(1,0,0.5,0)
UI.incrementBox.Size=UDim2.new(0,64,0,18)
UI.incrementBox.BackgroundColor3=C.SURFACE
UI.incrementBox.BorderSizePixel=0
UI.incrementBox.Font=Enum.Font.GothamMedium
UI.incrementBox.Text=tostring(St.currentIncrement)
UI.incrementBox.TextColor3=C.ACCENT
UI.incrementBox.TextXAlignment=Enum.TextXAlignment.Right
UI.incrementBox.TextSize=12
UI.incrementBox.ClearTextOnFocus=false
UI.incrementBox.ZIndex=3
UI.incrementBox.Parent=incRow
applyCornerRadius(7,UI.incrementBox)
applyStroke(1,C.BORDER,0.2,UI.incrementBox)
do local ipPad=Instance.new("UIPadding")
ipPad.PaddingRight=UDim.new(0,6)
ipPad.Parent=UI.incrementBox end
UI.incrementBox.Focused:Connect(function() UI.incrementBox.Text="" end)
UI.incrementBox.FocusLost:Connect(function() local n=tonumber(UI.incrementBox.Text);if n then if n<=0 then n=0.0000001 end;n=math.floor(n*1e6+0.5)/1e6;St.currentIncrement=n;UI.incrementBox.Text=tostring(n);saveUserSettings() else UI.incrementBox.Text=tostring(St.currentIncrement) end end)
UI.reverbPanel=Instance.new("Frame")
UI.reverbPanel.Position=UDim2.new(0,0,0,267)
UI.reverbPanel.Size=UDim2.new(1,0,0,140)
UI.reverbPanel.BackgroundTransparency=1
UI.reverbPanel.Visible=false
UI.reverbPanel.ZIndex=3
UI.reverbPanel.Parent=UI.content
do local rvH=Instance.new("TextLabel")
rvH.Position=UDim2.new(0,0,0,0)
rvH.Size=UDim2.new(1,0,0,14)
rvH.BackgroundTransparency=1
rvH.Font=Enum.Font.GothamMedium
rvH.Text="REVERB SETTINGS"
rvH.TextColor3=C.TEXT3
rvH.TextXAlignment=Enum.TextXAlignment.Left
rvH.TextSize=9
rvH.ZIndex=3
rvH.Parent=UI.reverbPanel end
local function mkRF(lbl,prop,ord)
	local row=Instance.new("Frame")
row.Size=UDim2.new(1,0,0,Cfg.REVERB_ROW_HEIGHT)
row.Position=UDim2.new(0,0,0,18+(ord-1)*(Cfg.REVERB_ROW_HEIGHT+Cfg.REVERB_ROW_GAP))
row.BackgroundTransparency=1
row.ZIndex=3
row.Parent=UI.reverbPanel
	local l=Instance.new("TextLabel")
l.Position=UDim2.new(0,0,0,0)
l.Size=UDim2.new(0.5,0,1,0)
l.BackgroundTransparency=1
l.Font=Enum.Font.Gotham
l.Text=lbl
l.TextColor3=C.TEXT2
l.TextXAlignment=Enum.TextXAlignment.Left
l.TextSize=12
l.ZIndex=3
l.Parent=row
	local b=Instance.new("TextBox")
b.AnchorPoint=Vector2.new(1,0.5)
b.Position=UDim2.new(1,0,0.5,0)
b.Size=UDim2.new(0,72,0,Cfg.REVERB_ROW_HEIGHT-2)
b.BackgroundColor3=C.SURFACE
b.BorderSizePixel=0
b.Font=Enum.Font.GothamMedium
local cv=reverb[prop]
b.Text=tostring(cv~=nil and cv or "")
b.TextColor3=C.ACCENT
b.TextXAlignment=Enum.TextXAlignment.Right
b.TextSize=12
b.ClearTextOnFocus=false
b.ZIndex=3
b.Parent=row
applyCornerRadius(6,b)
applyStroke(1,C.BORDER,0.2,b)
	local p=Instance.new("UIPadding")
p.PaddingRight=UDim.new(0,5)
p.Parent=b
	b.Focused:Connect(function() b.Text="" end)
b.FocusLost:Connect(function() local n=tonumber(b.Text);if n~=nil then reverb[prop]=n;b.Text=tostring(n) else b.Text=tostring(reverb[prop] or "") end end)
end
mkRF("DecayTime","DecayTime",1)
mkRF("Density","Density",2)
mkRF("Diffusion","Diffusion",3)
mkRF("DryLevel","DryLevel",4)
mkRF("Priority","Priority",5)
mkRF("WetLevel","WetLevel",6)
do
local function createPopupFrame(w,h) local f=Instance.new("Frame")
f.AnchorPoint=Vector2.new(0.5,0.5)
f.Position=UDim2.new(0.5,0,0.5,0)
f.Size=UDim2.new(0,w,0,h)
f.BackgroundColor3=C.SURFACE
f.BorderSizePixel=0
f.Visible=false
f.ZIndex=150
f.Parent=UI.gui
applyCornerRadius(14,f)
applyStroke(1,C.BORDER_LIT,0.25,f)
return f end
local function createPopupTitle(p,t) local l=Instance.new("TextLabel")
l.Name="Title"
l.Position=UDim2.new(0,16,0,12)
l.Size=UDim2.new(1,-32,0,18)
l.BackgroundTransparency=1
l.Font=Enum.Font.GothamSemibold
l.Text=t
l.TextColor3=C.TEXT
l.TextXAlignment=Enum.TextXAlignment.Left
l.TextSize=14
l.ZIndex=151
l.Parent=p
return l end
local function createPopupInput(p,ph,yp) local b=Instance.new("TextBox")
b.Position=UDim2.new(0,16,0,yp)
b.Size=UDim2.new(1,-32,0,30)
b.BackgroundColor3=C.ELEVATED
b.BorderSizePixel=0
b.Font=Enum.Font.Gotham
b.PlaceholderText=ph
b.Text=""
b.TextColor3=C.TEXT
b.PlaceholderColor3=C.TEXT3
b.TextSize=13
b.ClearTextOnFocus=true
b.ZIndex=151
b.Parent=p
applyCornerRadius(8,b)
applyStroke(1,C.BORDER,0.2,b)
return b end
local function createPopupButton(p,t,yp,pri,lft) local b=Instance.new("TextButton")
if lft then b.Position=UDim2.new(0,16,0,yp)
b.Size=UDim2.new(0.5,-20,0,30) else b.Position=UDim2.new(0.5,4,0,yp)
b.Size=UDim2.new(0.5,-20,0,30) end
b.BackgroundColor3=pri and C.ACCENT or C.ELEVATED
b.BorderSizePixel=0
b.Font=pri and Enum.Font.GothamSemibold or Enum.Font.Gotham
b.Text=t
b.TextColor3=pri and AT or C.TEXT2
b.TextSize=13
b.AutoButtonColor=false
b.ZIndex=151
b.Parent=p
applyCornerRadius(8,b)
return b end
UI.soundIdFrame=createPopupFrame(300,128)
UI.soundIdTitle=createPopupTitle(UI.soundIdFrame,"Enter Roblox Sound ID")
UI.soundIdInput=createPopupInput(UI.soundIdFrame,"e.g. 1234567890",38)
UI.soundIdConfirm=createPopupButton(UI.soundIdFrame,"Confirm",82,true,true)
UI.soundIdCancel=createPopupButton(UI.soundIdFrame,"Cancel",82,false,false)
UI.categoryRenameFrame=createPopupFrame(300,128)
UI.categoryRenameTitle=createPopupTitle(UI.categoryRenameFrame,"Rename Category")
UI.categoryRenameInput=createPopupInput(UI.categoryRenameFrame,"Enter new name",38)
UI.categoryRenameConfirm=createPopupButton(UI.categoryRenameFrame,"Confirm",82,true,true)
UI.categoryRenameCancel=createPopupButton(UI.categoryRenameFrame,"Cancel",82,false,false)
UI.categorySelectFrame=createPopupFrame(300,300)
UI.categorySelectTitle=createPopupTitle(UI.categorySelectFrame,"Select Category")
UI.categorySelectScroll=Instance.new("ScrollingFrame")
UI.categorySelectScroll.Position=UDim2.new(0,16,0,40)
UI.categorySelectScroll.Size=UDim2.new(1,-32,1,-88)
UI.categorySelectScroll.BackgroundTransparency=1
UI.categorySelectScroll.BorderSizePixel=0
UI.categorySelectScroll.ScrollBarThickness=3
UI.categorySelectScroll.ScrollBarImageColor3=C.ACCENT
UI.categorySelectScroll.CanvasSize=UDim2.new(0,0,0,0)
UI.categorySelectScroll.ZIndex=151
UI.categorySelectScroll.Parent=UI.categorySelectFrame
UI.categorySelectLayout=Instance.new("UIListLayout")
UI.categorySelectLayout.Padding=UDim.new(0,5)
UI.categorySelectLayout.SortOrder=Enum.SortOrder.LayoutOrder
UI.categorySelectLayout.Parent=UI.categorySelectScroll
UI.categorySelectLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() UI.categorySelectScroll.CanvasSize=UDim2.new(0,0,0,UI.categorySelectLayout.AbsoluteContentSize.Y+6) end)
UI.categorySelectCancel=createPopupButton(UI.categorySelectFrame,"Cancel",-38,false,false)
UI.categorySelectCancel.AnchorPoint=Vector2.new(0,1)
UI.categorySelectCancel.Position=UDim2.new(0,16,1,-10)
UI.categorySelectCancel.Size=UDim2.new(1,-32,0,30)
UI.deleteConfirmFrame=createPopupFrame(320,148)
UI.deleteConfirmTitle=createPopupTitle(UI.deleteConfirmFrame,"Delete Track?")
UI.deleteConfirmMessage=Instance.new("TextLabel")
UI.deleteConfirmMessage.Position=UDim2.new(0,16,0,40)
UI.deleteConfirmMessage.Size=UDim2.new(1,-32,0,52)
UI.deleteConfirmMessage.BackgroundTransparency=1
UI.deleteConfirmMessage.Font=Enum.Font.Gotham
UI.deleteConfirmMessage.Text='Would you like to delete (audio name)?'
UI.deleteConfirmMessage.TextColor3=C.TEXT2
UI.deleteConfirmMessage.TextXAlignment=Enum.TextXAlignment.Left
UI.deleteConfirmMessage.TextYAlignment=Enum.TextYAlignment.Top
UI.deleteConfirmMessage.TextSize=13
UI.deleteConfirmMessage.TextWrapped=true
UI.deleteConfirmMessage.ZIndex=151
UI.deleteConfirmMessage.Parent=UI.deleteConfirmFrame
UI.deleteConfirmYes=createPopupButton(UI.deleteConfirmFrame,"Delete",108,false,true)
UI.deleteConfirmNo=createPopupButton(UI.deleteConfirmFrame,"Cancel",108,false,false)
UI.listTooltip=Instance.new("Frame")
UI.listTooltip.AnchorPoint=Vector2.new(0,1)
UI.listTooltip.Size=UDim2.new(0,0,0,22)
UI.listTooltip.AutomaticSize=Enum.AutomaticSize.X
UI.listTooltip.BackgroundColor3=C.ELEVATED
UI.listTooltip.BorderSizePixel=0
UI.listTooltip.Visible=false
UI.listTooltip.ZIndex=200
UI.listTooltip.Parent=UI.gui
applyCornerRadius(6,UI.listTooltip)
applyStroke(1,C.BORDER_LIT,0.3,UI.listTooltip)
do local tp=Instance.new("UIPadding")
tp.PaddingLeft=UDim.new(0,8)
tp.PaddingRight=UDim.new(0,8)
tp.Parent=UI.listTooltip end
UI.listTooltipText=Instance.new("TextLabel")
UI.listTooltipText.Size=UDim2.new(0,0,1,0)
UI.listTooltipText.AutomaticSize=Enum.AutomaticSize.X
UI.listTooltipText.BackgroundTransparency=1
UI.listTooltipText.Font=Enum.Font.Gotham
UI.listTooltipText.Text=""
UI.listTooltipText.TextColor3=C.TEXT
UI.listTooltipText.TextXAlignment=Enum.TextXAlignment.Left
UI.listTooltipText.TextSize=11
UI.listTooltipText.TextTruncate=Enum.TextTruncate.None
UI.listTooltipText.ZIndex=201
UI.listTooltipText.Parent=UI.listTooltip
Svc.UserInput.InputChanged:Connect(function(inp)
	if inp.UserInputType==Enum.UserInputType.MouseMovement and UI.listTooltip.Visible then
		local mp=Svc.UserInput:GetMouseLocation()
		UI.listTooltip.Position=UDim2.fromOffset(mp.X+14,mp.Y-6)
	end
end)
end
local setCurrentTrack
local rebuildTrackListUI
local function rebuildQueueUI()
	for _,c in ipairs(UI.queueScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	for i,item in ipairs(Dat.queueList) do
		local btn=Instance.new("TextButton")
btn.Size=UDim2.new(1,0,0,30)
btn.BackgroundColor3=C.SURFACE
btn.AutoButtonColor=false
btn.Active=true
btn.Font=Enum.Font.Gotham
btn.Text=shortenText(item.DisplayName,28)
btn.TextColor3=C.TEXT2
btn.TextXAlignment=Enum.TextXAlignment.Left
btn.TextSize=12
btn.BorderSizePixel=0
btn.ZIndex=2
btn.Parent=UI.queueScroll
applyCornerRadius(7,btn)
applyStroke(1,C.BORDER,0.3,btn)
		local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,10)
p.Parent=btn
local qi=i
		btn.MouseButton1Click:Connect(function() table.remove(Dat.queueList,qi);rebuildQueueUI() end)
		btn.MouseEnter:Connect(function() btn.BackgroundColor3=Color3.fromRGB(50,20,20);btn.Text="click to remove" end)
		btn.MouseLeave:Connect(function() btn.BackgroundColor3=C.SURFACE;btn.Text=shortenText(item.DisplayName,28) end)
	end
end
local function addTrackToQueue(idx) if idx<1 or idx>#Dat.trackList then return end
local t=Dat.trackList[idx]
local s=Dat.createdSounds[idx]
if t and s then table.insert(Dat.queueList,{DisplayName=t.DisplayName,FullName=t.FullName or t.DisplayName,TrackIndex=idx,Sound=s})
rebuildQueueUI() end end
local function isTrackInCategory(idx)
	if not Dat.trackList[idx] then return false,nil end
local tid=getTrackId(Dat.trackList[idx])
	for ci,cat in ipairs(Dat.categories) do for _,t in ipairs(cat.TrackTIDs or {}) do if t==tid then return true,ci end end end
return false,nil
end
local function removeTrackFromCategory(idx)
	if not Dat.trackList[idx] then return false end
local tid=getTrackId(Dat.trackList[idx])
	for _,cat in ipairs(Dat.categories) do for i,t in ipairs(cat.TrackTIDs or {}) do if t==tid then table.remove(cat.TrackTIDs,i)
rebuildCategoryTrackIndices()
saveCategoriesToDisk()
return true end end end
return false
end
local function getSoundIdCategory() for _,cat in ipairs(Dat.categories) do if cat.CategoryID==Cfg.SOUND_ID_CATEGORY_ID then return cat end end end
local function getOrCreateSoundIdCategory() local e=getSoundIdCategory()
if e then return e end
local c={Name=Cfg.SOUND_ID_CATEGORY_NAME,Tracks={},CategoryID=Cfg.SOUND_ID_CATEGORY_ID}
table.insert(Dat.categories,c)
saveCategoriesToDisk()
return c end
local function showCategorySelector(ti)
	for _,c in ipairs(UI.categorySelectScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	if #Dat.categories==0 then local n=Instance.new("TextLabel")
n.Size=UDim2.new(1,0,0,40)
n.BackgroundTransparency=1
n.Font=Enum.Font.Gotham
n.Text="No categories yet.\nCreate one first!"
n.TextColor3=C.TEXT2
n.TextSize=12
n.TextYAlignment=Enum.TextYAlignment.Center
n.ZIndex=151
n.Parent=UI.categorySelectScroll
UI.categorySelectFrame.Visible=true
return end
	for ci,cat in ipairs(Dat.categories) do
		local btn=Instance.new("TextButton")
btn.Size=UDim2.new(1,0,0,30)
btn.BackgroundColor3=C.ACCENT_DIM
btn.AutoButtonColor=false
btn.Font=Enum.Font.GothamMedium
btn.Text=cat.Name
btn.TextColor3=Color3.fromRGB(255,255,255)
btn.TextSize=13
btn.BorderSizePixel=0
btn.ZIndex=151
btn.Parent=UI.categorySelectScroll
applyCornerRadius(7,btn)
		btn.MouseButton1Click:Connect(function()
			local track=Dat.trackList[ti];if not track then UI.categorySelectFrame.Visible=false;return end
			local tid=getTrackId(track);local dup=false;for _,t in ipairs(cat.TrackTIDs or {}) do if t==tid then dup=true;break end end
			if not dup then
				if not cat.TrackTIDs then cat.TrackTIDs={} end;table.insert(cat.TrackTIDs,tid);rebuildCategoryTrackIndices();saveCategoriesToDisk()
				local tb=nil;for _,ch in ipairs(UI.listScroll:GetChildren()) do if ch.Name=="Track_"..ti and ch:IsA("TextButton") then tb=ch;break end end
				if tb then tb.BackgroundColor3=C.ACCENT;tb.TextColor3=AT;Svc.TweenService:Create(tb,TweenInfo.new(0.12,Enum.EasingStyle.Linear),{BackgroundColor3=C.ACCENT_DIM,TextTransparency=1}):Play();Svc.TweenService:Create(tb,TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.In,0,false,0.12),{Size=UDim2.new(1,0,0,0)}):Play();task.delay(0.32,function() rebuildTrackListUI() end)
				else rebuildTrackListUI() end
			end;UI.categorySelectFrame.Visible=false;St.selectingCategoryForTrack=false;St.pendingTrackIndexForCategory=nil
		end)
		btn.MouseEnter:Connect(function() btn.BackgroundColor3=C.ACCENT;btn.TextColor3=AT end)
btn.MouseLeave:Connect(function() btn.BackgroundColor3=C.ACCENT_DIM;btn.TextColor3=Color3.fromRGB(255,255,255) end)
	end
St.selectingCategoryForTrack=true
St.pendingTrackIndexForCategory=ti
UI.categorySelectFrame.Visible=true
end
rebuildTrackListUI=function()
	Dat.rebuildTrackListUI=rebuildTrackListUI
	local sc=UI.listScroll.CanvasPosition
Dat.listButtonRefs={}
	for _,c in ipairs(UI.listScroll:GetChildren()) do if c:IsA("Frame") or c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
	local lo=1
local q=St.searchQuery or ""
	if q~="" then
		local function mq(dn) return dn:lower():find(q,1,true)~=nil end
		local chm={}
for ci,cat in ipairs(Dat.categories) do for _,ti in ipairs(cat.Tracks) do local t=Dat.trackList[ti]
if t and mq(t.DisplayName) then chm[ci]=true
break end end end
		for ci,cat in ipairs(Dat.categories) do
			if not chm[ci] then continue end
			local h=Instance.new("TextButton")
h.Size=UDim2.new(1,0,0,24)
h.BackgroundColor3=C.ACCENT_DIM
h.AutoButtonColor=false
h.Active=false
h.Font=Enum.Font.GothamMedium
h.Text="  "..cat.Name
h.TextColor3=Color3.fromRGB(255,255,255)
h.TextXAlignment=Enum.TextXAlignment.Left
h.TextSize=11
h.BorderSizePixel=0
h.LayoutOrder=lo
h.ZIndex=2
h.Parent=UI.listScroll
lo=lo+1
applyCornerRadius(7,h)
			for _,ti in ipairs(cat.Tracks) do
				local t=Dat.trackList[ti]
if not t or not mq(t.DisplayName) then continue end
				local isCurrent=ti==St.currentTrackIndex
				local b=Instance.new("TextButton")
b.Size=UDim2.new(1,-4,0,28)
b.BackgroundColor3=isCurrent and C.ACCENT_DIM or C.SURFACE
b.AutoButtonColor=false
b.Active=true
b.Font=isCurrent and Enum.Font.GothamMedium or Enum.Font.Gotham
b.Text=shortenText(t.DisplayName,28)
b.TextColor3=isCurrent and C.ACCENT or C.TEXT2
b.TextXAlignment=Enum.TextXAlignment.Left
b.TextSize=11
b.BorderSizePixel=0
b.LayoutOrder=lo
b.ZIndex=2
b.Parent=UI.listScroll
lo=lo+1
applyCornerRadius(6,b)
				if isCurrent then local str=applyStroke(1,C.ACCENT,1,b)
if str then Svc.TweenService:Create(str,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency=0.2}):Play() end else applyStroke(1,C.BORDER,0.4,b) end
				local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,20)
p.Parent=b
local cti=ti
				if isCurrent then b.BackgroundColor3=C.SURFACE
Svc.TweenService:Create(b,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=C.ACCENT_DIM}):Play() end
				b.MouseButton1Click:Connect(function()
					local ctrl=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftControl) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightControl)
					local shift=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftShift) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightShift)
					if shift then removeTrackFromCategory(cti);rebuildTrackListUI()
					elseif ctrl then addTrackToQueue(cti)
					else setCurrentTrack(cti,true) end
				end)
				b.MouseEnter:Connect(function() if not(cti==St.currentTrackIndex) then Svc.TweenService:Create(b,TweenInfo.new(0.12,Enum.EasingStyle.Quad),{BackgroundColor3=C.ELEVATED}):Play() end;St.hoveredTrackIndex=cti;St.hoveredTrackInCategory=true end)
				b.MouseLeave:Connect(function() Svc.TweenService:Create(b,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{BackgroundColor3=cti==St.currentTrackIndex and C.ACCENT_DIM or C.SURFACE}):Play();St.hoveredTrackIndex=nil;St.hoveredTrackInCategory=false end)
			end
		end
		for _,i in ipairs(getOrderedUncategorizedTracks()) do
			local t=Dat.trackList[i]
if not t or not mq(t.DisplayName) then continue end
			local isCurrent=i==St.currentTrackIndex
			local b=Instance.new("TextButton")
b.Size=UDim2.new(1,0,0,30)
b.BackgroundColor3=isCurrent and C.ACCENT_DIM or C.SURFACE
b.AutoButtonColor=false
b.Active=true
b.Font=isCurrent and Enum.Font.GothamMedium or Enum.Font.Gotham
b.Text=shortenText(t.DisplayName,30)
b.TextColor3=isCurrent and C.ACCENT or C.TEXT2
b.TextXAlignment=Enum.TextXAlignment.Left
b.TextSize=12
b.BorderSizePixel=0
b.LayoutOrder=lo
b.ZIndex=2
b.Parent=UI.listScroll
lo=lo+1
applyCornerRadius(8,b)
			if isCurrent then local str=applyStroke(1,C.ACCENT,1,b)
if str then Svc.TweenService:Create(str,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency=0.2}):Play() end else applyStroke(1,C.BORDER,0.3,b) end
			local p=Instance.new("UIPadding")
p.PaddingLeft=UDim.new(0,10)
p.Parent=b
local ci=i
			if isCurrent then b.BackgroundColor3=C.SURFACE
Svc.TweenService:Create(b,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=C.ACCENT_DIM}):Play() end
			b.MouseButton1Click:Connect(function()
				local ctrl=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftControl) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightControl)
				local shift=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftShift) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightShift)
				if shift then showCategorySelector(ci) elseif ctrl then addTrackToQueue(ci)
				else setCurrentTrack(ci,true) end
			end)
			b.MouseEnter:Connect(function() if not(ci==St.currentTrackIndex) then Svc.TweenService:Create(b,TweenInfo.new(0.12,Enum.EasingStyle.Quad),{BackgroundColor3=C.ELEVATED}):Play() end;St.hoveredTrackIndex=ci;St.hoveredTrackInCategory=false end)
			b.MouseLeave:Connect(function() Svc.TweenService:Create(b,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{BackgroundColor3=ci==St.currentTrackIndex and C.ACCENT_DIM or C.SURFACE}):Play();St.hoveredTrackIndex=nil;St.hoveredTrackInCategory=false end)
		end
		local any=false
for _,c in ipairs(UI.listScroll:GetChildren()) do if c:IsA("TextButton") or c:IsA("Frame") then any=true
break end end
		if not any then local n=Instance.new("TextLabel")
n.Size=UDim2.new(1,0,0,40)
n.BackgroundTransparency=1
n.Font=Enum.Font.GothamMedium
n.Text='No results for "'..q..'"'
n.TextColor3=C.TEXT3
n.TextSize=12
n.ZIndex=2
n.Parent=UI.listScroll end
		local _c
_c=Svc.RunService.Heartbeat:Connect(function() _c:Disconnect();UI.listScroll.CanvasPosition=sc end)
return
	end
	for ci,cat in ipairs(Dat.categories) do
		local TH,TG,HH,IP=28,4,30,4
local nt=#cat.Tracks
local exp=St.expandedCategories[ci]
local exH=HH+IP+nt*(TH+TG)+IP
local coH=HH
		local cf=Instance.new("Frame")
cf.Name="Category_"..ci
cf.Size=UDim2.new(1,0,0,exp and exH or coH)
cf.BackgroundTransparency=1
cf.ClipsDescendants=true
cf.LayoutOrder=lo
cf.ZIndex=2
cf.Parent=UI.listScroll
lo=lo+1
		local cb2=Instance.new("TextButton")
cb2.Name="CategoryButton"
cb2.Position=UDim2.new(0,0,0,0)
cb2.Size=UDim2.new(1,0,0,HH)
cb2.BackgroundColor3=C.ACCENT_DIM
cb2.AutoButtonColor=false
cb2.Active=true
cb2.Font=Enum.Font.GothamMedium
cb2.Text=(exp and "v  " or ">  ")..cat.Name
cb2.TextColor3=Color3.fromRGB(255,255,255)
cb2.TextXAlignment=Enum.TextXAlignment.Left
cb2.TextSize=12
cb2.BorderSizePixel=0
cb2.ZIndex=2
cb2.Parent=cf
applyCornerRadius(8,cb2)
applyStroke(1,C.BORDER_LIT,0.3,cb2)
		local hp=Instance.new("UIPadding")
hp.PaddingLeft=UDim.new(0,10)
hp.Parent=cb2
		local ic=Instance.new("Frame")
ic.Name="InnerContainer"
ic.Position=UDim2.new(0,0,0,HH)
ic.Size=UDim2.new(1,0,0,exH-HH)
ic.BackgroundTransparency=1
ic.ZIndex=2
ic.Parent=cf
		local il=Instance.new("UIListLayout")
il.Padding=UDim.new(0,TG)
il.SortOrder=Enum.SortOrder.LayoutOrder
il.Parent=ic
		local ipd=Instance.new("UIPadding")
ipd.PaddingTop=UDim.new(0,IP)
ipd.PaddingBottom=UDim.new(0,IP)
ipd.PaddingLeft=UDim.new(0,16)
ipd.Parent=ic
		il:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() if not exp then return end;cf.Size=UDim2.new(1,0,0,HH+il.AbsoluteContentSize.Y+IP*2) end)
		local function updCB() cb2.Text=(St.expandedCategories[ci] and "v  " or ">  ")..cat.Name end
		local function setExp(nexp,anim) St.expandedCategories[ci]=nexp
updCB()
local th=nexp and exH or coH
if anim then Svc.TweenService:Create(cf,nexp and TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out) or TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(1,0,0,th)}):Play() else cf.Size=UDim2.new(1,0,0,th) end end
		cb2.MouseButton1Click:Connect(function() local ctrl=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftControl) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightControl);if ctrl then for _,ti in ipairs(cat.Tracks) do addTrackToQueue(ti) end else setExp(not St.expandedCategories[ci],true) end end)
		cb2.MouseButton2Click:Connect(function() St.categoryBeingRenamed=ci;UI.categoryRenameInput.Text=cat.Name;UI.categoryRenameFrame.Visible=true;UI.categoryRenameInput:CaptureFocus() end)
		cb2.MouseEnter:Connect(function() cb2.BackgroundColor3=C.ACCENT;cb2.TextColor3=AT;St.hoveredCategoryIndex=ci end)
		cb2.MouseLeave:Connect(function() cb2.BackgroundColor3=C.ACCENT_DIM;cb2.TextColor3=Color3.fromRGB(255,255,255);St.hoveredCategoryIndex=nil end)
		for pi,ti in ipairs(cat.Tracks) do
			if ti<=#Dat.trackList then
				local t=Dat.trackList[ti]
local tb=Instance.new("TextButton")
tb.Name="CT_"..pi
tb.Size=UDim2.new(1,-4,0,TH)
tb.BackgroundColor3=C.SURFACE
tb.AutoButtonColor=false
tb.Active=true
tb.Font=Enum.Font.Gotham
tb.Text=shortenText(t.DisplayName,26)
tb.TextColor3=C.TEXT2
tb.TextXAlignment=Enum.TextXAlignment.Left
tb.TextSize=11
tb.BorderSizePixel=0
tb.LayoutOrder=pi
tb.ZIndex=2
tb.Parent=ic
applyCornerRadius(6,tb)
applyStroke(1,C.BORDER,0.4,tb)
				local tp=Instance.new("UIPadding")
tp.PaddingLeft=UDim.new(0,8)
tp.Parent=tb
				local ac2=Instance.new("Frame")
ac2.AnchorPoint=Vector2.new(1,0.5)
ac2.Position=UDim2.new(1,-4,0.5,0)
ac2.Size=UDim2.new(0,38,0,20)
ac2.BackgroundTransparency=1
ac2.Visible=false
ac2.ZIndex=2
ac2.Parent=tb
				local catI,posI=ci,pi
				local function createCategoryAction(lbl,xp,md)
					local a=Instance.new("TextButton")
a.AnchorPoint=Vector2.new(0,0.5)
a.Position=UDim2.new(0,xp,0.5,0)
a.Size=UDim2.new(0,17,0,18)
a.BackgroundColor3=C.ELEVATED
a.AutoButtonColor=false
a.Font=Enum.Font.GothamBold
a.Text=lbl
a.TextSize=9
a.TextColor3=C.ACCENT
a.BorderSizePixel=0
a.ZIndex=2
a.Parent=ac2
applyCornerRadius(5,a)
applyStroke(1,C.BORDER_LIT,0.4,a)
					a.MouseEnter:Connect(function() a.BackgroundColor3=C.ACCENT;a.TextColor3=AT end)
a.MouseLeave:Connect(function() a.BackgroundColor3=C.ELEVATED;a.TextColor3=C.ACCENT end)
					a.MouseButton1Click:Connect(function() local thc=Dat.categories[catI];if not thc then return end;local sp=posI+md;if sp<1 or sp>#thc.Tracks then return end;thc.Tracks[posI],thc.Tracks[sp]=thc.Tracks[sp],thc.Tracks[posI];saveCategoriesToDisk();rebuildTrackListUI() end)
				end
				createCategoryAction("↑",0,-1)
createCategoryAction("↓",20,1)
				local cti=ti
local isCurrent=cti==St.currentTrackIndex
				if isCurrent then tb.BackgroundColor3=C.SURFACE
Svc.TweenService:Create(tb,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=C.ACCENT_DIM}):Play()
local str=applyStroke(1,C.ACCENT,1,tb)
if str then Svc.TweenService:Create(str,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency=0.2}):Play() end end
				tb.MouseButton1Click:Connect(function()
					local ctrl=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftControl) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightControl)
					local shift=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftShift) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightShift)
					if shift then removeTrackFromCategory(cti);rebuildTrackListUI()
					elseif ctrl then addTrackToQueue(cti)
					else setCurrentTrack(cti,true) end
				end)
				tb.MouseEnter:Connect(function()
					if not(cti==St.currentTrackIndex) then Svc.TweenService:Create(tb,TweenInfo.new(0.12,Enum.EasingStyle.Quad),{BackgroundColor3=C.ELEVATED}):Play() end
					ac2.Visible=true;St.hoveredTrackIndex=cti;St.hoveredTrackInCategory=true
					if #t.DisplayName>26 then UI.listTooltipText.Text=t.DisplayName;local mp=Svc.UserInput:GetMouseLocation();UI.listTooltip.Position=UDim2.fromOffset(mp.X+14,mp.Y-6);UI.listTooltip.Visible=true end
				end)
				tb.MouseLeave:Connect(function() Svc.TweenService:Create(tb,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{BackgroundColor3=cti==St.currentTrackIndex and C.ACCENT_DIM or C.SURFACE}):Play();ac2.Visible=false;St.hoveredTrackIndex=nil;St.hoveredTrackInCategory=false;UI.listTooltip.Visible=false end)
			end
		end
	end
	for _,i in ipairs(getOrderedUncategorizedTracks()) do
		local t=Dat.trackList[i]
if not t then continue end
local ref={idx=i}
local isCurrent=i==St.currentTrackIndex
		local btn=Instance.new("TextButton")
btn.Name="Track_"..i
btn.Size=UDim2.new(1,0,0,30)
btn.LayoutOrder=lo
btn.BackgroundColor3=isCurrent and C.ACCENT_DIM or C.SURFACE
btn.AutoButtonColor=false
btn.Active=true
btn.Font=isCurrent and Enum.Font.GothamMedium or Enum.Font.Gotham
btn.Text=shortenText(t.DisplayName,30)
btn.TextColor3=isCurrent and C.ACCENT or C.TEXT2
btn.TextXAlignment=Enum.TextXAlignment.Left
btn.TextSize=12
btn.BorderSizePixel=0
btn.ZIndex=2
btn.Parent=UI.listScroll
lo=lo+1
applyCornerRadius(8,btn)
		if isCurrent then local str=applyStroke(1,C.ACCENT,1,btn)
if str then Svc.TweenService:Create(str,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency=0.2}):Play() end else applyStroke(1,C.BORDER,0.3,btn) end
		local bp2=Instance.new("UIPadding")
bp2.PaddingLeft=UDim.new(0,10)
bp2.Parent=btn
		if t.Type=="mp3" and t.FileName then Dat.listButtonRefs[t.FileName]={btn=btn,ref=ref} end
		if isCurrent then btn.BackgroundColor3=C.SURFACE
Svc.TweenService:Create(btn,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=C.ACCENT_DIM}):Play() end
		local ac3=Instance.new("Frame")
ac3.AnchorPoint=Vector2.new(1,0.5)
ac3.Position=UDim2.new(1,-4,0.5,0)
ac3.Size=UDim2.new(0,38,0,22)
ac3.BackgroundTransparency=1
ac3.Visible=false
ac3.ZIndex=2
ac3.Parent=btn
		local function createReorderArrow(lbl,xp,md)
			local a=Instance.new("TextButton")
a.Name=lbl
a.AnchorPoint=Vector2.new(0,0.5)
a.Position=UDim2.new(0,xp,0.5,0)
a.Size=UDim2.new(0,17,0,20)
a.BackgroundColor3=C.ELEVATED
a.AutoButtonColor=false
a.Font=Enum.Font.GothamBold
a.Text=lbl
a.TextSize=9
a.TextColor3=C.ACCENT
a.BorderSizePixel=0
a.ZIndex=2
a.Parent=ac3
applyCornerRadius(5,a)
applyStroke(1,C.BORDER_LIT,0.4,a)
			a.MouseEnter:Connect(function() a.BackgroundColor3=C.ACCENT;a.TextColor3=AT end)
a.MouseLeave:Connect(function() a.BackgroundColor3=C.ELEVATED;a.TextColor3=C.ACCENT end)
			a.MouseButton1Click:Connect(function() local tid=getTrackId(t);for p,id in ipairs(Dat.trackOrderList) do if id==tid then local sp=p+md;if sp>=1 and sp<=#Dat.trackOrderList then Dat.trackOrderList[p],Dat.trackOrderList[sp]=Dat.trackOrderList[sp],Dat.trackOrderList[p];saveTrackOrder();rebuildTrackListUI() end;return end end end)
		end
		createReorderArrow("↑",0,-1)
createReorderArrow("↓",20,1)
		btn.MouseButton1Down:Connect(function() local ctrl=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftControl) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightControl);if ctrl then St.draggedButton=btn;St.isDraggingToQueue=true;St.draggedTrackIndex=ref.idx;St.isDraggingToCategory=true end end)
		btn.MouseButton1Click:Connect(function()
			local ctrl=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftControl) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightControl)
			local shift=Svc.UserInput:IsKeyDown(Enum.KeyCode.LeftShift) or Svc.UserInput:IsKeyDown(Enum.KeyCode.RightShift)
			if shift then showCategorySelector(ref.idx)
			elseif ctrl then addTrackToQueue(ref.idx)
			else setCurrentTrack(ref.idx,true) end
		end)
		btn.MouseEnter:Connect(function()
			if not(ref.idx==St.currentTrackIndex) then Svc.TweenService:Create(btn,TweenInfo.new(0.12,Enum.EasingStyle.Quad),{BackgroundColor3=C.ELEVATED}):Play() end
			ac3.Visible=true;St.hoveredTrackIndex=ref.idx;St.hoveredTrackInCategory=false
			if #t.DisplayName>30 then UI.listTooltipText.Text=t.DisplayName;local mp=Svc.UserInput:GetMouseLocation();UI.listTooltip.Position=UDim2.fromOffset(mp.X+14,mp.Y-6);UI.listTooltip.Visible=true end
		end)
		btn.MouseLeave:Connect(function() Svc.TweenService:Create(btn,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{BackgroundColor3=ref.idx==St.currentTrackIndex and C.ACCENT_DIM or C.SURFACE}):Play();ac3.Visible=false;St.hoveredTrackIndex=nil;St.hoveredTrackInCategory=false;UI.listTooltip.Visible=false end)
	end
	local _c
_c=Svc.RunService.Heartbeat:Connect(function() _c:Disconnect();UI.listScroll.CanvasPosition=sc end)
end
Svc.UserInput.InputBegan:Connect(function(inp)
	if inp.KeyCode==Enum.KeyCode.Delete then
		if St.hoveredCategoryIndex then table.remove(Dat.categories,St.hoveredCategoryIndex);saveCategoriesToDisk();rebuildTrackListUI();St.hoveredCategoryIndex=nil
		elseif St.hoveredTrackIndex then local t=Dat.trackList[St.hoveredTrackIndex];if t then St.pendingDeleteTrackIndex=St.hoveredTrackIndex;UI.deleteConfirmMessage.Text='Would you like to delete "'..t.DisplayName..'"?';UI.deleteConfirmFrame.Visible=true end end
	end
end)
UI.deleteConfirmNo.MouseButton1Click:Connect(function() UI.deleteConfirmFrame.Visible=false;St.pendingDeleteTrackIndex=nil end)
UI.deleteConfirmYes.MouseButton1Click:Connect(function()
	if not St.pendingDeleteTrackIndex then return end;local ti=St.pendingDeleteTrackIndex;local t=Dat.trackList[ti];UI.deleteConfirmFrame.Visible=false;St.pendingDeleteTrackIndex=nil;if not t then return end
	local tb=nil;for _,c in ipairs(UI.listScroll:GetChildren()) do if c.Name=="Track_"..ti and c:IsA("TextButton") then tb=c;break end end
	local function doDel()
		if t.Type=="soundid" then
			removeTrackFromCategory(ti);local s=Dat.createdSounds[ti];if s then s:Destroy() end;table.remove(Dat.trackList,ti);table.remove(Dat.createdSounds,ti);rebuildCategoryTrackIndices();saveCategoriesToDisk();saveSoundIdTracks()
		elseif t.Type=="mp3" and t.Path then
			Dat.permanentlyDeleted[t.Path]=true;if isfile(t.Path) then delfile(t.Path) end
			for i=#Dat.lastMp3Files,1,-1 do if Dat.lastMp3Files[i].Path==t.Path then table.remove(Dat.lastMp3Files,i);break end end
			local tid=getTrackId(t);for _,cat in ipairs(Dat.categories) do for i,ct in ipairs(cat.TrackTIDs or {}) do if ct==tid then table.remove(cat.TrackTIDs,i);break end end end
			Dat.suppressAutoNotify[t.FileName or ""]=true;local s=Dat.createdSounds[ti];if s then s:Destroy() end;table.remove(Dat.trackList,ti);table.remove(Dat.createdSounds,ti);rebuildCategoryTrackIndices();saveCategoriesToDisk()
		end
		if St.currentTrackIndex==ti then if #Dat.createdSounds>0 then St.currentTrackIndex=math.min(St.currentTrackIndex,#Dat.createdSounds);setCurrentTrack(St.currentTrackIndex,false) else St.currentTrackIndex=1;sound=nil;updateTrackDisplay("no tracks loaded","no tracks loaded") end
		elseif St.currentTrackIndex>ti then St.currentTrackIndex=St.currentTrackIndex-1 end
		rebuildTrackListUI();showTrackNotification(t.DisplayName,true)
	end
	if tb then Svc.TweenService:Create(tb,TweenInfo.new(0.06,Enum.EasingStyle.Linear),{BackgroundColor3=C.DANGER,TextTransparency=0.4}):Play();task.delay(0.06,doDel) else doDel() end
end)
Svc.UserInput.InputEnded:Connect(function(inp)
	if inp.UserInputType~=Enum.UserInputType.MouseButton1 then return end
	if St.isDraggingToQueue and St.draggedButton then
		local mp=Svc.UserInput:GetMouseLocation();local qp=UI.queuePanel.AbsolutePosition;local qs=UI.queuePanel.AbsoluteSize
		if UI.queuePanel.Visible and mp.X>=qp.X and mp.X<=qp.X+qs.X and mp.Y>=qp.Y and mp.Y<=qp.Y+qs.Y then local is=St.draggedButton.Name:match("Track_(%d+)");if is then addTrackToQueue(tonumber(is)) end end
	end
	if St.isDraggingToCategory and St.draggedTrackIndex then
		local mp=Svc.UserInput:GetMouseLocation();local dragTrack=Dat.trackList[St.draggedTrackIndex]
		if dragTrack then
			local dragTID=getTrackId(dragTrack)
			for ci,cat in ipairs(Dat.categories) do for _,ch in ipairs(UI.listScroll:GetChildren()) do if ch.Name=="Category_"..ci then local cb3=ch:FindFirstChild("CategoryButton");if cb3 then local bp=cb3.AbsolutePosition;local bs=cb3.AbsoluteSize;if mp.X>=bp.X and mp.X<=bp.X+bs.X and mp.Y>=bp.Y and mp.Y<=bp.Y+bs.Y then
				local dup=false;for _,t in ipairs(cat.TrackTIDs or {}) do if t==dragTID then dup=true;break end end
				if not dup then if not cat.TrackTIDs then cat.TrackTIDs={} end;table.insert(cat.TrackTIDs,dragTID);rebuildCategoryTrackIndices();saveCategoriesToDisk();rebuildTrackListUI() end;break end end end end end
		end
	end;St.draggedButton=nil;St.isDraggingToQueue=false;St.draggedTrackIndex=nil;St.isDraggingToCategory=false
end)
UI.addCategoryBtn.MouseButton1Click:Connect(function() table.insert(Dat.categories,{Name="New Category",Tracks={}});saveCategoriesToDisk();rebuildTrackListUI() end)
UI.categoryRenameCancel.MouseButton1Click:Connect(function() UI.categoryRenameFrame.Visible=false;St.categoryBeingRenamed=nil;St.pendingRenameSoundIdIndex=nil;UI.categoryRenameTitle.Text="Rename Category" end)
UI.categoryRenameConfirm.MouseButton1Click:Connect(function()
	local newName=UI.categoryRenameInput.Text;if newName=="" then return end
	if St.pendingRenameSoundIdIndex then
		local idx=St.pendingRenameSoundIdIndex;local tr=Dat.trackList[idx]
		if tr and tr.Type=="soundid" then tr.DisplayName=newName;tr.FullName=newName;local s=Dat.createdSounds[idx];if s then s.Name=newName end;if idx==St.currentTrackIndex then updateTrackDisplay(newName,newName) end;saveSoundIdTracks();rebuildTrackListUI() end
		UI.categoryRenameFrame.Visible=false;St.pendingRenameSoundIdIndex=nil;UI.categoryRenameTitle.Text="Rename Category"
	elseif St.categoryBeingRenamed then
		Dat.categories[St.categoryBeingRenamed].Name=newName;saveCategoriesToDisk();rebuildTrackListUI();UI.categoryRenameFrame.Visible=false;St.categoryBeingRenamed=nil
	end
end)
UI.categorySelectCancel.MouseButton1Click:Connect(function() UI.categorySelectFrame.Visible=false;St.selectingCategoryForTrack=false;St.pendingTrackIndexForCategory=nil end)
local function refreshPlayButton()
	local ct=TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	if St.isPaused then UI.playPauseBtn.Text="play"
Svc.TweenService:Create(UI.playPauseBtn,ct,{BackgroundColor3=C.ACCENT}):Play()
Svc.TweenService:Create(UI.playPauseBtn,ct,{TextColor3=AT}):Play()
	else UI.playPauseBtn.Text="pause"
Svc.TweenService:Create(UI.playPauseBtn,ct,{BackgroundColor3=C.ELEVATED}):Play()
Svc.TweenService:Create(UI.playPauseBtn,ct,{TextColor3=C.TEXT}):Play() end
end
refreshPlayButton=refreshPlayButton
UI.playPauseBtn.MouseButton1Click:Connect(function()
	if not sound then return end
	if St.isPaused then
		if Dat.activeFadeOutTween then Dat.activeFadeOutTween:Cancel();Dat.activeFadeOutTween=nil end
		if St.crossfadeEnabled then Svc.TweenService:Create(sound,TweenInfo.new(Cfg.CROSSFADE_TIME,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=St.currentVolume}):Play() else sound.Volume=St.currentVolume end
		local ok=pcall(function() sound:Resume() end);if not ok or not sound.IsPlaying then sound:Play() end;St.isPaused=false
	else
		if St.crossfadeEnabled then
			local cs=sound;local fo=Svc.TweenService:Create(sound,TweenInfo.new(Cfg.CROSSFADE_TIME,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=0});Dat.activeFadeOutTween=fo
			fo.Completed:Connect(function() if Dat.activeFadeOutTween==fo then Dat.activeFadeOutTween=nil;if St.isPaused and cs==sound then pcall(function() cs:Pause() end);if cs.IsPlaying then cs:Stop() end end end end);fo:Play()
		else local ok=pcall(function() sound:Pause() end);if not ok then sound:Stop() end end
		St.isPaused=true
	end;refreshPlayButton()
end)
local function getCategoryForTrack(idx) for ci,cat in ipairs(Dat.categories) do for pi,v in ipairs(cat.Tracks) do if v==idx then return ci,pi end end end
return nil,nil end
local function nextUncategorizedTrack(si,dir) local idx=si
local cnt=#Dat.createdSounds
for _=1,cnt do idx=idx+dir
if idx<1 then idx=cnt elseif idx>cnt then idx=1 end
if not isTrackInCategory(idx) then return idx end end
return si end
local function getAdjacentTrackIndex(dir) local ci,pi=getCategoryForTrack(St.currentTrackIndex)
if ci then local cat=Dat.categories[ci]
local np=pi+dir
if np>=1 and np<=#cat.Tracks then return cat.Tracks[np] end
return nextUncategorizedTrack(St.currentTrackIndex,dir) end
return nextUncategorizedTrack(St.currentTrackIndex,dir) end
local function pickNextTrackIndex()
	if St.shuffleEnabled and #Dat.createdSounds>1 then
		local ci,_=getCategoryForTrack(St.currentTrackIndex)
		if ci then local cat=Dat.categories[ci]
if #cat.Tracks>1 then local att,ni=0,St.currentTrackIndex
repeat ni=cat.Tracks[math.random(1,#cat.Tracks)]
att=att+1 until ni~=St.currentTrackIndex or att>20
return ni end
		else local att=0
local ni=St.currentTrackIndex
repeat ni=math.random(1,#Dat.createdSounds)
att=att+1
if not isTrackInCategory(ni) then return ni end until att>100 end
		return nextUncategorizedTrack(St.currentTrackIndex,1)
	end
return getAdjacentTrackIndex(1)
end
function setCurrentTrack(newIdx,autoPlay)
	if #Dat.createdSounds==0 then updateTrackDisplay("no tracks loaded","no tracks loaded")
return end
	if newIdx<1 then newIdx=#Dat.createdSounds elseif newIdx>#Dat.createdSounds then newIdx=1 end
	local os2=sound
local ns=Dat.createdSounds[newIdx]
if not ns then return end
	if Dat.soundEndedConnection then Dat.soundEndedConnection:Disconnect()
Dat.soundEndedConnection=nil end
	if Dat.activeFadeOutTween then Dat.activeFadeOutTween:Cancel()
Dat.activeFadeOutTween=nil end
	Dat.crossfadeCleanupGen=Dat.crossfadeCleanupGen+1
for s,_ in pairs(Dat.crossfadingSounds) do pcall(function() s.Volume=(s==ns) and St.currentVolume or 0 end) end
Dat.crossfadingSounds={}
	if os2 then pcall(function() os2:Stop() end)
os2.Volume=St.currentVolume end
	St.crossfadeTriggered=false
UI.progressFill.Size=UDim2.new(0,0,1,0)
St.draggingProgress=false
pcall(function() ns.TimePosition=0 end)
	St.currentTrackIndex=newIdx
sound=ns
moveAudioEffects(sound)
sound.PlaybackSpeed=(St.currentSpeed<=0) and 0.01 or St.currentSpeed
sound.Looped=false
	if autoPlay then
		if St.crossfadeEnabled and os2 and os2~=sound then Dat.crossfadingSounds[sound]=true
sound.Volume=0
sound:Play()
St.isPaused=false
local it=Svc.TweenService:Create(sound,TweenInfo.new(Cfg.CROSSFADE_TIME,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=St.currentVolume})
it.Completed:Connect(function() Dat.crossfadingSounds[sound]=nil end)
it:Play()
		else sound.Volume=St.currentVolume
sound:Play()
St.isPaused=false end
	else sound.Volume=St.currentVolume
St.isPaused=true end
	refreshPlayButton()
local inf=Dat.trackList[St.currentTrackIndex]
	if inf then updateTrackDisplay(inf.DisplayName,inf.FullName or inf.DisplayName)
if lyricsOverlay and lyricsOverlay.updateFlagBtn then lyricsOverlay.updateFlagBtn(flaggedInstrumental[inf.DisplayName]==true) end
if St.lyricsEnabled then Dat.lyricsFetchGen=Dat.lyricsFetchGen+1
fetchLyricsForTrack(inf.DisplayName,Dat.lyricsFetchGen) end else updateTrackDisplay(sound.Name,sound.Name) end
	if St.cinematicMode and _cinGui then for _,ch in ipairs(_cinGui:GetChildren()) do if ch:IsA("TextLabel") then pcall(function() ch:Destroy() end) end end end
	do
		local oldIdx=Dat.prevTrackIndex
Dat.prevTrackIndex=St.currentTrackIndex
		local fadeTI=TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
		local oldBtn=oldIdx and UI.listScroll:FindFirstChild("Track_"..oldIdx)
		if oldBtn and oldBtn:IsA("TextButton") then
			Svc.TweenService:Create(oldBtn,fadeTI,{BackgroundColor3=C.SURFACE,TextColor3=C.TEXT2}):Play()
			local oldStr=oldBtn:FindFirstChildOfClass("UIStroke")
if oldStr then Svc.TweenService:Create(oldStr,fadeTI,{Transparency=1}):Play() end
			task.delay(0.2,function() task.defer(rebuildTrackListUI) end)
		else
			task.defer(rebuildTrackListUI)
		end
	end
	if sound.TimeLength and sound.TimeLength>0 then animateTimeDisplay("0:00 / "..formatTime(sound.TimeLength)) end
	Dat.soundEndedConnection=sound.Ended:Connect(function()
		if not sound then return end
		if #Dat.queueList>0 then local nq=table.remove(Dat.queueList,1);rebuildQueueUI();setCurrentTrack(nq.TrackIndex,true)
		elseif St.repeatEnabled then sound.TimePosition=0;sound:Play()
		else setCurrentTrack(pickNextTrackIndex(),true) end
	end)
end
local function playNextTrack() if #Dat.queueList>0 then local nq=table.remove(Dat.queueList,1)
rebuildQueueUI()
setCurrentTrack(nq.TrackIndex,true) else setCurrentTrack(pickNextTrackIndex(),true) end end
UI.currentTrackButton.MouseButton1Click:Connect(function() UI.soundIdFrame.Visible=true;UI.soundIdInput.Text="";UI.soundIdInput:CaptureFocus() end)
UI.soundIdCancel.MouseButton1Click:Connect(function() UI.soundIdFrame.Visible=false end)
local sidBusy=false
UI.soundIdConfirm.MouseButton1Click:Connect(function()
	if sidBusy then return end;sidBusy=true;local sid=tonumber(UI.soundIdInput.Text)
	if not sid then UI.soundIdTitle.Text="Invalid Sound ID!";task.wait(2);UI.soundIdTitle.Text="Enter Roblox Sound ID";sidBusy=false;return end
	for _,t in ipairs(Dat.trackList) do if t.Type=="soundid" and tostring(t.SoundId)==tostring(sid) then UI.soundIdTitle.Text="Already added!";task.wait(2);UI.soundIdTitle.Text="Enter Roblox Sound ID";sidBusy=false;return end end
	UI.soundIdTitle.Text="Loading..."
	local ok,pi=pcall(function() return Svc.MarketplaceService:GetProductInfo(sid) end)
	if not ok or not pi or pi.AssetTypeId~=3 then UI.soundIdTitle.Text="Invalid Roblox Sound ID!";task.wait(2);UI.soundIdTitle.Text="Enter Roblox Sound ID";sidBusy=false;return end
	local ns=Instance.new("Sound");ns.Name=pi.Name;ns.SoundId="rbxassetid://"..sid;ns.Volume=St.currentVolume;ns.PlaybackSpeed=St.currentSpeed;ns.Looped=false;ns.Parent=soundsFolder
	table.insert(Dat.createdSounds,ns);table.insert(Dat.trackList,{DisplayName=pi.Name,FullName=pi.Name,Type="soundid",SoundId=sid})
	if Dat.attachVolumeGuard then Dat.attachVolumeGuard(ns) end
	UI.soundIdFrame.Visible=false;UI.soundIdTitle.Text="Enter Roblox Sound ID";local nti=#Dat.trackList;local sic=getSoundIdCategory() or getOrCreateSoundIdCategory()
	local dup=false;for _,idx in ipairs(sic.Tracks) do if idx==nti then dup=true;break end end;if not dup then table.insert(sic.Tracks,nti) end
	saveCategoriesToDisk();saveSoundIdTracks();rebuildTrackListUI();setCurrentTrack(#Dat.createdSounds,true);sidBusy=false
end)
UI.currentTrackButton.MouseEnter:Connect(function()
	if not UI.tooltipText.Text or UI.tooltipText.Text=="" then return end
	local ts=game:GetService("TextService"):GetTextSize(UI.tooltipText.Text,14,Enum.Font.GothamSemibold,Vector2.new(math.huge,math.huge))
	if ts.X<=UI.currentTrackButton.AbsoluteSize.X-8 then return end
	UI.tooltipText.Text=UI.tooltipText.Text
	local mp=Svc.UserInput:GetMouseLocation()
	UI.tooltip.Position=UDim2.fromOffset(mp.X+14,mp.Y-6)
	UI.tooltip.Visible=true
end)
UI.currentTrackButton.MouseLeave:Connect(function() UI.tooltip.Visible=false end)
Svc.UserInput.InputChanged:Connect(function(inp)
	if inp.UserInputType==Enum.UserInputType.MouseMovement and UI.tooltip.Visible then
		local mp=Svc.UserInput:GetMouseLocation()
		UI.tooltip.Position=UDim2.fromOffset(mp.X+14,mp.Y-6)
	end
end)
UI.prevBtn.MouseButton1Click:Connect(function() if tick()-St.lastTrackSwitchTime<Cfg.TRACK_SWITCH_COOLDOWN then return end;St.lastTrackSwitchTime=tick();setCurrentTrack(getAdjacentTrackIndex(-1),true) end)
UI.nextBtn.MouseButton1Click:Connect(function() if tick()-St.lastTrackSwitchTime<Cfg.TRACK_SWITCH_COOLDOWN then return end;St.lastTrackSwitchTime=tick();playNextTrack() end)
local POT,PCT=TweenInfo.new(0.7,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.In)
UI.toggleListBtn.MouseButton1Click:Connect(function()
	St.listPanelOpen=not St.listPanelOpen
	if St.listPanelOpen then UI.toggleListBtn.Text="<";UI.listPanel.Visible=true;Svc.TweenService:Create(UI.listPanel,POT,{Position=UDim2.new(0,-Cfg.LIST_WIDTH-Cfg.PANEL_GAP,0,0)}):Play();Svc.TweenService:Create(UI.toggleListBtn,POT,{Position=UDim2.new(0,-Cfg.LIST_WIDTH-Cfg.PANEL_GAP-6,0.5,0)}):Play()
	else UI.toggleListBtn.Text=">";local pt=Svc.TweenService:Create(UI.listPanel,PCT,{Position=UDim2.new(0,0,0,0)});pt.Completed:Connect(function() UI.listPanel.Visible=false end);pt:Play();Svc.TweenService:Create(UI.toggleListBtn,PCT,{Position=UDim2.new(0,-6,0.5,0)}):Play() end
end)
UI.toggleQueueBtn.MouseButton1Click:Connect(function()
	St.queuePanelOpen=not St.queuePanelOpen
	if St.queuePanelOpen then UI.toggleQueueBtn.Text=">";UI.queuePanel.Visible=true;Svc.TweenService:Create(UI.queuePanel,POT,{Position=UDim2.new(1,Cfg.PANEL_GAP,0,0)}):Play();Svc.TweenService:Create(UI.toggleQueueBtn,POT,{Position=UDim2.new(1,Cfg.PANEL_GAP+Cfg.LIST_WIDTH+6,0.5,0)}):Play()
	else UI.toggleQueueBtn.Text="<";local pt=Svc.TweenService:Create(UI.queuePanel,PCT,{Position=UDim2.new(1,-Cfg.LIST_WIDTH,0,0)});pt.Completed:Connect(function() UI.queuePanel.Visible=false end);pt:Play();Svc.TweenService:Create(UI.toggleQueueBtn,PCT,{Position=UDim2.new(1,6,0.5,0)}):Play() end
end)
task.spawn(function()
	while true do
		task.wait(Cfg.AUTO_SCAN_INTERVAL);local mp3s=scanMusicDirectory();local op,np={},{}
		for _,f in ipairs(Dat.lastMp3Files) do op[f.Path]=true end
		local nf,rf={},{}
		for _,f in ipairs(mp3s) do np[f.Path]=true;if not op[f.Path] then table.insert(nf,f.FileName) end end
		for _,f in ipairs(Dat.lastMp3Files) do if not np[f.Path] then table.insert(rf,f.FileName) end end
		local rn,rr={},{};local rnFiles={}
		for _,fn in ipairs(nf) do if Dat.suppressAutoNotify[fn] then Dat.suppressAutoNotify[fn]=nil else table.insert(rn,fn);table.insert(rnFiles,fn) end end
		for _,fn in ipairs(rf) do if Dat.suppressAutoNotify[fn] then Dat.suppressAutoNotify[fn]=nil else table.insert(rr,fn) end end
		if #rn>0 or #rr>0 then
			local wp=sound and sound.IsPlaying;local ct2=sound and sound.TimePosition or 0;local otp=Dat.trackList[St.currentTrackIndex] and Dat.trackList[St.currentTrackIndex].Path
			loadAllMusicTracks(true);rebuildCategoryTrackIndices();saveCategoriesToDisk()
			local fs=false;if otp then for i,t in ipairs(Dat.trackList) do if t.Path==otp then St.currentTrackIndex=i;fs=true;break end end end
			if not fs or St.currentTrackIndex>#Dat.createdSounds then St.currentTrackIndex=math.max(1,math.min(St.currentTrackIndex,#Dat.createdSounds)) end
			if #Dat.createdSounds>0 then
				sound=Dat.createdSounds[St.currentTrackIndex]
				if sound then
					moveAudioEffects(sound);sound.Volume=St.currentVolume;sound.PlaybackSpeed=(St.currentSpeed<=0) and 0.01 or St.currentSpeed
					if fs and wp then pcall(function() sound.TimePosition=math.min(ct2,math.max(0,sound.TimeLength-0.1)) end);if not sound.IsPlaying then sound:Play() end;St.isPaused=false else if sound.IsPlaying then sound:Stop() end;St.isPaused=true end
					local inf=Dat.trackList[St.currentTrackIndex];if inf then updateTrackDisplay(inf.DisplayName,inf.FullName or inf.DisplayName) end
					if sound.TimeLength and sound.TimeLength>0 then UI.timeDisplay.Text="0:00 / "..formatTime(sound.TimeLength);St.lastDisplayedTime=UI.timeDisplay.Text end
					if Dat.soundEndedConnection then Dat.soundEndedConnection:Disconnect() end
					Dat.soundEndedConnection=sound.Ended:Connect(function()
						if not sound then return end
						if #Dat.queueList>0 then local nq=table.remove(Dat.queueList,1);rebuildQueueUI();setCurrentTrack(nq.TrackIndex,true)
						elseif St.repeatEnabled then sound.TimePosition=0;sound:Play()
						else setCurrentTrack(pickNextTrackIndex(),true) end
					end)
				end
			else sound=nil;St.isPaused=true;updateTrackDisplay("no tracks loaded","no tracks loaded") end
			refreshPlayButton();rebuildTrackListUI()
			if #rnFiles>0 then task.spawn(function() task.wait(0.12);for _,fn in ipairs(rnFiles) do local ref=Dat.listButtonRefs[fn];local btn=ref and ref.btn;if btn and btn.Parent then local tw=Svc.TweenService:Create(btn,TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{BackgroundColor3=C.ACCENT});tw:Play();local done=false;local cc;cc=btn.MouseButton1Click:Connect(function() done=true;cc:Disconnect();tw:Cancel();if btn.Parent then btn.BackgroundColor3=C.SURFACE end end);task.delay(5,function() if not done then done=true;pcall(function() cc:Disconnect() end);tw:Cancel();if btn.Parent then Svc.TweenService:Create(btn,TweenInfo.new(0.3),{BackgroundColor3=C.SURFACE}):Play() end end end) end end end) end
			for _,fn in ipairs(rr) do showTrackNotification(fn,true) end;for _,fn in ipairs(rn) do showTrackNotification(fn,false) end
		end
	end
end)
local showMainView,showSettingsView
showMainView=function() St.showingSettings=false
UI.content.Visible=true
UI.settingsPage.Visible=false
UI.titleLabel.Text="music controller"
UI.meterFrame.Visible=true
if UI.helpButton then UI.helpButton.Visible=false end
if UI.helpOverlay and helpOpen then closeHelpOverlay() end end
showSettingsView=function() St.showingSettings=true
UI.content.Visible=false
UI.settingsPage.Visible=true
UI.titleLabel.Text="settings"
UI.meterFrame.Visible=false
switchSettingsTab(St.settingsActiveTab)
updateSettingsCanvas()
if UI.helpButton then UI.helpButton.Visible=true end end
UI.settingsButton.MouseButton1Click:Connect(function() if St.showingSettings then showMainView() else showSettingsView() end end)
do
local HELP_ENTRIES={
	{"PLAYBACK",""},
	{"Play / Pause","Click the  play  button, or press your assigned keybind (default: F7)."},
	{"Previous / Next","Use  <<  and  >>  buttons, or F6 / F8 keybinds."},
	{"Volume & Speed","Drag the sliders, type a value, or scroll the mouse wheel while hovering over them."},
	{"Progress Bar","Click anywhere to seek. Hover to preview the time at that position."},
	{"Crossfade","Enable  Crossfade Tracks  in Settings to fade between songs instead of cutting."},
	{"",""},
	{"MP3 LIBRARY",""},
	{"Adding tracks","Drop MP3 files into  Music Workspace/Musics/. The library auto-updates every 2 seconds."},
	{"New track pulse","A newly added button pulses gold for 5 seconds. Click to stop the pulse early."},
	{"Track order","Use the arrow buttons on each track to reorder. Order is saved automatically."},
	{"Search","Click the magnifying glass icon to filter tracks by name."},
	{"Delete a track","Hover a track then press  Delete  on your keyboard. Confirm in the dialog."},
	{"",""},
	{"CATEGORIES",""},
	{"Create a folder","Click  + new folder  at the top of the MP3 list."},
	{"Add to category","Hover a track and  Shift + Click  to assign it to a category."},
	{"Remove from category","Hover a categorised track and  Shift + Click  to remove it."},
	{"Rename category","Right-click (MouseButton2) on a category header to rename it."},
	{"",""},
	{"QUEUE",""},
	{"Add to queue","Hold  Ctrl + Click  on any MP3 button to add it to the queue."},
	{"Clear queue","Tracks play from the queue in order and it clears automatically when finished."},
	{"",""},
	{"SYNCED LYRICS",""},
	{"Enable lyrics","Toggle  Show Synced Lyrics  in Settings. Lyrics fetch from lrclib.net automatically."},
	{"Cinematic Mode","Enable  Cinematic Mode  (only visible when lyrics are on) for floating lyric text with black bars."},
	{"Translate","Toggle  Translate Lyrics  to auto-translate lyrics via Google Translate."},
	{"",""},
	{"DOWNLOADER",""},
	{"Download from SoundCloud","Paste a SoundCloud URL into the  MP3 Downloader  tab and click Download."},
	{"Album art","Art loads automatically when a valid SoundCloud URL is detected."},
	{"",""},
	{"SC SEARCH",""},
	{"Search SoundCloud","Go to the  SC Search  tab, type a song title and press Search or Enter."},
	{"Navigate results","Use  Prev / Next  to browse. Copy the URL to use in the downloader."},
	{"",""},
	{"KEYBINDS",""},
	{"Assign a keybind","Settings > expand  Keybinds  > click a button > press any key."},
	{"Toggle controller","Assigned under  Toggle Controller  in the Keybinds list (default: N)."},
	{"Clear a keybind","Reassign the key to any other key or reassign to the same to replace."},
	{"",""},
	{"THEME & VISUALS",""},
	{"Change colors","Expand  Theme Colors  in Settings and type a hex code (e.g. #FF8800) for any slot."},
	{"Screen Shake","Enable  Screen Shake (Visualizer)  to shake the camera in sync with the music loudness."},
	{"Adjust intensity","Shake Intensity and FOV Intensity rows appear below the Screen Shake toggle."},
}
local helpClip=Instance.new("Frame")
helpClip.Name="HelpClip"
helpClip.Position=UDim2.new(0,0,0,34)
helpClip.Size=UDim2.new(1,0,1,-34)
helpClip.BackgroundTransparency=1
helpClip.BorderSizePixel=0
helpClip.ZIndex=199
helpClip.ClipsDescendants=true
helpClip.Visible=false
helpClip.Parent=UI.main
UI.helpOverlay=Instance.new("Frame")
UI.helpOverlay.Name="HelpOverlay"
UI.helpOverlay.AnchorPoint=Vector2.new(0,0)
UI.helpOverlay.Size=UDim2.new(1,0,1,0)
UI.helpOverlay.Position=UDim2.new(0,0,1,0)
UI.helpOverlay.BackgroundColor3=C.BG
UI.helpOverlay.BorderSizePixel=0
UI.helpOverlay.ZIndex=200
UI.helpOverlay.Visible=true
UI.helpOverlay.ClipsDescendants=false
UI.helpOverlay.Parent=helpClip
applyCornerRadius(12,UI.helpOverlay)
do local hClose=Instance.new("TextButton")
hClose.AnchorPoint=Vector2.new(1,0)
hClose.Position=UDim2.new(1,-8,0,8)
hClose.Size=UDim2.new(0,20,0,20)
hClose.BackgroundColor3=C.ELEVATED
hClose.AutoButtonColor=false
hClose.Font=Enum.Font.GothamBold
hClose.Text="x"
hClose.TextColor3=C.TEXT2
hClose.TextSize=11
hClose.BorderSizePixel=0
hClose.ZIndex=210
hClose.Parent=UI.helpOverlay
applyCornerRadius(10,hClose)
UI.helpCloseBtn=hClose end
do local hTitle=Instance.new("TextLabel")
hTitle.Position=UDim2.new(0,12,0,8)
hTitle.Size=UDim2.new(1,-44,0,20)
hTitle.BackgroundTransparency=1
hTitle.Font=Enum.Font.GothamBold
hTitle.Text="User Guide"
hTitle.TextColor3=C.TEXT
hTitle.TextXAlignment=Enum.TextXAlignment.Left
hTitle.TextSize=14
hTitle.ZIndex=205
hTitle.Parent=UI.helpOverlay end
local hScroll
do local hLL,hLP
hScroll=Instance.new("ScrollingFrame")
hScroll.Position=UDim2.new(0,0,0,34)
hScroll.Size=UDim2.new(1,0,1,-34)
hScroll.BackgroundTransparency=1
hScroll.BorderSizePixel=0
hScroll.ScrollBarThickness=3
hScroll.ScrollBarImageColor3=C.ACCENT
hScroll.CanvasSize=UDim2.new(0,0,0,0)
hScroll.ZIndex=201
hScroll.Parent=UI.helpOverlay
hLL=Instance.new("UIListLayout")
hLL.Padding=UDim.new(0,2)
hLL.SortOrder=Enum.SortOrder.LayoutOrder
hLL.Parent=hScroll
hLP=Instance.new("UIPadding")
hLP.PaddingLeft=UDim.new(0,10)
hLP.PaddingRight=UDim.new(0,10)
hLP.PaddingTop=UDim.new(0,4)
hLP.Parent=hScroll
hLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() hScroll.CanvasSize=UDim2.new(0,0,0,hLL.AbsoluteContentSize.Y+12) end) end
for i,e in ipairs(HELP_ENTRIES) do
	local head=e[1]
local body=e[2]
	local lo=i*4
	if head=="" then
		local sp=Instance.new("Frame")
sp.Size=UDim2.new(1,0,0,5)
sp.BackgroundTransparency=1
sp.LayoutOrder=lo
sp.Parent=hScroll
	elseif body=="" then
		local sep=Instance.new("Frame")
sep.Size=UDim2.new(1,0,0,1)
sep.BackgroundColor3=C.BORDER
sep.BorderSizePixel=0
sep.ZIndex=202
sep.LayoutOrder=lo
sep.Parent=hScroll
		local hl=Instance.new("TextLabel")
hl.Size=UDim2.new(1,0,0,16)
hl.BackgroundTransparency=1
hl.Font=Enum.Font.GothamBold
hl.Text=head
hl.TextColor3=C.ACCENT
hl.TextXAlignment=Enum.TextXAlignment.Left
hl.TextSize=10
hl.ZIndex=202
hl.LayoutOrder=lo+1
hl.Parent=hScroll
	else
		local row=Instance.new("Frame")
row.Size=UDim2.new(1,0,0,0)
row.AutomaticSize=Enum.AutomaticSize.Y
row.BackgroundColor3=C.ELEVATED
row.BorderSizePixel=0
row.ZIndex=201
row.LayoutOrder=lo
row.Parent=hScroll
applyCornerRadius(6,row)
		local rp=Instance.new("UIPadding")
rp.PaddingLeft=UDim.new(0,8)
rp.PaddingRight=UDim.new(0,8)
rp.PaddingTop=UDim.new(0,4)
rp.PaddingBottom=UDim.new(0,4)
rp.Parent=row
		local rl=Instance.new("UIListLayout")
rl.SortOrder=Enum.SortOrder.LayoutOrder
rl.Padding=UDim.new(0,1)
rl.Parent=row
		local kl=Instance.new("TextLabel")
kl.Size=UDim2.new(1,0,0,14)
kl.BackgroundTransparency=1
kl.Font=Enum.Font.GothamMedium
kl.Text=head
kl.TextColor3=C.TEXT
kl.TextXAlignment=Enum.TextXAlignment.Left
kl.TextSize=11
kl.ZIndex=203
kl.LayoutOrder=1
kl.Parent=row
		local bl=Instance.new("TextLabel")
bl.Size=UDim2.new(1,0,0,0)
bl.AutomaticSize=Enum.AutomaticSize.Y
bl.BackgroundTransparency=1
bl.Font=Enum.Font.Gotham
bl.Text=body
bl.TextColor3=C.TEXT2
bl.TextXAlignment=Enum.TextXAlignment.Left
bl.TextSize=10
bl.TextWrapped=true
bl.ZIndex=203
bl.LayoutOrder=2
bl.Parent=row
	end
end
UI.helpOverlay.Position=UDim2.new(0,0,1,0)
UI.helpOverlay.BackgroundTransparency=0
local helpOpen=false
local HELP_OPEN=UDim2.new(0,0,0,0)
local HELP_CLOSE=UDim2.new(0,0,1,0)
local helpTween=nil
local openHelpOverlay,closeHelpOverlay
openHelpOverlay=function()
	if helpOpen then return end
helpOpen=true
	if helpTween then helpTween:Cancel() end
	helpClip.Visible=true
UI.helpOverlay.Visible=true
	helpTween=Svc.TweenService:Create(UI.helpOverlay,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=HELP_OPEN})
	helpTween:Play()
	UI.helpButton.ImageColor3=C.ACCENT
end
closeHelpOverlay=function()
	if not helpOpen then return end
helpOpen=false
	if helpTween then helpTween:Cancel() end
	helpTween=Svc.TweenService:Create(UI.helpOverlay,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=HELP_CLOSE})
	helpTween.Completed:Connect(function(s) if s==Enum.TweenStatus.Completed then helpClip.Visible=false end end)
	helpTween:Play()
	UI.helpButton.ImageColor3=C.TEXT2
end
if UI.helpCloseBtn then UI.helpCloseBtn.MouseButton1Click:Connect(function() closeHelpOverlay() end) end
UI.helpButton.MouseButton1Click:Connect(function() if helpOpen then closeHelpOverlay() else openHelpOverlay() end end)
end

-- Re-apply UI scale and card size whenever the viewport changes (e.g. orientation flip)
Svc.Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	local newScale = computeUiScale()
	if math.abs(newScale - currentUiScale) > 0.01 then
		currentUiScale = newScale
		UI.uiScale.Scale = newScale
		-- Re-centre if the card is now out of bounds
		local vp  = getViewport()
		local pos = UI.main.Position
		local ap  = UI.main.AbsolutePosition
		local as  = UI.main.AbsoluteSize
		if ap.X < 0 or ap.Y < 0 or ap.X + as.X > vp.X or ap.Y + as.Y > vp.Y then
			UI.main.Position = UDim2.new(0.5, 0, 0.5, 0)
		end
	end
end)

UI.dragArea.MouseButton1Down:Connect(function()
	St.draggingWindow=true
	local mp=Svc.UserInput:GetMouseLocation()
	local vp=Svc.Workspace.CurrentCamera.ViewportSize
	local pos=UI.main.Position
	local gx=pos.X.Scale*vp.X+pos.X.Offset
	local gy=pos.Y.Scale*vp.Y+pos.Y.Offset
	Dat.dragStart=Vector2.new(mp.X-gx, mp.Y-gy)
end)
Svc.UserInput.InputChanged:Connect(function(inp)
	if St.draggingWindow and inp.UserInputType==Enum.UserInputType.MouseMovement then
		local mp=Svc.UserInput:GetMouseLocation()
		local vp=Svc.Workspace.CurrentCamera.ViewportSize
		local as=UI.main.AbsoluteSize
		local leftPad=St.listPanelOpen and (Cfg.LIST_WIDTH+Cfg.PANEL_GAP) or 0
		local rightPad=St.queuePanelOpen and (Cfg.LIST_WIDTH+Cfg.PANEL_GAP) or 0
		local nx=math.clamp(mp.X-Dat.dragStart.X, leftPad+as.X/2, vp.X-as.X/2-rightPad)
		local ny=math.clamp(mp.Y-Dat.dragStart.Y, as.Y/2, vp.Y-as.Y/2)
		UI.main.Position=UDim2.fromOffset(nx,ny)
	end
end)
Svc.UserInput.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then St.draggingWindow=false end end)

-- Touch-tap anywhere on the title bar toggles the GUI on mobile
if isMobileDevice() then
	UI.dragArea.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.Touch then
			-- Single tap: treat like a click
			St.draggingWindow = false
		end
	end)
end

local showController,hideController
showController=function()
	if St.animating or St.guiOpen then return end
	St.animating=true
St.guiOpen=true
	local vp=Svc.Workspace.CurrentCamera.ViewportSize
	local ap=UI.main.AbsolutePosition
local as=UI.main.AbsoluteSize
	if ap.X<0 or ap.Y<0 or ap.X+as.X>vp.X or ap.Y+as.Y>vp.Y then
		UI.main.Position=UDim2.new(0.5,0,0.5,0)
	end
	UI.main.Visible=true
UI.uiScale.Scale=0
	local tw=Svc.TweenService:Create(UI.uiScale,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
	tw.Completed:Connect(function() St.animating=false end)
tw:Play()
end
hideController=function()
	if St.animating or not St.guiOpen then return end
	St.animating=true
St.guiOpen=false
	for _,slot in ipairs(activeToasts or {}) do slot.dismiss=true end
	local tw=Svc.TweenService:Create(UI.uiScale,TweenInfo.new(0.16,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Scale=0})
	tw.Completed:Connect(function()
		UI.main.Visible=false
		if St.listPanelOpen then UI.listPanel.Visible=false;UI.listPanel.Position=UDim2.new(0,0,0,0);UI.toggleListBtn.Position=UDim2.new(0,-6,0.5,0);UI.toggleListBtn.Text=">";St.listPanelOpen=false end
		if St.queuePanelOpen then UI.queuePanel.Visible=false;UI.queuePanel.Position=UDim2.new(1,-Cfg.LIST_WIDTH,0,0);UI.toggleQueueBtn.Position=UDim2.new(1,6,0.5,0);UI.toggleQueueBtn.Text="<";St.queuePanelOpen=false end
		St.animating=false
	end)
tw:Play()
end
Svc.UserInput.InputBegan:Connect(function(inp,gp)
	if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
	if St.capturingKeybind then St.capturingKeybind=false;local nk=inp.KeyCode;if nk~=Enum.KeyCode.Unknown then curKC=nk;kbVal.Value=nk.Name;UI.keybindButton.Text=nk.Name;UI.keybindButton.BackgroundColor3=C.SURFACE else UI.keybindButton.Text=curKC.Name;UI.keybindButton.BackgroundColor3=C.SURFACE end;return end
	local kc=inp.KeyCode
	if St.kbPrev and kc==St.kbPrev then
		if #Dat.trackList>0 then
			local ni=St.currentTrackIndex>1 and St.currentTrackIndex-1 or #Dat.trackList
			local inf=Dat.trackList[ni];setCurrentTrack(ni,true)
			if inf and showTrackNotification then showTrackNotification("now playing "..inf.DisplayName,false) end
		end;return
	end
	if St.kbPlay and kc==St.kbPlay then
		if sound then
			if St.isPaused then
				if Dat.activeFadeOutTween then Dat.activeFadeOutTween:Cancel();Dat.activeFadeOutTween=nil end
				if St.crossfadeEnabled then Svc.TweenService:Create(sound,TweenInfo.new(Cfg.CROSSFADE_TIME,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=St.currentVolume}):Play() else sound.Volume=St.currentVolume end
				local ok=pcall(function() sound:Resume() end);if not ok or not sound.IsPlaying then sound:Play() end;St.isPaused=false
				if showTrackNotification then showTrackNotification(kc.Name.." — resumed",false) end
			else
				if St.crossfadeEnabled then
					local cs=sound;local fo=Svc.TweenService:Create(sound,TweenInfo.new(Cfg.CROSSFADE_TIME,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=0});Dat.activeFadeOutTween=fo
					fo.Completed:Connect(function() if Dat.activeFadeOutTween==fo then Dat.activeFadeOutTween=nil;if St.isPaused and cs==sound then pcall(function() cs:Pause() end);if cs.IsPlaying then cs:Stop() end end end end);fo:Play()
				else pcall(function() sound:Pause() end) end
				St.isPaused=true
				if showTrackNotification then showTrackNotification(kc.Name.." — paused",false) end
			end
			refreshPlayButton()
		end;return
	end
	if St.kbNext and kc==St.kbNext then
		if #Dat.trackList>0 then
			local ni=pickNextTrackIndex();local inf=Dat.trackList[ni];setCurrentTrack(ni,true)
			if inf and showTrackNotification then showTrackNotification("now playing "..inf.DisplayName,false) end
		end;return
	end
	if St.kbRepeat and kc==St.kbRepeat then
		St.repeatEnabled=not St.repeatEnabled;if UI.repeatToggle then UI.repeatToggle.RefreshTheme() end;saveUserSettings()
		if showTrackNotification then showTrackNotification("repeat — "..(St.repeatEnabled and "on" or "off"),false) end;return
	end
	if St.kbShuffle and kc==St.kbShuffle then
		St.shuffleEnabled=not St.shuffleEnabled;if UI.shuffleToggle then UI.shuffleToggle.RefreshTheme() end;saveUserSettings()
		if showTrackNotification then showTrackNotification("shuffle — "..(St.shuffleEnabled and "on" or "off"),false) end;return
	end
	if St.kbLyrics and kc==St.kbLyrics then
		St.lyricsEnabled=not St.lyricsEnabled;refreshLyricsToggle();saveUserSettings()
		if St.lyricsEnabled then
			local inf=Dat.trackList[St.currentTrackIndex];if inf then Dat.lyricsFetchGen=Dat.lyricsFetchGen+1;fetchLyricsForTrack(inf.DisplayName,Dat.lyricsFetchGen) end
			if St.cinematicMode then
				if lyricsOverlay and lyricsOverlay.gui then lyricsOverlay.gui.Enabled=false end
				startCinematicOverlay()
			elseif lyricsOverlay and lyricsOverlay.gui and lyricsOverlay.frame then
				if _lyricsTween then _lyricsTween:Cancel();_lyricsTween=nil end
				lyricsOverlay.gui.Enabled=true
				lyricsOverlay.frame.Position=UDim2.new(0.5,0,1.3,0)
				_lyricsTween=Svc.TweenService:Create(lyricsOverlay.frame,TweenInfo.new(0.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,0,0.87,0)})
				_lyricsTween:Play()
			end
		else
			clearCurrentLyrics()
			if lyricsOverlay and lyricsOverlay.frame then
				if _lyricsTween then _lyricsTween:Cancel();_lyricsTween=nil end
				_lyricsTween=Svc.TweenService:Create(lyricsOverlay.frame,TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(0.5,0,1.3,0)})
				_lyricsTween.Completed:Connect(function(s)
					if s==Enum.TweenStatus.Completed then if lyricsOverlay and lyricsOverlay.gui then lyricsOverlay.gui.Enabled=false end end
				end)
				_lyricsTween:Play()
			end
			if St.cinematicMode then St.cinematicMode=false;stopCinematicOverlay();refreshCinematicToggle();saveUserSettings() end
		end
		if showTrackNotification then showTrackNotification("synced lyrics — "..(St.lyricsEnabled and "on" or "off"),false) end;return
	end
	if St.kbTranslate and kc==St.kbTranslate then
		St.translateEnabled=not St.translateEnabled;refreshTranslateToggle();saveUserSettings()
		if _G.__MCRefTranslatePill then _G.__MCRefTranslatePill() end;if showTrackNotification then showTrackNotification("translate lyrics — "..(St.translateEnabled and "on" or "off"),false) end;return
	end
	if St.kbMute and kc==St.kbMute then
		St.muteGameSounds=not St.muteGameSounds;if _G.__MCRefMute then _G.__MCRefMute() end;saveUserSettings()
		if showTrackNotification then showTrackNotification("mute game sounds — "..(St.muteGameSounds and "on" or "off"),false) end;return
	end
	if St.kbCinematic and kc==St.kbCinematic then
		if St.lyricsEnabled and not _cinLocked then
			_cinLocked=true;St.cinematicMode=not St.cinematicMode;refreshCinematicToggle();saveUserSettings()
			if St.cinematicMode then startCinematicOverlay();task.delay(2.2,function() _cinLocked=false end)
			else stopCinematicOverlay();task.delay(2.8,function() _cinLocked=false end) end
			if showTrackNotification then showTrackNotification("cinematic mode — "..(St.cinematicMode and "on" or "off"),false) end
		end;return
	end
	if gp then return end
	if kc==curKC then if St.guiOpen then hideController() else showController() end;return end
end)
local cam=Svc.Workspace.CurrentCamera
Svc.Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() cam=Svc.Workspace.CurrentCamera end)
do
	local fovLockConn=nil
	local function releaseFovLock()
		if fovLockConn then fovLockConn:Disconnect()
fovLockConn=nil end
		local c=Svc.Workspace.CurrentCamera
if c and Dat.fovBaseline then pcall(function() c.FieldOfView=Dat.fovBaseline end) end
		Dat.fovLockedVal=nil
Dat.fovBaseline=nil
Dat.fovSmooth=0
	end
	local function applyFovLock(c,value)
		value=math.clamp(value,1,120)
if Dat.fovLockedVal==value then return end
Dat.fovLockedVal=value
		if fovLockConn then fovLockConn:Disconnect()
fovLockConn=nil end
		pcall(function() c.FieldOfView=value end)
		fovLockConn=c:GetPropertyChangedSignal("FieldOfView"):Connect(function() if Dat.fovLockedVal and c.FieldOfView~=Dat.fovLockedVal then pcall(function() c.FieldOfView=Dat.fovLockedVal end) end end)
	end
	task.spawn(function()
		while true do
			Svc.RunService.Heartbeat:Wait()
			pcall(function()
				local c=Svc.Workspace.CurrentCamera;if not c then return end
				local fi=math.clamp(St.fovIntensity,0,5);local s=sound;local loud=0
				if s and s.IsPlaying then loud=math.clamp((s.PlaybackLoudness or 0)/600,0,1);if St.currentVolume>0 then loud=loud*math.clamp(s.Volume/St.currentVolume,0,1) end end
				Dat.fovSmooth=Dat.fovSmooth+(loud-Dat.fovSmooth)*0.25
				if fi>0 and St.screenShakeEnabled and Dat.fovSmooth>0.005 then
					if not Dat.fovBaseline then Dat.fovBaseline=c.FieldOfView end;applyFovLock(c,Dat.fovBaseline+Dat.fovSmooth*fi*10)
				else Dat.fovSmooth=0;if Dat.fovBaseline then releaseFovLock() end end
			end)
		end
	end)
end
Svc.RunService:BindToRenderStep("MCShake",Enum.RenderPriority.Camera.Value+1,function(dt)
	local s=sound;local pl=s and s.IsPlaying;local c=Svc.Workspace.CurrentCamera;if not c then return end
	local l01=0
	if pl then local r=math.clamp((s.PlaybackLoudness or 0)/600,0,1);local vr=(St.currentVolume>0) and math.clamp(s.Volume/St.currentVolume,0,1) or 0;l01=r*vr end
	local dtC=math.min(dt,0.1);local ssl=Dat.smoothShakeLoud or 0;Dat.smoothShakeLoud=ssl+(l01-ssl)*math.min(dtC*10,1)
	if St.screenShakeEnabled and pl and Dat.smoothShakeLoud>0.015 then
		local si=math.clamp(St.shakeIntensity,0,5);local t=tick();local mag=Dat.smoothShakeLoud*si
		local rot=CFrame.Angles(math.rad(math.sin(t*7.0)*mag*0.9),math.rad(math.sin(t*9.3+1.2)*mag*0.9),math.rad(math.sin(t*6.1+2.4)*mag*0.4))
		local offset=Vector3.new(math.sin(t*6.2)*mag*0.12,math.sin(t*8.1+1.57)*mag*0.12,math.sin(t*5.3+3.0)*mag*0.04)
		c.CFrame=c.CFrame*rot+offset
	else Dat.smoothShakeLoud=0;if Dat.fovBaseline then releaseFovLock() end;Dat.fovSmooth=0 end
end)
Svc.RunService.RenderStepped:Connect(function()
	local s=sound;local pl=s and s.IsPlaying;local l01=0
	if pl then local r=math.clamp((s.PlaybackLoudness or 0)/600,0,1);local vr=(St.currentVolume>0) and math.clamp(s.Volume/St.currentVolume,0,1) or 0;l01=r*vr end
	if s and s.TimeLength and s.TimeLength>0 then
		if not St.draggingProgress then UI.progressFill.Size=UDim2.new(math.clamp(s.TimePosition/s.TimeLength,0,1),0,1,0) end
		if UI.timeDisplay.TextTransparency~=0 then UI.timeDisplay.TextTransparency=0 end
		local txt=formatTime(s.TimePosition or 0).." / "..formatTime(s.TimeLength or 0)
		if txt~=UI.timeDisplay.Text then UI.timeDisplay.Text=txt;St.lastDisplayedTime=txt end
		if St.crossfadeEnabled and pl and not St.isPaused and not St.repeatEnabled and not St.crossfadeTriggered and s.TimeLength>(Cfg.CROSSFADE_TRIGGER+0.5) then
			local rem=(s.TimeLength or 0)-(s.TimePosition or 0)
			if rem<=Cfg.CROSSFADE_TRIGGER and rem>0 then
				St.crossfadeTriggered=true;local ni;if #Dat.queueList>0 then ni=Dat.queueList[1].TrackIndex else ni=pickNextTrackIndex() end
				local ns2=Dat.createdSounds[ni]
				if ns2 and ns2~=s then
					Dat.crossfadingSounds[s]=true;Dat.crossfadingSounds[ns2]=true
					local fo=Svc.TweenService:Create(s,TweenInfo.new(Cfg.CROSSFADE_TIME,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=0});fo.Completed:Connect(function() Dat.crossfadingSounds[s]=nil end);fo:Play()
					ns2.PlaybackSpeed=(St.currentSpeed<=0) and 0.01 or St.currentSpeed;ns2.Looped=false;ns2.Volume=0;ns2:Play()
					local fi2=Svc.TweenService:Create(ns2,TweenInfo.new(Cfg.CROSSFADE_TIME,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=St.currentVolume});fi2.Completed:Connect(function() Dat.crossfadingSounds[ns2]=nil end);fi2:Play()
					if Dat.soundEndedConnection then Dat.soundEndedConnection:Disconnect();Dat.soundEndedConnection=nil end
					St.currentTrackIndex=ni;sound=ns2;St.crossfadeTriggered=false;St.isPaused=false
					if #Dat.queueList>0 then table.remove(Dat.queueList,1);rebuildQueueUI() end
					local nt=Dat.trackList[ni];if nt then updateTrackDisplay(nt.DisplayName,nt.FullName or nt.DisplayName);if St.lyricsEnabled then Dat.lyricsFetchGen=Dat.lyricsFetchGen+1;fetchLyricsForTrack(nt.DisplayName,Dat.lyricsFetchGen) end end
					if ns2.TimeLength and ns2.TimeLength>0 then animateTimeDisplay("0:00 / "..formatTime(ns2.TimeLength)) end;moveAudioEffects(ns2)
					do
						local oldIdx=Dat.prevTrackIndex;Dat.prevTrackIndex=ni
						local fadeTI=TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
						local oldBtn=oldIdx and UI.listScroll:FindFirstChild("Track_"..oldIdx)
						if oldBtn and oldBtn:IsA("TextButton") then
							Svc.TweenService:Create(oldBtn,fadeTI,{BackgroundColor3=C.SURFACE,TextColor3=C.TEXT2}):Play()
							local oldStr=oldBtn:FindFirstChildOfClass("UIStroke");if oldStr then Svc.TweenService:Create(oldStr,fadeTI,{Transparency=1}):Play() end
							task.delay(0.2,function() task.defer(rebuildTrackListUI) end)
						else task.defer(rebuildTrackListUI) end
					end
					Dat.soundEndedConnection=ns2.Ended:Connect(function()
						if not sound then return end;if St.crossfadeTriggered then St.crossfadeTriggered=false;return end
						if #Dat.queueList>0 then local nq=table.remove(Dat.queueList,1);rebuildQueueUI();setCurrentTrack(nq.TrackIndex,true)
						elseif St.repeatEnabled then sound.TimePosition=0;sound:Play()
						else setCurrentTrack(pickNextTrackIndex(),true) end
					end)
					local myG=Dat.crossfadeCleanupGen;task.spawn(function() local to=Cfg.CROSSFADE_TRIGGER+0.5;local el=0;while el<to do task.wait(0.05);el=el+0.05;if not s.IsPlaying then break end;if Dat.crossfadeCleanupGen~=myG then return end end;if Dat.crossfadeCleanupGen~=myG then return end;pcall(function() s:Stop() end);s.Volume=St.currentVolume end)
				else St.crossfadeTriggered=false end
			end
		end
	else UI.progressFill.Size=UDim2.new(0,0,1,0);if UI.timeDisplay.TextTransparency~=0 then UI.timeDisplay.TextTransparency=0 end;if UI.timeDisplay.Text~="0:00 / 0:00" then UI.timeDisplay.Text="0:00 / 0:00";St.lastDisplayedTime="0:00 / 0:00" end end
	if UI.meterFrame.Visible and #Dat.meterBars>0 then
		if not pl or l01<0.02 then for i,b in ipairs(Dat.meterBars) do b.Size=UDim2.new(0,3,0.12+(i-1)*0.04,0);b.BackgroundTransparency=0.82 end
		else local t=tick();for i,b in ipairs(Dat.meterBars) do local w=(math.sin(t*10+(i-1)*0.8)+1)/2;local h=math.clamp(0.2+l01*(0.5+0.2*(i-1))*(0.4+0.6*w),0.2,1);b.Size=UDim2.new(0,3,h,0);b.BackgroundTransparency=0.45-l01*0.25 end end
	end
	if St.lyricsEnabled and lyricsOverlay and lyricsOverlay.gui and lyricsOverlay.gui.Enabled then
		if s and s.TimeLength and s.TimeLength>0 and pl then
			local pos=s.TimePosition;local lyr=Dat.currentLyrics
			if #lyr>0 then
				local ci2=0;for li=1,#lyr do if lyr[li].time<=pos then ci2=li else break end end
				local lastLineTime=lyr[#lyr].time;local afterLast=pos>lastLineTime+1.5
				if afterLast and not Dat.eolFired then
					Dat.eolFired=true;lyricsOverlay.prev.Active=false;lyricsOverlay.current.Active=false;lyricsOverlay.next.Active=false
					local trackInf=Dat.trackList[St.currentTrackIndex];local tname=Dat.detectedLyricsTitle or (trackInf and trackInf.DisplayName) or (sound and sound.Name) or ""
					Svc.TweenService:Create(lyricsOverlay.prev,TweenInfo.new(0.4,Enum.EasingStyle.Quad),{TextTransparency=1}):Play();Svc.TweenService:Create(lyricsOverlay.next,TweenInfo.new(0.4,Enum.EasingStyle.Quad),{TextTransparency=1}):Play();Svc.TweenService:Create(lyricsOverlay.current,TweenInfo.new(0.4,Enum.EasingStyle.Quad),{TextTransparency=1}):Play()
					Svc.TweenService:Create(lyricsOverlay.underline,TweenInfo.new(0.35,Enum.EasingStyle.Quad),{Size=UDim2.new(0,0,0,2)}):Play()
					task.delay(0.38,function()
						Svc.TweenService:Create(lyricsOverlay.underline,TweenInfo.new(0.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,0,0,18)}):Play()
						task.delay(0.15,function() local pillW=lyricsOverlay.pill.AbsoluteSize.X;local barW=math.max(pillW*0.93,pillW-12);Svc.TweenService:Create(lyricsOverlay.underline,TweenInfo.new(0.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,barW,0,2)}):Play() end)
						task.delay(0.3,function() lyricsOverlay.eolTitle.Text=tname;lyricsOverlay.eolTitle.Position=UDim2.new(0.5,0,0.5,10);lyricsOverlay.eolTitle.TextTransparency=1;eolTitleTween=Svc.TweenService:Create(lyricsOverlay.eolTitle,TweenInfo.new(0.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{TextTransparency=0,Position=UDim2.new(0.5,0,0.5,0)});eolTitleTween:Play() end)
					end)
				elseif not afterLast and Dat.eolFired then
					Dat.eolFired=false;lyricsOverlay.prev.Active=true;lyricsOverlay.current.Active=true;lyricsOverlay.next.Active=true
					lyricsOverlay.eolTitle.Text="";lyricsOverlay.eolTitle.TextTransparency=1;Svc.TweenService:Create(lyricsOverlay.underline,TweenInfo.new(0.2),{Position=UDim2.new(0.5,0,0,76),Size=UDim2.new(0,0,0,2)}):Play()
				end
				if not afterLast then
					if ci2~=Dat.lastLyricIndex then
						Dat.lastLyricIndex=ci2;local pi=ci2>1 and(ci2-1) or 0;local ni=ci2<#lyr and(ci2+1) or 0
						local ptxt=pi>0 and lyr[pi].text or "";local ntxt=ni>0 and lyr[ni].text or ""
						if St.translateEnabled then
							local tp=Dat.translateCache[ptxt] or ptxt
							local tn=Dat.translateCache[ntxt] or ntxt
							animateLyricsTransition(tp,tn,pi,ci2,ni)
						else
							animateLyricsTransition(ptxt,ntxt,pi,ci2,ni)
						end
						lyricsOverlay.current.Position=UDim2.new(0.5,0,0,52);Svc.TweenService:Create(lyricsOverlay.current,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,0,0,34)}):Play()
					end
					if ci2>0 then
						local entry=lyr[ci2];local lineEnd=(ci2<#lyr) and lyr[ci2+1].time or s.TimeLength
						local function toRgb(c) return string.format("rgb(%d,%d,%d)",math.floor(c.R*255+0.5),math.floor(c.G*255+0.5),math.floor(c.B*255+0.5)) end
						local function lerpRgb(a,b,t) t=math.clamp(t,0,1);return toRgb(Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)) end
						local parts={}
						if entry.words and not St.translateEnabled then
							local XF=0.08
							for i,w in ipairs(entry.words) do
								local wS=w.time;local wE=(i<#entry.words) and entry.words[i+1].time or lineEnd;local col
								if pos<wS-XF then col=toRgb(C.TEXT3) elseif pos<wS then col=lerpRgb(C.TEXT3,C.ACCENT,(pos-(wS-XF))/XF) elseif pos<wE-XF then col=toRgb(C.ACCENT) elseif pos<wE then col=lerpRgb(C.ACCENT,C.TEXT2,(pos-(wE-XF))/XF) else col=toRgb(C.TEXT2) end
								table.insert(parts,'<font color="'..col..'">'..w.text:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")..'</font>')
							end
						else
							local displayText=St.translateEnabled and (Dat.translateCache[entry.text] or entry.text) or entry.text
							table.insert(parts,'<font color="'..toRgb(C.ACCENT)..'">'..displayText:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")..'</font>')
						end
						lyricsOverlay.current.RichText=true;lyricsOverlay.current.TextTransparency=0;lyricsOverlay.current.Text=table.concat(parts," ")
						if lyricsOverlay.refreshUnderline then lyricsOverlay.refreshUnderline() end
					end
				end
			end
		end
	end
end)
UI.searchBox:GetPropertyChangedSignal("Text"):Connect(function() St.searchQuery=UI.searchBox.Text:lower():match("^%s*(.-)%s*$") or "";rebuildTrackListUI() end)
-- Named timing constants for the cinematic intro sequence
local CINEMATIC_CINEMATIC_VIDEO_START_OFFSET  = 4.3   -- seconds before sequence starts
local CINEMATIC_CINEMATIC_VIDEO_EXIT_TIME     = 24.3  -- seconds when sequence ends
local CINEMATIC_CINEMATIC_SEQUENCE_DURATION   = CINEMATIC_CINEMATIC_VIDEO_EXIT_TIME - CINEMATIC_CINEMATIC_VIDEO_START_OFFSET
local CINEMATIC_CINEMATIC_INITIAL_BAR_HEIGHT  = 0.12  -- bar height before narrowing
local CINEMATIC_CINEMATIC_FINAL_BAR_HEIGHT    = 0.22  -- bar height after narrowing

-- Playback position thresholds for the teapot Easter-egg sequence
local TEAPOT_BORDERS_IN_POS  = 45  -- seconds: when to animate borders in
local TEAPOT_LYRICS_SLIDE_POS = 43  -- seconds: when to slide lyrics
local TEAPOT_SEQUENCE_START  = 51  -- seconds: when to start lyric sequence
local TEAPOT_RESET_THRESHOLD = 5   -- seconds: position below which we reset

do
	local CINEMATIC_VIDEO_START_OFFSET=4.3
local CINEMATIC_VIDEO_EXIT_TIME=24.3
local CINEMATIC_SEQUENCE_DURATION=CINEMATIC_VIDEO_EXIT_TIME-CINEMATIC_VIDEO_START_OFFSET
	local CINEMATIC_INITIAL_BAR_HEIGHT=0.12
local CINEMATIC_FINAL_BAR_HEIGHT=0.22
local TEXT_FONT=Enum.Font.Merriweather
	local COLOR_MAIN=Color3.fromHex("f8ffff")
local OUTLINE_MAIN=Color3.fromHex("060a3d")
	local COLOR_ALT=Color3.fromHex("b4f9ff")
local OUTLINE_ALT=Color3.fromHex("000b46")
	local COLOR_RED=Color3.fromHex("fa282d")
local OUTLINE_RED=Color3.fromHex("08040e")
	local TP_LYRICS={
		{text="Shimmering",inT=4.3,outT=5.5,x=107,y=200,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="night",inT=4.7,outT=5.9,x=372,y=303,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="skies",inT=5.1,outT=6.2,x=454,y=405,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="casts",inT=5.5,outT=6.5,x=1748,y=208,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="its",inT=5.7,outT=6.8,x=1715,y=282,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="light",inT=6.0,outT=7.0,x=1768,y=353,s=70,c=COLOR_ALT,oc=OUTLINE_ALT},
		{text="hopelessly",inT=6.3,outT=7.4,x=1705,y=431,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="trying",inT=6.6,outT=8.4,x=849,y=338,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="to",inT=7.0,outT=8.4,x=1165,y=348,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="survive",inT=7.4,outT=8.4,x=1305,y=342,s=100,c=COLOR_RED,oc=OUTLINE_RED},
		{text="Eternally",inT=8.5,outT=10.1,x=588,y=241,s=70,c=COLOR_ALT,oc=OUTLINE_ALT,segments={{8.5,1},{8.7,4},{9.0,7},{9.1,9}}},
		{text="trapped",inT=9.3,outT=10.3,x=445,y=343,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="inside",inT=9.6,outT=10.6,x=612,y=446,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="What",inT=9.8,outT=10.9,x=1574,y=197,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="we",inT=10.0,outT=11.1,x=1784,y=242,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="call",inT=10.4,outT=11.4,x=1665,y=340,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="our",inT=10.5,outT=11.6,x=1625,y=433,s=100,c=COLOR_ALT,oc=OUTLINE_ALT},
		{text="light",inT=10.8,outT=11.8,x=1807,y=434,s=100,c=COLOR_ALT,oc=OUTLINE_ALT},
		{text="Again",inT=11.3,outT=12.4,x=449,y=237,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="and",inT=11.7,outT=12.8,x=655,y=331,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="Again",inT=11.9,outT=13.0,x=513,y=462,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="you'll",inT=12.5,outT=13.5,x=1716,y=365,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="try",inT=12.9,outT=13.9,x=1984,y=363,s=100,c=COLOR_RED,oc=OUTLINE_RED},
		{text="(ooooh)",inT=13.4,outT=14.5,x=1269,y=672,s=35,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="Running",inT=14.3,outT=15.4,x=330,y=224,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="ain't",inT=14.6,outT=15.7,x=295,y=326,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="an",inT=14.9,outT=16.0,x=337,y=409,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="option",inT=15.3,outT=16.3,x=448,y=409,s=70,c=COLOR_ALT,oc=OUTLINE_ALT},
		{text="and",inT=15.8,outT=16.6,x=1182,y=388,s=90,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="you",inT=16.2,outT=17.2,x=1444,y=307,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="know",inT=16.3,outT=17.4,x=1584,y=307,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="your",inT=16.5,outT=17.5,x=1424,y=402,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="options",inT=16.7,outT=17.8,x=1588,y=402,s=70,c=COLOR_ALT,oc=OUTLINE_ALT},
		{text="are",inT=16.9,outT=18.0,x=1489,y=506,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="running",inT=17.2,outT=18.5,x=1622,y=506,s=70,c=COLOR_MAIN,oc=OUTLINE_MAIN,segments={{17.2,3},{17.5,7}}},
		{text="DRY",inT=17.8,outT=18.7,x=1177,y=353,s=100,c=COLOR_RED,oc=OUTLINE_RED},
		{text="The",inT=18.5,outT=19.5,x=372,y=246,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="weather",inT=18.6,outT=19.7,x=332,y=346,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="forecast's",inT=18.8,outT=19.9,x=381,y=458,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="calling",inT=19.3,outT=20.5,x=1790,y=273,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="for",inT=19.6,outT=20.6,x=1841,y=387,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="an",inT=19.8,outT=20.8,x=1966,y=464,s=100,c=COLOR_MAIN,oc=OUTLINE_MAIN},
		{text="EVERLASTING",inT=20.3,outT=22.1,x=757,y=359,s=100,c=COLOR_ALT,oc=OUTLINE_ALT,segments={{20.3,1},{20.5,4},{20.7,8},{21.0,11}}},
		{text="NIGHT",inT=21.3,outT=22.3,x=1413,y=359,s=100,c=Color3.fromHex("030278"),oc=Color3.fromHex("FFFFFF")},
	}
	local tpS={lyricsSlid=false,bordersStarted=false,lyricsStarted=false,trackIdx=nil,gui=nil,topBar=nil,bottomBar=nil,narrowTop=nil,narrowBot=nil}
	local function tpReset()
		tpS.lyricsSlid=false
tpS.bordersStarted=false
tpS.lyricsStarted=false
tpS.trackIdx=nil
		if tpS.narrowTop then pcall(function() tpS.narrowTop:Cancel() end)
tpS.narrowTop=nil end
		if tpS.narrowBot then pcall(function() tpS.narrowBot:Cancel() end)
tpS.narrowBot=nil end
		if tpS.gui then pcall(function() tpS.gui:Destroy() end)
tpS.gui=nil end
		tpS.topBar=nil
tpS.bottomBar=nil
		if lyricsOverlay and lyricsOverlay.frame then
			lyricsOverlay.frame.Position=UDim2.new(0.5,0,0.87,0)
		end
	end
	local function isTeapot()
		local inf=Dat.trackList[St.currentTrackIndex]
return inf and inf.DisplayName and inf.DisplayName:lower()=="teapot lms"
	end
	local function updateSegmentedText(label,segments,seqStart)
		local conn
conn=Svc.RunService.Heartbeat:Connect(function()
			if not label or not label.Parent then conn:Disconnect();return end
			local currentTime=(os.clock()-seqStart)+CINEMATIC_VIDEO_START_OFFSET
			local visibleChars=0
			for _,seg in ipairs(segments) do if currentTime>=seg[1] then visibleChars=seg[2] end end
			label.MaxVisibleGraphemes=visibleChars
		end)
	end
	local function createCinText(data,seqStart,parent)
		local label=Instance.new("TextLabel")
		label.Size=UDim2.fromOffset(800,300)
label.Position=UDim2.fromOffset(data.x,data.y)
		label.AnchorPoint=Vector2.new(0,0)
label.TextXAlignment=Enum.TextXAlignment.Left
		label.RichText=true
label.Text="<b><i>"..data.text.."</i></b>"
		label.TextColor3=data.c
label.TextSize=data.s
label.Font=TEXT_FONT
		label.BackgroundTransparency=1
label.TextTransparency=1
label.TextStrokeTransparency=1
		label.TextStrokeColor3=data.oc
label.Parent=parent
		if data.segments then label.MaxVisibleGraphemes=0
updateSegmentedText(label,data.segments,seqStart) end
		Svc.TweenService:Create(label,TweenInfo.new(0.15),{TextTransparency=0,TextStrokeTransparency=0.4}):Play()
		local dur=data.outT-data.inT
		task.delay(dur,function()
			if label and label.Parent then
				local fade=Svc.TweenService:Create(label,TweenInfo.new(0.2),{TextTransparency=1,TextStrokeTransparency=1})
				fade:Play();fade.Completed:Wait();if label then label:Destroy() end
			end
		end)
	end
	local function tpSlideLyricsDown()
		if tpS.lyricsSlid then return end
tpS.lyricsSlid=true
		if not St.lyricsEnabled then return end
		if _cinGui then
			local sg=_cinGui
_cinGui=nil
			local topBar=sg:FindFirstChild("TopCinBar")
local botBar=sg:FindFirstChild("BotCinBar")
			local exitTI=TweenInfo.new(0.8,Enum.EasingStyle.Sine,Enum.EasingDirection.In)
			if topBar then Svc.TweenService:Create(topBar,exitTI,{Position=UDim2.new(0,0,-0.6,0)}):Play() end
			if botBar then Svc.TweenService:Create(botBar,exitTI,{Position=UDim2.new(0,0,1.6,0)}):Play() end
			task.delay(0.9,function() pcall(function() sg:Destroy() end) end)
		end
		if not lyricsOverlay or not lyricsOverlay.gui then return end
		if lyricsOverlay.frame.Position.Y.Scale < 1 then
			Svc.TweenService:Create(lyricsOverlay.frame,TweenInfo.new(1.5,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(0.5,0,1.4,0)}):Play()
		end
	end
	local function tpBuildGui()
		local sg=Instance.new("ScreenGui")
sg.Name="TeapotCinematicGui"
sg.IgnoreGuiInset=true
		sg.DisplayOrder=2147483647
sg.ResetOnSpawn=false
sg.Parent=pGui
tpS.gui=sg
		local tb=Instance.new("Frame")
tb.Size=UDim2.new(1,0,CINEMATIC_INITIAL_BAR_HEIGHT,0)
		tb.Position=UDim2.new(0,0,-CINEMATIC_INITIAL_BAR_HEIGHT,0)
tb.BackgroundColor3=Color3.new(0,0,0)
		tb.BorderSizePixel=0
tb.ZIndex=100
tb.Parent=sg
tpS.topBar=tb
		local bb=Instance.new("Frame")
bb.Size=UDim2.new(1,0,CINEMATIC_INITIAL_BAR_HEIGHT,0)
		bb.Position=UDim2.new(0,0,1+CINEMATIC_INITIAL_BAR_HEIGHT,0)
bb.AnchorPoint=Vector2.new(0,1)
		bb.BackgroundColor3=Color3.new(0,0,0)
bb.BorderSizePixel=0
bb.ZIndex=100
bb.Parent=sg
tpS.bottomBar=bb
	end
	local function tpBordersIn()
		if tpS.bordersStarted then return end
tpS.bordersStarted=true
tpS.trackIdx=St.currentTrackIndex
		tpBuildGui()
		local si=TweenInfo.new(1.0,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
		Svc.TweenService:Create(tpS.topBar,si,{Position=UDim2.new(0,0,0,0)}):Play()
		Svc.TweenService:Create(tpS.bottomBar,si,{Position=UDim2.new(0,0,1,0)}):Play()
	end
	local function tpStartSequence()
		if tpS.lyricsStarted then return end
tpS.lyricsStarted=true
		if not tpS.gui or not tpS.topBar or not tpS.bottomBar then return end
		local seqStart=os.clock()
		local ni=TweenInfo.new(CINEMATIC_SEQUENCE_DURATION,Enum.EasingStyle.Linear)
		tpS.narrowTop=Svc.TweenService:Create(tpS.topBar,ni,{Size=UDim2.new(1,0,CINEMATIC_FINAL_BAR_HEIGHT,0)})
tpS.narrowTop:Play()
		tpS.narrowBot=Svc.TweenService:Create(tpS.bottomBar,ni,{Size=UDim2.new(1,0,CINEMATIC_FINAL_BAR_HEIGHT,0)})
tpS.narrowBot:Play()
		local myIdx=tpS.trackIdx
		for _,data in ipairs(TP_LYRICS) do
			local wt=data.inT-CINEMATIC_VIDEO_START_OFFSET
			task.delay(wt,function()
				if tpS.trackIdx~=myIdx then return end
				createCinText(data,seqStart,tpS.gui)
			end)
		end
		task.delay(CINEMATIC_SEQUENCE_DURATION,function()
			if tpS.trackIdx~=myIdx then return end
			if tpS.narrowTop then tpS.narrowTop:Cancel() end
			if tpS.narrowBot then tpS.narrowBot:Cancel() end
			local exitInfo=TweenInfo.new(2.5,Enum.EasingStyle.Sine,Enum.EasingDirection.In)
			local tExit=Svc.TweenService:Create(tpS.topBar,exitInfo,{Position=UDim2.new(0,0,-0.6,0)})
			local bExit=Svc.TweenService:Create(tpS.bottomBar,exitInfo,{Position=UDim2.new(0,0,1.6,0)})
			tExit:Play();bExit:Play()
			tExit.Completed:Connect(function()
				if tpS.gui then tpS.gui:Destroy();tpS.gui=nil end
			end)
		end)
	end
	local lastTpIdx=St.currentTrackIndex
	Svc.RunService.Heartbeat:Connect(function()
		local idx=St.currentTrackIndex
		if idx~=lastTpIdx then
			lastTpIdx=idx;tpReset();return
		end
		if not isTeapot() then return end
		local s=sound;if not s or not s.IsPlaying then return end
		local pos=s.TimePosition
		-- Reset if playback jumped back near start
		if pos < TEAPOT_RESET_THRESHOLD and tpS.bordersStarted then tpReset();return end
		if pos >= TEAPOT_LYRICS_SLIDE_POS and not tpS.lyricsSlid then tpSlideLyricsDown() end
		if pos >= TEAPOT_BORDERS_IN_POS and not tpS.bordersStarted then tpBordersIn() end
		if pos >= TEAPOT_SEQUENCE_START and tpS.bordersStarted and not tpS.lyricsStarted then tpStartSequence() end
	end)
end
do
	if UI.shakeIntensityBox then UI.shakeIntensityBox.Text=tostring(St.shakeIntensity) end
	if UI.fovIntensityBox   then UI.fovIntensityBox.Text=tostring(St.fovIntensity) end
	if UI.notifVolumeBox    then UI.notifVolumeBox.Text=tostring(St.notifVolume) end
	if UI.incrementBox      then UI.incrementBox.Text=tostring(St.currentIncrement) end
	if UI.repeatToggle      then UI.repeatToggle.SetActiveSilent(St.repeatEnabled) end
	if UI.shuffleToggle     then UI.shuffleToggle.SetActiveSilent(St.shuffleEnabled) end
end
do
	-- ─────────────────────────────────────────────────────────────────────────────
-- SPECIAL TRACK ACTIONS
-- Add entries here to trigger animations/events at specific playback positions.
-- Each entry: { trackMatch = function(name) -> bool, timeStart, timeEnd, onTrigger }
-- ─────────────────────────────────────────────────────────────────────────────
local SPECIAL_TRACK_ACTIONS = {
	{
		-- Triggers a dance animation for a specific track by name
		trackMatch = function(name)
			return name:find("cukak", 1, true) and name:find("tia", 1, true)
		end,
		triggerTime    = 32,  -- seconds: when to fire
		triggerEndTime = 33,  -- seconds: window end
		animationId    = "rbxassetid://126604285933607",
		priority       = Enum.AnimationPriority.Action,
	},
}

local lcFired=false
local lcGen=0
	Svc.RunService.Heartbeat:Connect(function()
		if not sound or not sound.IsPlaying then return end
		local inf=Dat.trackList[St.currentTrackIndex]
		if not inf then return end
		local name=inf.DisplayName:lower()
		local isTarget=name:find("cukak",1,true) and name:find("tia",1,true)
		if not isTarget then lcFired=false;return end
		local pos=sound.TimePosition
		local DANCE_TRIGGER_START = 32
		local DANCE_TRIGGER_END   = 33
		if pos >= DANCE_TRIGGER_START and pos < DANCE_TRIGGER_END and not lcFired then
			lcFired=true;lcGen=lcGen+1;local g=lcGen
			task.spawn(function()
				local char=Svc.Players.LocalPlayer.Character;if not char then return end
				local hum=char:FindFirstChildWhichIsA("Humanoid");if not hum then return end
				local anim=Instance.new("Animation");anim.AnimationId="rbxassetid://126604285933607"
				local ok,track=pcall(function() return hum:LoadAnimation(anim) end)
				if ok and track then
					track.Priority=Enum.AnimationPriority.Action
					track:Play()
					local moveConn;moveConn=Svc.RunService.Heartbeat:Connect(function()
						if not track.IsPlaying then if moveConn then moveConn:Disconnect();moveConn=nil end;return end
						if hum.MoveDirection.Magnitude>0.05 then track:Stop();if moveConn then moveConn:Disconnect();moveConn=nil end end
					end)
					track.Stopped:Connect(function() if moveConn then moveConn:Disconnect();moveConn=nil end;if lcGen==g then lcFired=false end end)
				end
			end)
		elseif pos < DANCE_TRIGGER_START - 1 then lcFired = false end
	end)
end
rebuildTrackListUI()
rebuildQueueUI()
refreshShakeToggle()
refreshCrossfadeToggle()
refreshLyricsToggle()
refreshTranslateToggle()
applyThemeColors()
updateSettingsCanvas()
if #Dat.createdSounds>0 then Dat.prevTrackIndex=St.currentTrackIndex
setCurrentTrack(St.currentTrackIndex,false) end
refreshPlayButton()
showMainView()
do local s=Instance.new("Sound")
s.SoundId="rbxassetid://140172825268473"
s.Volume=0.8
s.Parent=soundsFolder
s:Play()
Svc.Debris:AddItem(s,10) end
local tc=#Dat.createdSounds
if tc>0 then showTrackNotification(tc.." track"..(tc==1 and "" or "s").." ready",false) end
print("[MusicController] Loaded — N to toggle GUI | SC Search tab: ON | CharacterAdded reload: ON | Mute fix: ON")