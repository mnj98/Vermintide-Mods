local mod = get_mod("HideBuffs")

local pl = require'pl.import_into'()
local tablex = require'pl.tablex'

mod.persistent_storage = mod:persistent_table("persistent_storage")

--- Keep track of player ammo and hp from Numeric UI for use in equipment_ui.
mod.numeric_ui_data = {}

mod.change_slot_visibility = mod:get(mod.SETTING_NAMES.HIDE_WEAPON_SLOTS)
mod.reposition_weapon_slots =
	mod.change_slot_visibility
	or mod:get(mod.SETTING_NAMES.REPOSITION_WEAPON_SLOTS) ~= 0

mod.hp_bar_width = 553
mod.default_hp_bar_width = 553
mod.hp_bar_height = 36
mod.hp_bar_w_scale = mod.hp_bar_width / mod.default_hp_bar_width
mod.team_ammo_bar_length = 92

--- Store frame_index in a new variable.
mod:hook_safe(UnitFrameUI, "_create_ui_elements", function(self, frame_index)
	self._mod_frame_index = frame_index -- nil for player, 2 3 4 for other players
end)

mod:hook(UnitFrameUI, "draw", function(func, self, dt)
	local team_ui_ammo_bar_enabled = mod:get(mod.SETTING_NAMES.TEAM_UI_AMMO_BAR)
	if self._mod_frame_index then
		if self._mod_cached_team_ui_ammo_bar ~= team_ui_ammo_bar_enabled then
			self._dirty = true
			self._mod_cached_team_ui_ammo_bar = team_ui_ammo_bar_enabled
		end
	end

	mod:pcall(function()
		if not self._is_visible then
			return -- just from pcall
		end

		if not self._dirty then
			return -- just from pcall
		end

		if not self._mod_frame_index then -- PLAYER UI
			mod.hp_bar_width = mod.default_hp_bar_width * mod:get(mod.SETTING_NAMES.PLAYER_UI_WIDTH_SCALE)/100
			mod.hp_bar_w_scale = mod.hp_bar_width / mod.default_hp_bar_width

			self.ui_scenegraph.pivot.position[1] = mod:get(mod.SETTING_NAMES.PLAYER_UI_OFFSET_X)
			self.ui_scenegraph.pivot.position[2] = mod:get(mod.SETTING_NAMES.PLAYER_UI_OFFSET_Y)

			if mod:get(mod.SETTING_NAMES.MINI_HUD_PRESET) then
				local ability_dynamic = self._ability_widgets.ability_dynamic

				ability_dynamic.element.passes[1].content_change_function = mod.player_ability_dynamic_content_change_fun

				local ability_bar_height = mod:get(mod.SETTING_NAMES.PLAYER_ULT_BAR_HEIGHT)

				if ability_dynamic.style.ability_bar.size then
					ability_dynamic.style.ability_bar.size[2] = ability_bar_height
					ability_dynamic.offset[1] = 0
					ability_dynamic.offset[2] = 16 + 3 - ability_bar_height + ability_bar_height/2
					ability_dynamic.offset[3] = 50
					ability_dynamic.style.ability_bar.offset[1] = -(mod.hp_bar_width*0.88)/2
				end

				local hp_dynamic = self._health_widgets.health_dynamic
				hp_dynamic.style.grimoire_debuff_divider.offset[3] = 200
				if not mod.def_style then
					mod.def_style = {}
					for w_name, style in pairs( hp_dynamic.style ) do
						mod.def_style[w_name] = style.size
					end
				end

				local hp_bar_width = mod.hp_bar_width - 18 * mod.hp_bar_w_scale

				hp_dynamic.style.total_health_bar.size[1] = hp_bar_width
				hp_dynamic.style.total_health_bar.size[2] = mod.hp_bar_height - 18

				hp_dynamic.style.hp_bar_highlight.size[1] = hp_bar_width
				hp_dynamic.style.hp_bar_highlight.size[2] = mod.hp_bar_height - 8

				hp_dynamic.style.hp_bar.size[1] = hp_bar_width
				hp_dynamic.style.hp_bar.size[2] = mod.hp_bar_height - 18

				for _, pass in ipairs( hp_dynamic.element.passes ) do
					if pass.style_id == "grimoire_debuff_divider" then
						pass.content_change_function = mod.player_grimoire_debuff_divider_content_change_fun
					end
					if pass.style_id == "grimoire_bar" then
						pass.content_change_function = mod.player_grimoire_bar_content_change_fun
					end
				end
				hp_dynamic.style.grimoire_bar.size[2] = 18
				local grimoire_debuff_divider_size = hp_dynamic.style.grimoire_debuff_divider.size
				grimoire_debuff_divider_size[1] = 21
				grimoire_debuff_divider_size[2] = 36

				local total_health_bar_style = hp_dynamic.style.total_health_bar
				total_health_bar_style.offset[1] = -hp_dynamic.style.total_health_bar.size[1]/2
				total_health_bar_style.offset[2] = 35
				total_health_bar_style.offset[3] = -6

				local hp_bar_style = hp_dynamic.style.hp_bar
				hp_bar_style.offset[1] = -hp_dynamic.style.hp_bar.size[1]/2
				hp_bar_style.offset[2] = 35
				hp_bar_style.offset[3] = -5

				local hp_bar_highlight_style = hp_dynamic.style.hp_bar_highlight
				hp_bar_highlight_style.offset[1] = -hp_dynamic.style.hp_bar.size[1]/2
				hp_bar_highlight_style.offset[2] = 35 - 4
				hp_bar_highlight_style.offset[3] = -5 + 3
			end
		else -- TEAMMATE UI
			-- adjust loadout dynamic offset(item slots)
			local loadout_dynamic = self._equipment_widgets.loadout_dynamic
			loadout_dynamic.offset[1] = -15 + mod:get(mod.SETTING_NAMES.TEAM_UI_ITEM_SLOTS_OFFSET_X)
			loadout_dynamic.offset[2] = -121 + mod:get(mod.SETTING_NAMES.TEAM_UI_ITEM_SLOTS_OFFSET_Y)

			if team_ui_ammo_bar_enabled then
				loadout_dynamic.offset[2] = loadout_dynamic.offset[2] - 8
			end

			local start_x = -35
			local item_spacing = mod:get(mod.SETTING_NAMES.TEAM_UI_ITEM_SLOTS_SPACING)
			local item_size = mod:get(mod.SETTING_NAMES.TEAM_UI_ITEM_SLOTS_SIZE) + 4

			for i = 1, 3 do
				loadout_dynamic.style["item_slot_"..i].offset[1] = start_x+2.5+item_spacing*(i-1)
				loadout_dynamic.style["item_slot_"..i].size[1] = item_size-4
				loadout_dynamic.style["item_slot_"..i].size[2] = item_size-4

				for _, item_slot_name in ipairs( mod.item_slot_widgets ) do
					loadout_dynamic.style[item_slot_name..i].offset[1] = start_x+item_spacing*(i-1)
					loadout_dynamic.style[item_slot_name..i].size[1] = item_size
					loadout_dynamic.style[item_slot_name..i].size[2] = item_size
				end
			end

			local hp_bar_scale_x = mod:get(mod.SETTING_NAMES.TEAM_UI_HP_BAR_SCALE_WIDTH) / 100
			local hp_bar_scale_y = mod:get(mod.SETTING_NAMES.TEAM_UI_HP_BAR_SCALE_HEIGHT) / 100
			mod.hp_bar_size = { 92*hp_bar_scale_x, 9*hp_bar_scale_y }
			local hp_bar_size = mod.hp_bar_size

			local static_w_style = self:_widget_by_feature("default", "static").style
			static_w_style.ability_bar_bg.size = { hp_bar_size[1], 5*hp_bar_scale_y }

			local ability_bar_delta_y = 5*hp_bar_scale_y - 5
			local delta_x = hp_bar_size[1] - 92
			local delta_y = hp_bar_size[2] - 9
			mod.hp_bar_delta_y = delta_y

			static_w_style.hp_bar_bg.size[1] = 100 + delta_x
			static_w_style.hp_bar_bg.size[2] = 17 + delta_y + ability_bar_delta_y

			static_w_style.hp_bar_fg.size[1] = 100 + delta_x
			static_w_style.hp_bar_fg.size[2] = 24 + delta_y + ability_bar_delta_y

			static_w_style.ability_bar_bg.size[1] = 92 + delta_x
			static_w_style.ability_bar_bg.size[2] = 5*hp_bar_scale_y

			local hp_bar_offset_x = mod:get(mod.SETTING_NAMES.TEAM_UI_HP_BAR_OFFSET_X)
			local hp_bar_offset_y = mod:get(mod.SETTING_NAMES.TEAM_UI_HP_BAR_OFFSET_Y)
			mod.hp_bar_offset_x = hp_bar_offset_x
			mod.hp_bar_offset_y = hp_bar_offset_y

			local def_dynamic_w = self:_widget_by_feature("default", "dynamic")
			def_dynamic_w.style.ammo_indicator.offset[1] = 60 + delta_x + hp_bar_offset_x
			def_dynamic_w.style.ammo_indicator.offset[2] = -40 + delta_y/2 + hp_bar_offset_y

			static_w_style.ability_bar_bg.offset[1] = -46 + hp_bar_offset_x
			static_w_style.ability_bar_bg.offset[2] = -34 + hp_bar_offset_y

			static_w_style.hp_bar_fg.offset[1] = -50 + hp_bar_offset_x
			static_w_style.hp_bar_fg.offset[2] = -36 + hp_bar_offset_y

			static_w_style.hp_bar_bg.offset[1] = -50 + hp_bar_offset_x
			static_w_style.hp_bar_bg.offset[2] = -29 + hp_bar_offset_y

			local hp_dynamic = self:_widget_by_name("health_dynamic")
			local hp_dynamic_style = hp_dynamic.style

			hp_dynamic_style.hp_bar.offset[1] = -46 + hp_bar_offset_x
			hp_dynamic_style.hp_bar.offset[2] = -25 + delta_y/2 + hp_bar_offset_y

			hp_dynamic_style.total_health_bar.offset[1] = -46 + hp_bar_offset_x
			hp_dynamic_style.total_health_bar.offset[2] = -25 + delta_y/2 + hp_bar_offset_y

			hp_dynamic_style.total_health_bar.size[1] = hp_bar_size[1]
			hp_dynamic_style.total_health_bar.size[2] = hp_bar_size[2]
			hp_dynamic_style.hp_bar.size[1] = hp_bar_size[1]
			hp_dynamic_style.hp_bar.size[2] = hp_bar_size[2]
			hp_dynamic_style.grimoire_bar.size[1] = hp_bar_size[1]
			hp_dynamic_style.grimoire_bar.size[2] = hp_bar_size[2]

			hp_dynamic_style.hp_bar_highlight.offset[1] = -50 + hp_bar_offset_x
			hp_dynamic_style.hp_bar_highlight.offset[2] = -32 + hp_bar_offset_y

			hp_dynamic_style.grimoire_debuff_divider.size[1] = 3
			hp_dynamic_style.grimoire_debuff_divider.size[2] = 28 + delta_y

			for _, pass in ipairs( hp_dynamic.element.passes ) do
				if pass.style_id == "grimoire_debuff_divider" then
					pass.content_change_function = mod.team_grimoire_debuff_divider_content_change_fun
				end
				if pass.style_id == "grimoire_bar" then
					pass.content_change_function = mod.team_grimoire_bar_content_change_fun
				end
			end

			local ability_dynamic = self:_widget_by_feature("ability", "dynamic")
			ability_dynamic.style.ability_bar.size[2] = 5*hp_bar_scale_y
			ability_dynamic.style.ability_bar.offset[1] = -46 + hp_bar_offset_x
			ability_dynamic.style.ability_bar.offset[2] = -34 + hp_bar_offset_y

			for _, pass in ipairs( ability_dynamic.element.passes ) do
				if pass.style_id == "ability_bar" then
					pass.content_change_function = mod.team_ability_bar_content_change_fun
				end
			end

			if not self._teammate_custom_widget then
				self._teammate_custom_widget = UIWidget.init(mod.teammate_ui_custom_def)
			end

			self._teammate_custom_widget.style.hp_bar_fg.size[1] = 100 + delta_x
			self._teammate_custom_widget.style.hp_bar_fg.size[2] = 24 + delta_y + ability_bar_delta_y

			self._teammate_custom_widget.style.hp_bar_fg.offset[1] = -62 + hp_bar_offset_x
			self._teammate_custom_widget.style.hp_bar_fg.offset[2] = -37 + hp_bar_offset_y - delta_y + ability_bar_delta_y

			mod.team_ammo_bar_length = 92 + delta_x

			local ammo_bar_w = 92 + delta_x
			local ammo_bar_h = 5*hp_bar_scale_y
			self._teammate_custom_widget.style.ammo_bar.size[1] = ammo_bar_w
			self._teammate_custom_widget.style.ammo_bar.size[2] = ammo_bar_h

			self._teammate_custom_widget.style.ammo_bar_bg.size[1] = ammo_bar_w
			self._teammate_custom_widget.style.ammo_bar_bg.size[2] = ammo_bar_h

			local ammo_bar_offset_x = -59 + hp_bar_offset_x
			local ammo_bar_offset_y = -35 + hp_bar_offset_y - delta_y + ability_bar_delta_y
			self._teammate_custom_widget.style.ammo_bar.offset[1] = ammo_bar_offset_x
			self._teammate_custom_widget.style.ammo_bar.offset[2] = ammo_bar_offset_y

			self._teammate_custom_widget.style.ammo_bar_bg.offset[1] = ammo_bar_offset_x
			self._teammate_custom_widget.style.ammo_bar_bg.offset[2] = ammo_bar_offset_y

			local important_icons_offset_x = mod:get(mod.SETTING_NAMES.TEAM_UI_ICONS_OFFSET_X)
			local important_icons_offset_y = mod:get(mod.SETTING_NAMES.TEAM_UI_ICONS_OFFSET_Y)
			local icons_start_offset_x = 44
			local icons_start_offset_y = -31
			local custom_widget_style = self._teammate_custom_widget.style

			local icons_offset_x = icons_start_offset_x + delta_x + hp_bar_offset_x + important_icons_offset_x
			local icons_offset_y = icons_start_offset_y + hp_bar_offset_y + delta_y/2 + important_icons_offset_y

			custom_widget_style.icon_natural_bond.offset[1] = icons_offset_x
			custom_widget_style.icon_natural_bond.offset[2] = icons_offset_y

			local teammate_icons_alpha = mod:get(mod.SETTING_NAMES.TEAM_UI_ICONS_ALPHA)
			custom_widget_style.icon_natural_bond.color[1] = teammate_icons_alpha

			custom_widget_style.frame_natural_bond.offset[1] = custom_widget_style.icon_natural_bond.offset[1] - 2
			custom_widget_style.frame_natural_bond.offset[2] = custom_widget_style.icon_natural_bond.offset[2] - 2

			local next_icon_offset = (self.has_natural_bond and 30 or 0)

			custom_widget_style.icon_hand_of_shallya.offset[1] = icons_offset_x + next_icon_offset
			custom_widget_style.icon_hand_of_shallya.offset[2] = icons_offset_y
			custom_widget_style.icon_hand_of_shallya.color[1] = teammate_icons_alpha

			custom_widget_style.frame_hand_of_shallya.offset[1] = custom_widget_style.icon_hand_of_shallya.offset[1] - 2
			custom_widget_style.frame_hand_of_shallya.offset[2] = custom_widget_style.icon_hand_of_shallya.offset[2] - 2

			next_icon_offset = next_icon_offset + (self.has_hand_of_shallya and 30 or 0)

			custom_widget_style.icon_healshare_talent.offset[1] = icons_offset_x + next_icon_offset
			custom_widget_style.icon_healshare_talent.offset[2] = icons_offset_y
			custom_widget_style.icon_healshare_talent.color[1] = teammate_icons_alpha

			next_icon_offset = next_icon_offset + (self.has_healshare_talent and 28 or 0)

			custom_widget_style.icon_is_wounded.offset[1] = icons_offset_x + next_icon_offset - 10
			custom_widget_style.icon_is_wounded.offset[2] = icons_offset_y - 10

			custom_widget_style.frame_is_wounded.offset[1] = custom_widget_style.icon_is_wounded.offset[1] - 2 + 10
			custom_widget_style.frame_is_wounded.offset[2] = custom_widget_style.icon_is_wounded.offset[2] - 2 + 10
			custom_widget_style.frame_is_wounded.size[1] = 0

			next_icon_offset = next_icon_offset + (self.is_wounded and 30 or 0)

			if self.important_icons_enabled then
				def_dynamic_w.style.ammo_indicator.offset[1] = def_dynamic_w.style.ammo_indicator.offset[1] + next_icon_offset
			end
		end
	end)

	-- option to hide the ammo indicator
	-- by making it transparent during the draw call
	local teammate_ammo_indicator_alpha_temp
	if self._mod_frame_index and mod:get(mod.SETTING_NAMES.TEAM_UI_AMMO_HIDE_INDICATOR) then
		local def_dynamic_w = self:_widget_by_feature("default", "dynamic")
		teammate_ammo_indicator_alpha_temp = def_dynamic_w.style.ammo_indicator.color[1]
		def_dynamic_w.style.ammo_indicator.color[1] = 0
	end

	func(self, dt)

	-- restore old ammo indicator alpha color value
	if self._mod_frame_index and teammate_ammo_indicator_alpha_temp then
		local def_dynamic_w = self:_widget_by_feature("default", "dynamic")
		def_dynamic_w.style.ammo_indicator.color[1] = teammate_ammo_indicator_alpha_temp
	end

	if self._mod_frame_index
	and self._is_visible then
		local network_manager = Managers.state.network
		local game = network_manager:game()
		local widget = self._teammate_custom_widget
		if widget and self.player_unit then
			local go_id = Managers.state.unit_storage:go_id(self.player_unit)
			if self.has_ammo then
				widget.content.ammo_bar.bar_value = GameSession.game_object_field(game, go_id, "ammo_percentage")
			elseif self.has_overcharge then
				local overcharge = GameSession.game_object_field(game, go_id, "overcharge_percentage")
				widget.content.ammo_bar.bar_value = overcharge
			end
		end

		-- adjust teammate ammo bar visibility
		local draw_ammo_bar =
			team_ui_ammo_bar_enabled
			and (
				self.has_ammo
				or self.has_overcharge and mod:get(mod.SETTING_NAMES.TEAM_UI_AMMO_SHOW_HEAT)
				)
		self._teammate_custom_widget.content.ammo_bar.draw_ammo_bar = draw_ammo_bar
		self._teammate_custom_widget.style.hp_bar_fg.color[1] = draw_ammo_bar and 255 or 0

		local ui_renderer = self.ui_renderer
		local ui_scenegraph = self.ui_scenegraph
		local input_service = self.input_manager:get_service("ingame_menu")
		local render_settings = self.render_settings
		UIRenderer.begin_pass(ui_renderer, ui_scenegraph, input_service, dt, nil, render_settings)
		UIRenderer.draw_widget(ui_renderer, self._teammate_custom_widget)
		UIRenderer.end_pass(ui_renderer)
	end
end)

