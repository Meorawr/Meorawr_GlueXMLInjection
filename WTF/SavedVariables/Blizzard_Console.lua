-- We'll change the login screen backgrounds to make an easily visible test.
EXPANSION_HIGH_RES_BG = {
	[[Interface\Glues\Models\UI_MainMenu_Northrend\UI_MainMenu_Northrend.m2]],
	[[Interface\Glues\Models\UI_MainMenu_Northrend\UI_MainMenu_Northrend.m2]],
	[[Interface\Glues\Models\UI_MainMenu_Northrend\UI_MainMenu_Northrend.m2]],
	[[Interface\Glues\Models\UI_MainMenu_Northrend\UI_MainMenu_Northrend.m2]],
	[[Interface\Glues\Models\UI_MainMenu_Northrend\UI_MainMenu_Northrend.m2]],
	[[Interface\Glues\Models\UI_MainMenu_Northrend\UI_MainMenu_Northrend.m2]],
	[[Interface\Glues\Models\UI_MainMenu_Northrend\UI_MainMenu_Northrend.m2]],
};

EXPANSION_LOW_RES_BG = {
	[[Interface\Glues\Models\UI_MAINMENU\UI_MainMenu.m2]],
	[[Interface\Glues\Models\UI_MAINMENU\UI_MainMenu.m2]],
	[[Interface\Glues\Models\UI_MAINMENU\UI_MainMenu.m2]],
	[[Interface\Glues\Models\UI_MAINMENU\UI_MainMenu.m2]],
	[[Interface\Glues\Models\UI_MAINMENU\UI_MainMenu.m2]],
	[[Interface\Glues\Models\UI_MAINMENU\UI_MainMenu.m2]],
	[[Interface\Glues\Models\UI_MAINMENU\UI_MainMenu.m2]],
};

-- Saved variables are loaded in a restricted environment that can't access
-- globals, but any globals defined here are coped to _G as long as no error
-- occurs.
--
-- This doesn't filter out the types of copied variables though, so we can
-- export functions to replace those in the global environment.
--
-- From that, we can then get access to _G because the store UI addon is
-- loaded after getting past the login screen. It'll call setfenv with its
-- addon table which, helpfully, includes _G as w'ere on the glue screen!
local _G;

