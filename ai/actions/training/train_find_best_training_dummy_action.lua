local Point3 = _radiant.csg.Point3
local FindBestTrainingDummy = class()

FindBestTrainingDummy.name = 'train'
FindBestTrainingDummy.status_text_key = 'stonehearth_ace:ai.actions.status_text.train'
FindBestTrainingDummy.does = 'stonehearth_ace:find_training_dummy'
FindBestTrainingDummy.args = {}
FindBestTrainingDummy.priority = 0.5

function find_training_dummy(entity)
   local player_id = radiant.entities.get_work_player_id(entity)
   local job_comp = entity:get_component('stonehearth:job')
   local job_uri = job_comp:get_job_uri()
   local job_level = job_comp:get_current_job_level()
   
   return stonehearth.ai:filter_from_key('stonehearth_ace:training_dummy:'..job_uri..job_level, player_id,
		function(target)
			if player_id == target:get_player_id() then
            local training_dummy = target:get_component('stonehearth_ace:training_dummy')
            local level = training_dummy and training_dummy:can_train_entity_level(job_uri)
            return level and level >= job_level
			end
			return false
		end)
end

function _should_abort(source, training_enabled)
   return not training_enabled
end

local ai = stonehearth.ai
return ai:create_compound_action(FindBestTrainingDummy)
         :execute('stonehearth:abort_on_event_triggered', {
            source = ai.ENTITY,
            event_name = 'stonehearth:work_order:build:work_player_id_changed',
         })
         :execute('stonehearth:find_best_reachable_entity_by_type', 
               { filter_fn = ai.CALL(find_training_dummy, ai.ENTITY)})
         :set_think_output({dummy = ai.PREV.item})