mod:hook(UnitFrameUI, "set_ammo_percentage", function (func, self, ammo_percent)
	if self._mod_frame_index then
		mod:pcall(function()
			local widget = self._teammate_custom_widget
			self:_on_player_ammo_changed("ammo", widget, ammo_percent)
			self:_set_widget_dirty(widget)
			self:set_dirty()
		end)
	end

	return func(self, ammo_percent)
end)

mod:hook_safe(UnitFrameUI, "set_portrait_frame", function(self)
	mod.adjust_portrait_size_and_position(self)
end)

mod:hook(UnitFrameUI, "update", function(func, self, ...)
	mod:pcall(function()
		if self.unit_frame_index then
			self._mod_frame_index = self.unit_frame_index > 1 and self.unit_frame_index or nil
		end

		local portrait_static = self._widgets.portrait_static

		-- frame hiding: texture_1 is static frame, texture_2 is dynamic frame
		local frame_texture_alpha = mod:get(mod.SETTING_NAMES.HIDE_FRAMES) and 0 or 255
		for _, frame_texture_name in ipairs( mod.frame_texture_names ) do
			if portrait_static.style[frame_texture_name]
			and portrait_static.style[frame_texture_name].color[1] ~= frame_texture_alpha
			then
				portrait_static.style[frame_texture_name].color[1] = frame_texture_alpha
				self:_set_widget_dirty(portrait_static)
			end
		end

		-- hide frames
		if mod:get(mod.SETTING_NAMES.FORCE_DEFAULT_FRAME)
		and portrait_static.content.texture_1 ~= "portrait_frame_0000" then
			self:set_portrait_frame("default", portrait_static.content.level_text)
		end

		-- hide levels
		local level_alpha = mod:get(mod.SETTING_NAMES.HIDE_LEVELS) and 0 or 255
		if portrait_static.style.level.text_color[1] ~= level_alpha then
			portrait_static.style.level.text_color[1] = level_alpha
			self:_set_widget_dirty(portrait_static)
		end

		if not self._mod_frame_index then -- player UI
			-- hide player portrait
			local hide_player_portrait = mod:get(mod.SETTING_NAMES.HIDE_PLAYER_PORTRAIT)
			local status_icon_widget = self:_widget_by_feature("status_icon", "dynamic")
			local status_icon_widget_content = status_icon_widget.content
			if (hide_player_portrait and status_icon_widget_content.visible)
			or (hide_player_portrait and status_icon_widget_content.visible == nil)
			or (not hide_player_portrait and not status_icon_widget_content.visible)
			then
				status_icon_widget_content.visible = not hide_player_portrait
				self:_set_widget_dirty(status_icon_widget)
			end

			local player_portrait_x = mod:get(mod.SETTING_NAMES.PLAYER_UI_PLAYER_PORTRAIT_OFFSET_X)
			local player_portrait_y = mod:get(mod.SETTING_NAMES.PLAYER_UI_PLAYER_PORTRAIT_OFFSET_Y)
			status_icon_widget.offset[1] = player_portrait_x
			status_icon_widget.offset[2] = player_portrait_y

			local def_static_widget = self:_widget_by_feature("default", "static")
			local def_static_widget_content = def_static_widget.content
			if (hide_player_portrait and def_static_widget_content.visible)
			or (hide_player_portrait and def_static_widget_content.visible == nil)
			or (not hide_player_portrait and not def_static_widget_content.visible)
			then
				def_static_widget_content.visible = not hide_player_portrait
				self:_set_widget_dirty(def_static_widget)
			end

			def_static_widget.offset[1] = player_portrait_x
			def_static_widget.offset[2] = player_portrait_y

			local portrait_widget = self._portrait_widgets.portrait_static
			local portrait_widget_content = portrait_widget.content
			if (hide_player_portrait and portrait_widget_content.visible)
			or (hide_player_portrait and portrait_widget_content.visible == nil)
			or (not hide_player_portrait and not portrait_widget_content.visible)
			then
				portrait_widget_content.visible = not hide_player_portrait
				self:_set_widget_dirty(portrait_widget)
			end

			portrait_widget.offset[1] = player_portrait_x
			portrait_widget.offset[2] = player_portrait_y

			-- reposition the "needs help" icon that goes over the portrait
			local def_dynamic = self:_widget_by_feature("default", "dynamic")
			def_dynamic.style.portrait_icon.offset[1] = player_portrait_x
			def_dynamic.style.portrait_icon.offset[2] = player_portrait_y

			-- NumericUI interop.
			-- NumericUI stores hp and ammo in vanilla widgets content.
			-- So just copy those values to our teammate widget.
			local hp_dynamic = self:_widget_by_feature("health", "dynamic")
			mod.numeric_ui_data.health_string = hp_dynamic.content.health_string or ""
			mod.numeric_ui_data.cooldown_string = hp_dynamic.content.cooldown_string or ""

			-- ammo
			mod.numeric_ui_data.ammo_string = def_dynamic.content.ammo_string or ""
			mod.numeric_ui_data.ammo_percent = def_dynamic.content.ammo_percent
			mod.numeric_ui_data.ammo_style = def_dynamic.content.ammo_style
		else -- changes to the non-player portraits UI
			if self._teammate_custom_widget then -- update important icons
				local teammate_widget_content = self._teammate_custom_widget.content
				local important_icons_enabled = mod:get(mod.SETTING_NAMES.TEAM_UI_ICONS_GROUP)
				self.important_icons_enabled = important_icons_enabled
				if teammate_widget_content.important_icons_enabled ~= important_icons_enabled then
					teammate_widget_content.important_icons_enabled = important_icons_enabled
					self:_set_widget_dirty(self._teammate_custom_widget)
					self:set_dirty()
				end
				if teammate_widget_content.has_natural_bond ~= self.has_natural_bond
				or teammate_widget_content.is_wounded ~= self.is_wounded
				or teammate_widget_content.has_healshare_talent ~= self.has_healshare_talent
				or teammate_widget_content.has_hand_of_shallya ~= self.has_hand_of_shallya
				then
					teammate_widget_content.has_natural_bond = self.has_natural_bond
					teammate_widget_content.is_wounded = self.is_wounded
					teammate_widget_content.has_healshare_talent = self.has_healshare_talent
					teammate_widget_content.has_hand_of_shallya = self.has_hand_of_shallya
					self:_set_widget_dirty(self._teammate_custom_widget)
					self:set_dirty()
				end

				-- NumericUI interop.
				-- NumericUI stores hp and ammo in vanilla widgets content.
				-- So just copy those values to our teammate widget.
				local hp_dynamic = self:_widget_by_feature("health", "dynamic")
				teammate_widget_content.health_string = hp_dynamic.content.health_string or ""

				-- ammo
				local def_dynamic = self:_widget_by_feature("default", "dynamic")
				teammate_widget_content.cooldown_string = def_dynamic.content.cooldown_string or ""
				teammate_widget_content.ammo_string = def_dynamic.content.ammo_string or ""
				teammate_widget_content.ammo_percent = def_dynamic.content.ammo_percent
				teammate_widget_content.ammo_style = def_dynamic.content.ammo_style

				local teammate_widget_style = self._teammate_custom_widget.style
				local ammo_text_x = 80 + mod:get(mod.SETTING_NAMES.TEAM_UI_NUMERIC_UI_AMMO_OFFSET_X)
				teammate_widget_style.ammo_text.offset[1] = ammo_text_x
				teammate_widget_style.ammo_text_shadow.offset[1] = ammo_text_x + 2

				local ammo_text_y = 65 + mod:get(mod.SETTING_NAMES.TEAM_UI_NUMERIC_UI_AMMO_OFFSET_Y)
				teammate_widget_style.ammo_text.offset[2] = ammo_text_y
				teammate_widget_style.ammo_text_shadow.offset[2] = ammo_text_y - 2

				local hp_text_x = 80 + mod:get(mod.SETTING_NAMES.TEAM_UI_NUMERIC_UI_HP_OFFSET_X)
				teammate_widget_style.hp_text.offset[1] = hp_text_x
				teammate_widget_style.hp_text_shadow.offset[1] = hp_text_x + 1

				local hp_text_y = 100 + mod:get(mod.SETTING_NAMES.TEAM_UI_NUMERIC_UI_HP_OFFSET_Y)
				teammate_widget_style.hp_text.offset[2] = hp_text_y
				teammate_widget_style.hp_text_shadow.offset[2] = hp_text_y - 1

				local ult_cd_text_x = 70 + mod:get(mod.SETTING_NAMES.TEAM_UI_NUMERIC_UI_ULT_CD_OFFSET_X)
				teammate_widget_style.cooldown_text.offset[1] = ult_cd_text_x
				teammate_widget_style.cooldown_text_shadow.offset[1] = ult_cd_text_x + 2

				local ult_cd_text_y = 40 + mod:get(mod.SETTING_NAMES.TEAM_UI_NUMERIC_UI_ULT_CD_OFFSET_Y)
				teammate_widget_style.cooldown_text.offset[2] = ult_cd_text_y
				teammate_widget_style.cooldown_text_shadow.offset[2] = ult_cd_text_y - 2

				local numeric_ui_font_size = mod:get(mod.SETTING_NAMES.TEAM_UI_NUMERIC_UI_HP_FONT_SIZE)
				teammate_widget_style.hp_text.font_size = numeric_ui_font_size
				teammate_widget_style.hp_text_shadow.font_size = numeric_ui_font_size
			end

			if not self._hb_mod_cached_character_portrait_size then
				-- keep the default portrait size cached
				self._hb_mod_cached_character_portrait_size = table.clone(self._default_widgets.default_static.style.character_portrait.size)
			end
			local portrait_scale = mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_SCALE)/100
			local scaled_character_portrait_size = tablex.map("*", self._hb_mod_cached_character_portrait_size, portrait_scale)
			if mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_ICONS) ~= mod.PORTRAIT_ICONS.DEFAULT then
				self._default_widgets.default_static.style.character_portrait.size = tablex.map("*", {80,80}, portrait_scale)
			else
				self._default_widgets.default_static.style.character_portrait.size = scaled_character_portrait_size
			end

			local widget = self:_widget_by_feature("status_icon", "dynamic")
			widget.style.portrait_icon.size = tablex.map("*", self._hb_mod_cached_character_portrait_size, portrait_scale)

			local team_ui_portrait_offset_x = mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_OFFSET_X)
			local team_ui_portrait_offset_y = mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_OFFSET_Y)

			local portrait_size = widget.style.portrait_icon.size
			widget.style.portrait_icon.offset[1] = -portrait_size[1]/2 + team_ui_portrait_offset_x
			local delta_y = self._hb_mod_cached_character_portrait_size[2] -
				self._default_widgets.default_static.style.character_portrait.size[2]
			if mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_ICONS) ~= mod.PORTRAIT_ICONS.DEFAULT then
				delta_y = self._hb_mod_cached_character_portrait_size[2] -
					scaled_character_portrait_size[2]
			end
			widget.style.portrait_icon.offset[2] = delta_y/2 + team_ui_portrait_offset_y

			local def_dynamic_w = self:_widget_by_feature("default", "dynamic")
			local def_dynamic_style = def_dynamic_w.style

			for _, talk_widget_name in ipairs( mod.def_dynamic_widget_names ) do
				def_dynamic_style[talk_widget_name].offset[1] = 60 + team_ui_portrait_offset_x
				def_dynamic_style[talk_widget_name].offset[2] = 30 + team_ui_portrait_offset_y
			end

			local connecting_icon_style = def_dynamic_style.connecting_icon
			connecting_icon_style.offset[1] = -25 + team_ui_portrait_offset_x
			connecting_icon_style.offset[2] = 34 + team_ui_portrait_offset_y

			if not self._hb_mod_adjusted_portraits then
				self._hb_mod_adjusted_portraits = true
				mod.adjust_portrait_size_and_position(self)
			end

			local widgets = self._widgets
			local previous_widget = widgets.portrait_static
			if (
					self._hb_mod_portrait_scale_lf ~= portrait_scale
					or self._hb_mod_portrait_offset_x_lf ~= team_ui_portrait_offset_x
					or self._hb_mod_portrait_offset_y_lf ~= team_ui_portrait_offset_y
				)
				and previous_widget.content.level_text
			then
				self._hb_mod_portrait_offset_x_lf = team_ui_portrait_offset_x
				self._hb_mod_portrait_offset_y_lf = team_ui_portrait_offset_y
				self._hb_mod_portrait_scale_lf = portrait_scale

				local current_frame_settings_name = previous_widget.content.frame_settings_name
				previous_widget.content.scale = portrait_scale
				previous_widget.content.frame_settings_name = nil
				self:set_portrait_frame(current_frame_settings_name, previous_widget.content.level_text)
			end

			local def_static_widget = self:_widget_by_feature("player_name", "static")
			if def_static_widget then
				local team_ui_name_offset_x = mod:get(mod.SETTING_NAMES.TEAM_UI_NAME_OFFSET_X)
				local team_ui_name_offset_y = mod:get(mod.SETTING_NAMES.TEAM_UI_NAME_OFFSET_Y)

				local def_static_widget_style = def_static_widget.style
				def_static_widget_style.player_name.offset[1] = 0 + team_ui_name_offset_x
				def_static_widget_style.player_name.offset[2] = 110 + team_ui_name_offset_y
				def_static_widget_style.player_name_shadow.offset[1] = 2 + team_ui_name_offset_x
				def_static_widget_style.player_name_shadow.offset[2] = 110 - 2 + team_ui_name_offset_y

				local team_ui_player_name_alignment = mod.ALIGNMENTS_LOOKUP[mod:get(mod.SETTING_NAMES.TEAM_UI_PLAYER_NAME_ALIGNMENT)]
				def_static_widget_style.player_name.horizontal_alignment = team_ui_player_name_alignment
				def_static_widget_style.player_name_shadow.horizontal_alignment = team_ui_player_name_alignment
			end

			-- different hero portraits
			local team_ui_portrait_icons = mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_ICONS)
			local profile_index = self.profile_index
			if profile_index then
				local profile_data = SPProfiles[profile_index]
				local def_static_content = self:_widget_by_feature("default", "static").content
				local character_portrait = def_static_content.character_portrait
				if not def_static_content.portrait_backup then
					def_static_content.portrait_backup = character_portrait
				end
				local default_portrait = def_static_content.portrait_backup

				if team_ui_portrait_icons == mod.PORTRAIT_ICONS.HERO then
					local hero_icon = UISettings.hero_icons.medium[profile_data.display_name]
					if character_portrait ~= hero_icon then
						mod.set_portrait(self, hero_icon)
					end
				elseif team_ui_portrait_icons == mod.PORTRAIT_ICONS.HATS then
					local careers = profile_data.careers
					local career_index = self.career_index
					if career_index then
						local career_name = careers[career_index].display_name
						local hat_icon = mod.career_name_to_hat_icon[career_name]
						if hat_icon and character_portrait ~= hat_icon then
							mod.set_portrait(self, hat_icon)
						end
					end
				elseif character_portrait ~= default_portrait then
					mod.set_portrait(self, default_portrait)
				end

				-- for testing
				-- self:set_portrait("hero_icon_medium_dwarf_ranger_yellow")
				-- self:set_portrait("icon_wpn_dw_axe_01_t1_dual")
				-- self:set_portrait("icon_ironbreaker_hat_0000")
				-- local widget = self:_widget_by_feature("default", "static")
				-- widget.style.character_portrait.size = {80,80}
				-- widget.style.character_portrait.offset[2] = -15+(108-86)+7
				-- mod.adjust_portrait_size_and_position(self)
			end
		end
	end)
	return func(self, ...)
