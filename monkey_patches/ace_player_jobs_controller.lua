--[[
   the goal is to allow for population-specific jobs for citizens of different populations in the same kingdom
   e.g., an orc footman may have different skills/traits than an ascendancy footman
   also then allows for promotion to kingdom-specific classes (e.g., goblin shaman in a non-goblin kingdom)
]]

local PlayerJobsController = require 'stonehearth.services.server.job.player_jobs_controller'
local AcePlayerJobsController = class()

local log = radiant.log.create_logger('player_jobs_controller')

-- For a given player, keep a table of job_info_controllers for that player

AcePlayerJobsController._ace_old_reset = PlayerJobsController.reset
function AcePlayerJobsController:reset()
   self:_ace_old_reset()
   
   -- create all job info controllers so the client is aware of all possible recipes for your faction's crafters
   -- even if you haven't promoted your hearthlings to those jobs yet
   local pop = stonehearth.population:get_population(self._sv.player_id)
   local job_index = pop:get_job_index()
   local jobs = job_index and radiant.resources.load_json(job_index)
   log:debug('ensuring all job controllers found in "%s"...', tostring(job_index))
   if jobs then
      for job_key, _ in pairs(jobs.jobs) do
         log:debug('ensuring "%s"', job_key)
         self:_ensure_job_id(job_key)
      end
   end
end

function AcePlayerJobsController:request_craft_product(product_uri, amount, building)
   for _, job_info in pairs(self._sv.jobs) do
      local order = job_info:queue_order_if_possible(product_uri, amount, building)
      if order then
         -- it's just true if the order didn't need to be created
         -- otherwise it returns the actual order
         if order ~= true then
            return order
         else
            return
         end
      end
   end
end

function AcePlayerJobsController:remove_craft_orders_for_building(bid)
   for _, job_info in pairs(self._sv.jobs) do
      job_info:remove_craft_orders_for_building(bid)
   end
end

function AcePlayerJobsController:_ensure_job_id(id)
   self:_ensure_job_index()

   if self._job_index and self._job_index.jobs and self._job_index.jobs[id] then
      local info = self._job_index.jobs[id]
      self._sv.jobs[id] = radiant.create_controller('stonehearth:job_info_controller', info, self._sv.player_id)
      self.__saved_variables:mark_changed()
   end
end

--If we have kingdom data for this job, use that, instead of the default
function AcePlayerJobsController:_ensure_job_index(population_override)
   if not self._job_index then
      -- first load the general population data
      local pop = stonehearth.population:get_population(self._sv.player_id)
      local job_index_location = 'stonehearth:jobs:index'
      if pop then
         job_index_location = pop:get_job_index()
      end

      local job_index = radiant.resources.load_json(job_index_location)
      self._job_index = job_index
   end
   
   if not self._population_job_indexes then
      self._population_job_indexes = {}
   end
   if population_override and not self._population_job_indexes[population_override] then
      self._population_job_indexes[population_override] = {}
      -- then, if a population was specified, load that
      local pop = stonehearth.population:get_population(self._sv.player_id)
      if pop then
         local job_index_location = pop:get_job_index(population_override)
         -- only proceed if it's actually a different job index
         if job_index_location and job_index_location ~= pop:get_job_index() then
            local job_index = radiant.resources.load_json(job_index_location)
            self._population_job_indexes[population_override] = job_index

            -- and mix it into the regular job index
            local new_job_index = {}
            -- make sure we override any duplicate entries with our population's entry for that job
            -- create a new table since the original was the directly-loaded-from-json version
            for k, v in pairs(job_index) do
               new_job_index[k] = v
            end
            for k, v in pairs(self._job_index) do
               -- override any existing entries with these ones
               new_job_index[k] = v
            end

            self._job_index = new_job_index
         end
      end
   end
end

--If we have kingdom data for this job, use that, instead of the default
function AcePlayerJobsController:get_job_description(job_uri, population_override)
   self:_ensure_job_index(population_override)

   if self._job_index and self._job_index.jobs and self._job_index.jobs[job_uri] then
      return self._job_index.jobs[job_uri].description
   else
      return job_uri
   end
end

return AcePlayerJobsController