setfenv = function(_, env)
	-- Unfortunately setfenv can't be emulated so this hoses the store UI.
	if _G or not env._G then
		return;
	end

	_G = env._G;

	-- These'll cause the last-logged-in build versions to display.
	_G.IsGMClient = function() return true; end
	_G.HideGMOnly = function() return false; end

	-- Filter out any errors as a result of our setfenv injection.
	_G.HandleLuaWarning = function() end
	_G.seterrorhandler(function(err)
		if _G.strfind(err, "Attempt to access forbidden object") then
			return;
		end

		_G.HandleLuaError(err);
	end);

	-- Load in development tooling.
	_G.LoadAddOn("Blizzard_DebugTools");

	-- Set up a scene for the background.
	local frame = _G.CreateFrame("ModelFFX", "DanceFrame", _G.GlueParent);
	frame:SetToplevel(true);
	frame:SetAllPoints(true);
	frame:Hide();
	frame:SetModel([[interface\glues\models\ui_orc\ui_orc.m2]], true);
	frame:SetCamera(0);
	frame:SetSequence(0);

	-- Editbox so you can execute stuff.
	frame.EditBox = _G.CreateFrame("EditBox", nil, frame, "InputBoxTemplate");
	frame.EditBox:SetSize(450, 32);
	frame.EditBox:SetPoint("BOTTOMLEFT", 20, 20);
	frame.EditBox:SetAutoFocus(false);
	frame.EditBox:SetPoint("CENTER");
	frame.EditBox:SetScript("OnEscapePressed", frame.EditBox.ClearFocus);
	frame.EditBox:SetScript("OnEnterPressed", function(self)
		local code = self:GetText();
		self:SetText("");

		-- Handle special prefixes.
		local showInspector = false;

		if code:sub(1, 1) == "?" then
			_G.print("Help:");
			_G.print("    Enter Lua code into the editbox to evaluate it.");
			_G.print("    Prefix input with a \"=\" to dump the result.");
			_G.print("    Prefix input with a \"/\" to inspect the result.");
			return;
		elseif code:sub(1, 1) == "=" then
			_G.DevTools_DumpCommand(code:sub(2));
			return;
		elseif code:sub(1, 1) == "/" then
			showInspector = true;
			code = "return " .. code:sub(2);
		end

		local ok, ret = _G.loadstring(code);
		if not ok then
			_G.print("|cffff0000Error: |r" .. _G.tostring(ret));
		end

		ok, ret = _G.pcall(ok);
		if not ok then
			_G.print("|cffff0000Error: |r" .. _G.tostring(ret));
		end

		-- Show the table inspector on the output if requested.
		if showInspector and _G.type(ret) == "table" then
			_G.DisplayTableInspectorWindow(ret);
		end
	end);

	-- Log frame for print output and stuff.
	frame.LogFrame = _G.CreateFrame("ScrollingMessageFrame", nil, frame);
	frame.LogFrame:SetPoint("BOTTOMLEFT", frame.EditBox, "TOPLEFT", 0, 5);
	frame.LogFrame:SetPoint("BOTTOMRIGHT", frame.EditBox, "TOPRIGHT", 0, 5);
	frame.LogFrame:SetHeight(200);
	frame.LogFrame:SetTimeVisible(10.0);
	frame.LogFrame:SetMaxLines(128);
	frame.LogFrame:SetFontObject(_G.ChatFontNormal);
	frame.LogFrame:SetIndentedWordWrap(true);
	frame.LogFrame:SetJustifyH("LEFT");
	frame.LogFrame:EnableMouseWheel(true);
	frame.LogFrame:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then
			self:ScrollUp();
		else
			self:ScrollDown();
		end
	end);

	-- Export a print function for utility purposes.
	_G.tostringall = function(...)
		local out = {};

		for i = 1, _G.select("#", ...) do
			out[i] = _G.tostring(_G.select(i, ...));
		end

		return _G.unpack(out);
	end

	_G.print = function(...)
		local message = _G.strjoin(" ", _G.tostringall(...));
		frame.LogFrame:AddMessage(message);
	end

	-- Export the log frame as the default chat frame so that dump output
	-- goes there automatically.
	_G.DEFAULT_CHAT_FRAME = frame.LogFrame;

	-- Add in some utility buttons.
	frame.LogoutButton = _G.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.LogoutButton:SetPoint("BOTTOMRIGHT", -20, 20);
	frame.LogoutButton:SetSize(150, 25);
	frame.LogoutButton:Show();
	frame.LogoutButton:SetText("Logout");
	frame.LogoutButton:SetScript("OnClick", _G.C_Login.DisconnectFromServer);

	frame.ReloadUIButton = _G.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.ReloadUIButton:SetPoint("BOTTOM", frame.LogoutButton, "TOP", 0, 5);
	frame.ReloadUIButton:SetSize(150, 25);
	frame.ReloadUIButton:Show();
	frame.ReloadUIButton:SetText("Reload UI");
	frame.ReloadUIButton:SetScript("OnClick", _G.ReloadUI);

	frame.FrameStackButton = _G.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.FrameStackButton:SetPoint("BOTTOM", frame.ReloadUIButton, "TOP", 0, 5);
	frame.FrameStackButton:SetSize(150, 25);
	frame.FrameStackButton:Show();
	frame.FrameStackButton:SetText("Toggle Frame Stack");
	frame.FrameStackButton:SetScript("OnClick", _G.FrameStackTooltip_ToggleDefaults);

	-- Spice things up a bit.
	frame.Bear = _G.CreateFrame("PlayerModel", nil, frame);
	frame.Bear:SetAllPoints(true);
	frame.Bear:SetModel(1302532);
	frame.Bear:SetDisplayInfo(29293);
	frame.Bear:SetPosition(0, 0, -1);
	frame.Bear:SetCamDistanceScale(3.25);
	frame.Bear:SetAnimation(69);

	frame.Disco = _G.CreateFrame("PlayerModel", nil, frame);
	frame.Disco:SetAllPoints(true);
	frame.Disco:SetModel(1625014);
	frame.Disco:SetPosition(0, 0, 12);
	frame.Disco:SetCamDistanceScale(12.5);
	frame.Disco:SetPitch(0.35);

	frame.Birb = _G.CreateFrame("PlayerModel", nil, frame);
	frame.Birb:SetAllPoints(true);
	frame.Birb:SetModel(1131798);
	frame.Birb:SetPosition(0, 6, 0.275);
	frame.Birb:SetCamDistanceScale(9);
	frame.Birb:SetPitch(-0.5);
	frame.Birb:SetRoll(0.15);

	-- Install our custom screen and ensure you can't accidentally swap to
	-- the character selection/creation screens.
	_G.GLUE_SCREENS["game"] = { frame = "DanceFrame" };
	_G.GlueParent_SetScreen("game");
	_G.GLUE_SCREENS["charcreate"] = { frame = "DanceFrame" };
	_G.GLUE_SCREENS["charselect"] = { frame = "DanceFrame" };

	_G.print("GlueXML injection |cff00ff00successful|r; use the editbox below to execute Lua code.");
	_G.print("Enter \"?\" for help.");
end