end)

mod:hook(UnitFrameUI, "_update_portrait_opacity", function(func, self, is_dead, is_knocked_down, needs_help, assisted_respawn)
	local widget = self:_widget_by_feature("default", "static")
	local color = widget.style.character_portrait.color

	local normal_state = not is_dead
			and not is_knocked_down
			and not needs_help
			and not assisted_respawn

	local alpha_temp = color[1]
	if normal_state then
		color[1] = 255 -- skip an if check that dirties the widget
	end

	local is_dirtied = func(self, is_dead, is_knocked_down, needs_help, assisted_respawn)

	local portrait_alpha = mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_ALPHA)
	if not is_dirtied and normal_state then
		color[1] = portrait_alpha
		if alpha_temp ~= portrait_alpha then
			self:_set_widget_dirty(widget)
			return true
		end
	end

	return is_dirtied
end)

--- Catch unit_frame_ui:set_portrait calls to cache the real portrait.
mod:hook_safe(UnitFrameUI, "set_portrait", function(self)
	local widget = self:_widget_by_feature("default", "static")
	local widget_content = widget.content
	widget_content.portrait_backup = widget_content.character_portrait
end)

--- Catch Material.set_vector2 crash on changed portrait textures.
mod:hook(UnitFrameUI, "set_portrait_status", function(func, ...)
	mod:hook_enable(Material, "set_vector2")

	func(...)

	mod:hook_disable(Material, "set_vector2")
end)

