#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.



class PulpTaskStatus < TaskStatus

  def self.wait_for_tasks async_tasks
    async_tasks = async_tasks.collect do |t|
      PulpTaskStatus.using_pulp_task(t)
    end

    while any_task_running(async_tasks)
      sleep 1
    end

    async_tasks
  end


  def self.using_pulp_task(sync)
    self.new(
        :uuid => sync[:id],
        :state => sync[:state],
        :start_time => sync[:start_time],
        :finish_time => sync[:finish_time],
        :progress => sync[:progress],
        :result => sync[:result].nil? ? {:errors => [sync[:exception], sync[:traceback]]}.to_json : sync[:result]
    ) { |t| yield t if block_given? }
  end

  def refresh
    PulpTaskStatus.refresh(self)
  end

  def error
    ActiveSupport::JSON.decode(self.result)["errors"][0] if self.error? 
  end

  def self.refresh task_status
    pulp_task = Pulp::Task.find(task_status.uuid)
    task_status.attributes = {
        :state => pulp_task[:state],
        :finish_time => pulp_task[:finish_time],
        :progress => pulp_task[:progress],
        :result => pulp_task[:result].nil? ? {:errors => [pulp_task[:exception], pulp_task[:traceback]]}.to_json : pulp_task[:result]
    }
    task_status.save! if not task_status.new_record?
    task_status
  end

  protected

  def self.any_task_running(async_tasks)
    for t in async_tasks
      t.refresh
      sleep 0.5 # do not overload backend engines
      if not t.finished?
        return true
      elsif t.error?
        raise RuntimeError, t.error
      end
    end
    return false
  end


end
