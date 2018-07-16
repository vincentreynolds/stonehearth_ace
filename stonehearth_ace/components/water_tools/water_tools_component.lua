local csg_lib = require 'lib.csg.csg_lib'
local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local Region3 = _radiant.csg.Region3
local log = radiant.log.create_logger('water_tools')

local WaterToolsComponent = class()

-- Closely mimics wet_stone_component.lua
function WaterToolsComponent:initialize()
	local json = radiant.entities.get_json(self)
	self._sv.enabled = false or json.enabled
	self._sv.type = json.type
	self._sv.on_command = json.on_command
	self._sv.off_command = json.off_command
	self._sv.rate = math.max(json and json.rate or 1, 0)
	self._sv.height = math.max(json and json.height or 1, 1) + 1
end

function WaterToolsComponent:post_activate()
	self:apply_settings(true, true)
	
	if self._sv.type == 'water_pump' then
		self._tick_listener = radiant.events.listen(stonehearth.hydrology, 'stonehearth:hydrology:tick', function()
			self:_on_tick()
		end)
	end
end

function WaterToolsComponent:apply_settings(enabled_changed, height_changed)
	if enabled_changed then
		-- swap commands
		local commands_component = self._entity:get_component('stonehearth:commands')
		if commands_component then
			if self._sv.enabled then
				commands_component:remove_command(self._sv.on_command)
				if not commands_component:has_command(self._sv.off_command) then
					commands_component:add_command(self._sv.off_command)
				end
			else
				commands_component:remove_command(self._sv.off_command)
				if not commands_component:has_command(self._sv.on_command) then
					commands_component:add_command(self._sv.on_command)
				end
			end
		end

		if self._sv.type == 'water_gate' then
			local new_collision_type
			if self._sv.enabled then
				new_collision_type = _radiant.om.RegionCollisionShape.PLATFORM
			else
				new_collision_type = _radiant.om.RegionCollisionShape.SOLID
			end

			self._entity:get_component('region_collision_shape'):set_region_collision_type(new_collision_type)
		end

		-- do anything else here like playing animations?
	end
end

function WaterToolsComponent:get_type()
	return self._sv.type
end

function WaterToolsComponent:get_enabled()
	return self._sv.enabled
end

function WaterToolsComponent:set_enabled(value)
	if self._sv.enabled ~= value then
		self._sv.enabled = value
		self.__saved_variables:mark_changed()

		self:apply_settings(true)

		radiant.events.trigger(radiant, 'stonehearth_ace:on_water_tools_enabled_changed', { entity = self._entity, enabled = value })
	end
end

function WaterToolsComponent:get_rate()
	return self._sv.rate
end

function WaterToolsComponent:set_rate(value)
	self._sv.rate = math.max(value, 0)
	self.__saved_variables:mark_changed()
end

function WaterToolsComponent:get_height()
	return self._sv.height
end

function WaterToolsComponent:set_height(value)
	if self._sv.height ~= value then
		local old_height = self._sv.height
		self._sv.height = math.max(value, 1) + 1
		self.__saved_variables:mark_changed()

		self:apply_settings(false, true)

		radiant.events.trigger(radiant, 'stonehearth_ace:on_water_tools_height_changed', { entity = self._entity, old_height = old_height })
	end
end

function WaterToolsComponent:destroy()
	if self._tick_listener then
		self._tick_listener:destroy()
		self._tick_listener = nil
	end
end

function WaterToolsComponent:_on_tick()
	if not self._sv.enabled or self._sv.rate <= 0 then
		log:error('water pump is disabled or has negative/zero rate')
		return
	end

	local location = radiant.entities.get_world_grid_location(self._entity)
	if not location then
		log:error('water pump entity has invalid location')
		return
	end
   
	local water_body = self:_get_water_body(location)

	if water_body then
		-- first we need to identify the destination for the water
		local output_location = location + Point3(0, self._sv.height, 0)

		-- then we need to remove water from where the entity is
		local volume, info = stonehearth.hydrology:remove_water(self._sv.rate, location, water_body)

		-- then we need to try adding the same amount of water that was removed to a position above the entity
		local out_volume, info = stonehearth.hydrology:add_water(volume, output_location)

		log:error('water pump removed %d water and added %d water', volume, out_volume)

		-- finally, if we output less volume than we input, output the difference back at the source location
		if out_volume < volume then
			stonehearth.hydrology:add_water(volume - out_volume, location, water_body)
		end
	end
end

function WaterToolsComponent:_get_water_body(location)
	if not location then
		return nil
	end

	local entities = radiant.terrain.get_entities_at_point(location)

	for id, entity in pairs(entities) do
		local water_component = entity:get_component('stonehearth:water')
		if water_component then
			return entity
		end
	end

	return nil
end

return WaterToolsComponent