mod:hook(Material, "set_vector2", function(func, gui_material, ...)
	if not gui_material then
		return
	end

	return func(gui_material, ...)
end)

mod:hook(UnitFramesHandler, "_create_unit_frame_by_type", function(func, self, frame_type, frame_index)
	local unit_frame = func(self, frame_type, frame_index)
	if frame_type == "player" and mod:get(mod.SETTING_NAMES.MINI_HUD_PRESET) then
		local new_definitions = local_require("scripts/ui/hud_ui/player_console_unit_frame_ui_definitions")
		unit_frame.definitions.widget_definitions.health_dynamic = new_definitions.widget_definitions.health_dynamic
		unit_frame.widget = UnitFrameUI:new(self.ingame_ui_context, unit_frame.definitions, unit_frame.data, frame_index, unit_frame.player_data)
	end
	return unit_frame
end)

--- Realign teammate portraits and pass additional data to unit frames.
mod:hook(UnitFramesHandler, "update", function(func, self, ...)
	if not self._hb_mod_first_frame_done then
		self._hb_mod_first_frame_done = true

		mod.realign_team_member_frames = true
		mod.recreate_player_unit_frame = true
	end

	if mod.realign_team_member_frames then
		mod.realign_team_member_frames = false

		self:_align_team_member_frames()
	end

	if mod.recreate_player_unit_frame then
		mod.recreate_player_unit_frame = false

		local my_unit_frame = self._unit_frames[1]
		my_unit_frame.widget:destroy()

		local new_unit_frame = self:_create_unit_frame_by_type("player")
		new_unit_frame.player_data = my_unit_frame.player_data
		new_unit_frame.sync = true
		self._unit_frames[1] = new_unit_frame

		self:set_visible(self._is_visible)
	end

	for _, unit_frame in ipairs(self._unit_frames) do
		local has_ammo
		local has_overcharge
		local player_data = unit_frame.player_data
		local player_unit = player_data.player_unit
		local player_ui_id = player_data.player_ui_id

		local inventory_extension = ScriptUnit.has_extension(player_unit, "inventory_system")
		if inventory_extension then
			local equipment = inventory_extension:equipment()
			if equipment then
				local slot_data = equipment.slots["slot_ranged"]
				local item_data = slot_data and slot_data.item_data

				if item_data then
					local item_template = BackendUtils.get_item_template(item_data)
					has_overcharge = not not item_template.overcharge_data
					has_ammo = not not item_template.ammo_data
				end
			end
		end

		local unit_frame_w = unit_frame.widget
		unit_frame_w.unit_frame_index = self._unit_frame_index_by_ui_id[player_ui_id]

		local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")
		if buff_extension then
			unit_frame_w.has_natural_bond = false
			if mod:get(mod.SETTING_NAMES.TEAM_UI_ICONS_NATURAL_BOND) then
				unit_frame_w.has_natural_bond = buff_extension:has_buff_type("trait_necklace_no_healing_health_regen")
			end
			unit_frame_w.has_hand_of_shallya = false
			if mod:get(mod.SETTING_NAMES.TEAM_UI_ICONS_HAND_OF_SHALLYA) then
				unit_frame_w.has_hand_of_shallya = buff_extension:has_buff_type("trait_necklace_heal_self_on_heal_other")
			end

			unit_frame_w.has_healshare_talent = false
			if mod:get(mod.SETTING_NAMES.TEAM_UI_ICONS_HEALSHARE) then
				for _, hs_buff_name in ipairs( mod.healshare_buff_names ) do
					if buff_extension:has_buff_type(hs_buff_name) then
						unit_frame_w.has_healshare_talent = true
						break
					end
				end
			end
		end

		local is_wounded = unit_frame.data.is_wounded
		unit_frame_w.is_wounded = is_wounded

		-- wounded buff handling for local player
		if player_unit then
			local buff_ext = ScriptUnit.extension(player_unit, "buff_system")
			if buff_ext then
				if unit_frame_w.unit_frame_index == 1
				and is_wounded
				and mod:get(mod.SETTING_NAMES.PLAYER_UI_CUSTOM_BUFFS_WOUNDED)
				then
					buff_ext:add_buff("custom_wounded")
				else
					local wounded_buff = buff_ext:get_non_stacking_buff("custom_wounded")
					if wounded_buff then
						buff_ext:remove_buff(wounded_buff.id)
					end
				end
			end
		end

		-- for debugging
		-- unit_frame_w.is_wounded = true
		-- unit_frame_w.has_natural_bond = true
		-- unit_frame_w.has_hand_of_shallya = true
		-- unit_frame_w.has_healshare_talent = true

		unit_frame_w.has_ammo = has_ammo
		unit_frame_w.has_overcharge = has_overcharge
		unit_frame_w.player_unit = player_unit
		unit_frame_w.profile_index = self.profile_synchronizer:profile_by_peer(player_data.peer_id, player_data.local_player_id)

		local extensions = player_data.extensions
		if extensions and extensions.career then
			unit_frame_w.career_index = extensions.career:career_index()
		end
	end

	return func(self, ...)
end)

