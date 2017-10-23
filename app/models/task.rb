class Task

  attr_accessor :parent_case, :priority, :case_id

  def self.from_case(records)
    records = [records] unless records.is_a?(Array)
    tasks = []
    records.each do |record|
      if AssesmentTask.has_task?(record)
        tasks << AssesmentTask.new(record)
      end
      if CasePlanTask.has_task?(record)
        tasks << CasePlanTask.new(record)
      end
      if record.try(:followup_subform_section).present?
        record.followup_subform_section.each do |followup|
          if FollowUpTask.has_task?(followup)
            tasks << FollowUpTask.new(record, followup)
          end
        end
      end
      if record.try(:services_section).present?
        record.services_section.each do |service|
          if ServiceTask.has_task?(service)
            tasks << ServiceTask.new(record, service)
          end
        end
      end
    end
    tasks.sort_by! &:due_date
  end

  def initialize(record)
    self.parent_case = record
    self.priority = record.try(:risk_level)
    self.case_id = record.case_id_display
  end

  def type
    self.class.name[0..-5].underscore
  end

  def overdue?
    self.due_date < Date.today
  end

  def upcoming_soon?
    !self.overdue && self.due_date <= 7.days.from_now
  end

end

class AssesmentTask < Task
  def self.has_task?(record)
    record.try(:assessment_due_date).present? &&
    !record.try(:assessment_requested_on).present?
  end

  def due_date
    self.parent_case.assessment_due_date
  end
end

class CasePlanTask < Task
  def self.has_task?(record)
    record.try(:case_plan_due_date).present? &&
    !record.try(:date_case_plan).present?
  end

  def due_date
    self.parent_case.case_plan_due_date
  end
end

class FollowUpTask < Task
  attr_accessor :followup

  def self.has_task?(followup)
    followup.try(:followup_needed_by_date).present? &&
    !followup.try(:followup_date).present?
  end

  def initialize(record, followup)
    super(record)
    self.followup = followup
  end

  def due_date
    self.followup.followup_needed_by_date
  end
end

class ServiceTask < Task
  attr_accessor :service

  def self.has_task?(service)
    #TODO: or should use service.try(:service_implemented) == Child::SERVICE_NOT_IMPLEMENTED
    service.try(:service_appointment_date).present? &&
    !service.try(:service_implemented_day_time).present?
  end

  def initialize(record, service)
    super(record)
    self.service = service
  end

  def due_date
    self.service.service_appointment_date
  end
end
