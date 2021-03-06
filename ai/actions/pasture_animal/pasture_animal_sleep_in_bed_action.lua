local animal_filters = require 'ai.filters.animal_filters'
local PastureAnimalSleepInBed = radiant.class()

PastureAnimalSleepInBed.name = 'sleep in pasture bed'
PastureAnimalSleepInBed.does = 'stonehearth_ace:pasture_animal_sleep_in_bed'
PastureAnimalSleepInBed.args = {}
PastureAnimalSleepInBed.priority = 0

local function _pet_bed_rating_filter(entity)
   local pasture_animal_location = radiant.entities.get_world_grid_location(entity)
   return function(bed)
      local bed_location = radiant.entities.get_world_grid_location(bed)
      return -pasture_animal_location:distance_to_squared(bed_location)
   end
end

local ai = stonehearth.ai
return ai:create_compound_action(PastureAnimalSleepInBed)
         :execute('stonehearth:find_best_reachable_entity_by_type', {
            filter_fn = ai.CALL(animal_filters.make_available_pet_bed_filter, ai.ENTITY),
            rating_fn = ai.CALL(_pet_bed_rating_filter, ai.ENTITY),
            description = 'find best pet bed',
         })
         :execute('stonehearth:find_path_to_reachable_entity', {
            destination = ai.PREV.item
         })
         :execute('stonehearth:follow_path', { path = ai.PREV.path })
         :execute('stonehearth:reserve_entity', { entity = ai.BACK(3).item })
         :execute('stonehearth_ace:pasture_animal_sleep_in_bed_adjacent', { bed = ai.BACK(4).item })