--- Teammate UI.
mod:hook_origin(UnitFramesHandler, "_align_team_member_frames", function(self)
	local start_offset_x = 80 + mod:get(mod.SETTING_NAMES.TEAM_UI_OFFSET_X)
	local start_offset_y = -100 + mod:get(mod.SETTING_NAMES.TEAM_UI_OFFSET_Y)
	local spacing = mod:get(mod.SETTING_NAMES.TEAM_UI_SPACING)
	local is_visible = self._is_visible
	local count = 0

	for index, unit_frame in ipairs(self._unit_frames) do
		if index > 1 then
			local widget = unit_frame.widget
			local player_data = unit_frame.player_data
			local peer_id = player_data.peer_id
			local connecting_peer_id = player_data.connecting_peer_id

			if (peer_id or connecting_peer_id) and is_visible then
				local position_x = start_offset_x
				local position_y = start_offset_y - count * spacing

				if mod:get(mod.SETTING_NAMES.TEAM_UI_FLOWS_HORIZONTALLY) then
					position_x = start_offset_x + count * spacing
					position_y = start_offset_y
				end

				widget:set_position(position_x, position_y)

				count = count + 1

				widget:set_visible(true)
			else
				widget:set_visible(false)
			end
		end
	end
end)

--- Chat position and background transparency.
mod:hook("ChatGui", "update", function(func, self, ...)
	mod:pcall(function()
		local position = self.ui_scenegraph.chat_window_root.local_position
		position[1] = mod:get(mod.SETTING_NAMES.CHAT_OFFSET_X)
		position[2] = 200 + mod:get(mod.SETTING_NAMES.CHAT_OFFSET_Y)
		self.chat_window_widget.style.background.color[1] = mod:get(mod.SETTING_NAMES.CHAT_BG_ALPHA)
	end)

	return func(self, ...)
end)

--- Hide or make less obtrusive the floating mission marker.
--- Used for "Set Free" on respawned player.
mod:hook(TutorialUI, "update_mission_tooltip", function(func, self, ...)
	if mod:get(mod.SETTING_NAMES.NO_TUTORIAL_UI) then
		return
	end

	func(self, ...)

	if mod:get(mod.SETTING_NAMES.UNOBTRUSIVE_MISSION_TOOLTIP) then
		mod:pcall(function()
			local widget = self.tooltip_mission_widget
			widget.style.texture_id.size = nil
			widget.style.texture_id.offset = { 0, 0 }
			if widget.style.text.text_color[1] ~= 0 then
				widget.style.texture_id.color[1] = 100
				widget.style.text.text_color[1] = 100
				widget.style.text_shadow.text_color[1] = 100
			else
				widget.style.texture_id.size = { 32, 32 }
				widget.style.texture_id.offset = { 16+16, 16 }
			end
		end)
	end
end)

mod:hook(TutorialUI, "update", function(func, self, ...)
	if mod:get(mod.SETTING_NAMES.NO_TUTORIAL_UI) then
		mod:pcall(function()
			self.active_tooltip_widget = nil
			for _, obj_tooltip in ipairs( self.objective_tooltip_widget_holders ) do
				obj_tooltip.updated = false
			end
		end)
	end
	return func(self, ...)
end)

--- Change size and transparency of floating objective icon.
mod:hook(TutorialUI, "update_objective_tooltip_widget", function(func, self, widget_holder, player_unit, dt)
	func(self, widget_holder, player_unit, dt)

	if mod:get(mod.SETTING_NAMES.UNOBTRUSIVE_FLOATING_OBJECTIVE) then
		local widget = self.objective_tooltip_widget_holders[1].widget
		local icon_style = widget.style.texture_id
		icon_style.size = { 32, 32 }
		icon_style.offset = { 16, 16 }
		icon_style.color[1] = 75

		if widget.style.text.text_color[1] ~= 0 then
			widget.style.text.text_color[1] = 100
			widget.style.text_shadow.text_color[1] = 100
		end
	end
end)

mod:hook(MissionObjectiveUI, "draw", function(func, self, dt)
	if mod:get(mod.SETTING_NAMES.NO_MISSION_OBJECTIVE) then
		return
	end

	return func(self, dt)
end)

--- Hide boss hp bar.
mod:hook(BossHealthUI, "_draw", function(func, self, dt, t)
	if mod:get(mod.SETTING_NAMES.HIDE_BOSS_HP_BAR) then
		return
	end

	return func(self, dt, t)
end)

-- not making this mod.disable_outlines to attempt some optimization
-- since OutlineSystem.always gets called a crazy amount of times per frame
local disable_outlines = false

--- Hide HUD when inspecting or when "Hide HUD" toggled with hotkey.
mod:hook(GameModeManager, "has_activated_mutator", function(func, self, name, ...)
	if name == "realism" then
		if mod:get(mod.SETTING_NAMES.HIDE_HUD_WHEN_INSPECTING) then
			local just_return
			pcall(function()
				local player_unit = Managers.player:local_player().player_unit
				local character_state_machine_ext = ScriptUnit.extension(player_unit, "character_state_machine_system")
				just_return = character_state_machine_ext:current_state() == "inspecting"
			end)

			local is_inpecting = not not just_return
			disable_outlines = is_inpecting
			if is_inpecting then
				return true
			end
		end

		if mod.keep_hud_hidden then
			return true
		end
	end

	return func(self, name, ...)
end)

--- Patch realism visibility_group to show LevelCountdownUI.
mod:hook(IngameHud, "_update_component_visibility", function(func, self)
	if self._definitions then
		for _, visibility_group in ipairs( self._definitions.visibility_groups ) do
			if visibility_group.name == "realism" then
				visibility_group.visible_components["LevelCountdownUI"] = true
			end
		end
	end

	return func(self)
end)

--- Disable hero outlines.
mod:hook(OutlineSystem, "always", function(func, self, ...)
	if disable_outlines then
		return false
	end

	return func(self, ...)
end)

--- Disable level intro audio.
mod:hook(StateLoading, "_trigger_sound_events", function(func, self, level_key)
	if mod:get(mod.SETTING_NAMES.DISABLE_LEVEL_INTRO_AUDIO) then
		return
	end

	return func(self, level_key)
end)

--- Mute Olesya in the Ubersreik levels.
mod:hook(DialogueSystem, "trigger_sound_event_with_subtitles", function(func, self, sound_event, subtitle_event, speaker_name)
	local level_key = Managers.state.game_mode and Managers.state.game_mode:level_key()

	if speaker_name == "ferry_lady"
	and level_key
	and mod.ubersreik_lvls:contains(level_key)
	and mod:get(mod.SETTING_NAMES.DISABLE_OLESYA_UBERSREIK_AUDIO)
	then
		return
	end

	return func(self, sound_event, subtitle_event, speaker_name)
end)

--- Hide name of new location text.
mod:hook(PlayerHud, "set_current_location", function(func, self, ...)
	if mod:get(mod.SETTING_NAMES.HIDE_NEW_AREA_TEXT) then
		return
	end

	return func(self, ...)
end)

--- Reposition the subtitles.
mod:hook_safe(SubtitleGui, "update", function(self)
	local subtitle_widget = self.subtitle_widget
	if not subtitle_widget.offset then
		subtitle_widget.offset = { 0, 0, 0 }
	end
	subtitle_widget.offset[1] = mod:get(mod.SETTING_NAMES.OTHER_ELEMENTS_SUBTITLES_OFFSET_X)
	subtitle_widget.offset[2] = mod:get(mod.SETTING_NAMES.OTHER_ELEMENTS_SUBTITLES_OFFSET_Y)
end)

--- Reposition the heat bar.
mod:hook_safe(OverchargeBarUI, "update", function(self)
	local charge_bar = self.charge_bar
	if not charge_bar.offset then
		charge_bar.offset = { 0, 0, 0 }
	end
	charge_bar.offset[1] = mod:get(mod.SETTING_NAMES.OTHER_ELEMENTS_HEAT_BAR_OFFSET_X)
	charge_bar.offset[2] = mod:get(mod.SETTING_NAMES.OTHER_ELEMENTS_HEAT_BAR_OFFSET_Y)
end)

--- Reposition the Twitch voting UI.
mod:hook(TwitchVoteUI, "_draw", function(func, self, dt, t)
	local local_position = self._ui_scenegraph.base_area.local_position
	local_position[1] = 0 + mod:get(mod.SETTING_NAMES.OTHER_ELEMENTS_TWITCH_VOTE_OFFSET_X)
	local_position[2] = 120 + mod:get(mod.SETTING_NAMES.OTHER_ELEMENTS_TWITCH_VOTE_OFFSET_Y)

	return func(self, dt, t)
end)

--- Hide the "Waiting for rescue" message.
mod:hook(WaitForRescueUI, "update", function(func, ...)
	if mod:get(mod.SETTING_NAMES.HIDE_WAITING_FOR_RESCUE) then
		return
	end

	return func(...)
end)

--- Hide the Twitch mode icons in lower right.
mod:hook(TwitchIconView, "_draw", function(func, self, ...)
	if mod:get(mod.SETTING_NAMES.HIDE_TWITCH_MODE_ON_ICON) then
		return
	end

	return func(self, ...)
end)

mod:dofile("scripts/mods/HideBuffs/mod_data")
mod:dofile("scripts/mods/HideBuffs/mod_events")
mod:dofile("scripts/mods/HideBuffs/content_change_functions")
mod:dofile("scripts/mods/HideBuffs/teammate_widget_definitions")
mod:dofile("scripts/mods/HideBuffs/buff_ui")
mod:dofile("scripts/mods/HideBuffs/ability_ui")
mod:dofile("scripts/mods/HideBuffs/equipment_ui")
mod:dofile("scripts/mods/HideBuffs/second_buff_bar")
mod:dofile("scripts/mods/HideBuffs/persistent_ammo_counter")
mod:dofile("scripts/mods/HideBuffs/locked_and_loaded_compat")
mod:dofile("scripts/mods/HideBuffs/faster_chest_opening")
mod:dofile("scripts/mods/HideBuffs/custom_buffs")
mod:dofile("scripts/mods/HideBuffs/stamina_shields")

--- MOD FUNCTIONS ---
mod.reapply_pickup_ranges = function()
	OutlineSettings.ranges = table.clone(mod.persistent_storage.outline_ranges_backup)
	if mod:get(mod.SETTING_NAMES.HIDE_PICKUP_OUTLINES) then
		OutlineSettings.ranges.pickup = 0
	end
	if mod:get(mod.SETTING_NAMES.HIDE_OTHER_OUTLINES) then
		OutlineSettings.ranges.doors = 0
		OutlineSettings.ranges.objective = 0
		OutlineSettings.ranges.objective_light = 0
		OutlineSettings.ranges.interactable = 0
		OutlineSettings.ranges.revive = 0
		OutlineSettings.ranges.player_husk = 0
		OutlineSettings.ranges.elevators = 0
	end
end

mod.adjust_portrait_size_and_position = function(unit_frame_ui)
	local self = unit_frame_ui
	if self._mod_frame_index then
		local widgets = self._widgets
		local team_ui_portrait_offset_x = mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_OFFSET_X)
		local team_ui_portrait_offset_y = mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_OFFSET_Y)

		local default_static_widget = self._default_widgets.default_static
		local default_static_style = default_static_widget.style
		local portrait_size = default_static_style.character_portrait.size
		default_static_style.character_portrait.offset[1] = -portrait_size[1]/2 + team_ui_portrait_offset_x

		local delta_y = self._hb_mod_cached_character_portrait_size[2] -
			default_static_style.character_portrait.size[2]
		if mod:get(mod.SETTING_NAMES.TEAM_UI_PORTRAIT_ICONS) ~= mod.PORTRAIT_ICONS.DEFAULT then
			delta_y = 86 - default_static_style.character_portrait.size[2] + 10+15
		end
		default_static_style.character_portrait.offset[2] = 1 + delta_y/2 + team_ui_portrait_offset_y

		local portrait_static_w = widgets.portrait_static
		portrait_static_w.offset[1] = team_ui_portrait_offset_x
		portrait_static_w.offset[2] = team_ui_portrait_offset_y

		default_static_style.host_icon.offset[1] = -50 + team_ui_portrait_offset_x
		default_static_style.host_icon.offset[2] = 10 + team_ui_portrait_offset_y

		self:_set_widget_dirty(default_static_widget)
		self:_set_widget_dirty(portrait_static_w)
		self:set_dirty()
	end
end

--- Same as UnitFrameUI.set_portrait, but we avoid using that so we can instead hook
--- UnitFrameUI set_portrait calls and cache results.
mod.set_portrait = function(unit_frame_ui, portrait_texture)
	local self = unit_frame_ui
	local widget = self:_widget_by_feature("default", "static")
	local widget_content = widget.content
	widget_content.character_portrait = portrait_texture

	self:_set_widget_dirty(widget)
	self._hb_mod_adjusted_portraits = false
end

--- Hide HUD hotkey callback.
mod.hide_hud = function()
	mod.keep_hud_hidden = not mod.keep_hud_hidden
end

--- EXECUTE ---
if not mod.persistent_storage.outline_ranges_backup then
	mod.persistent_storage.outline_ranges_backup = table.clone(OutlineSettings.ranges)
end

mod.reapply_pickup_ranges()
