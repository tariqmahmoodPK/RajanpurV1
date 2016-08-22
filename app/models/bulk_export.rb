class BulkExport < CouchRest::Model::Base
  use_database :bulk_export

  include PrimeroModel
  include Primero::CouchRestRailsBackward
  include Sunspot::Rails::Searchable

  PROCESSING = 'job.status.processing' #The job is still running
  TERMINATED = 'job.status.terminated' #The job terminated due to an error
  COMPLETE = 'job.status.complete'     #The job completed successfully
  ARCHIVED = 'job.status.archived'     #The job's files have been cleaned up

  EXPORT_DIR = File.join(Rails.root,'tmp','export')
  FileUtils.mkdir_p EXPORT_DIR

  ARCHIVE_CUTOFF = 30.days.ago

  property :status
  property :owned_by
  property :started_on, DateTime
  property :completed_on, DateTime

  property :format
  property :record_type
  property :model_range #This is a future thing. Currently the bulk is only invoked for :all
  property :filters #Filters as calculated from the params by the controllers
  property :order #Solr query order as calculated by the controllers
  property :query #Text search string
  property :match_criteria #Tracing Request match criteria #TODO: refactor for v1.3?
  property :custom_export_params #Used by the custom exports to select forms and fields
  property :permitted_property_keys

  property :file_name
  #TODO: Temporarily we are going to store INSECURELY the password.
  #      Going forward, a random password will be generated for each export at download time
  property :password

  design #Create the default all design view

  searchable do
    time :started_on
    time :completed_on
    string :status, as: 'status_sci'
    string :owned_by, as: 'owned_by_sci'
    string :format, as: 'format_sci'
  end
  Sunspot::Adapters::InstanceAdapter.register DocumentInstanceAccessor, self
  Sunspot::Adapters::DataAccessor.register DocumentDataAccessor, self

  def model_class
    @model_class ||= Record.model_from_name(self.record_type)
  end

  def exporter
    @exporter ||= Exporters::active_exporters_for_model(self.model_class)
    .select{|e| e.id == self.format.to_s}.first
  end

  def owner
    @owner ||= User.find_by_user_name(self.owned_by)
  end

  #Override accessors for values populated from the controller indifferent access
  def filters
    self['filters'].with_indifferent_access if self['filters'].present?
  end
  def order
    self['order'].with_indifferent_access if self['order'].present?
  end
  def match_criteria
    self['match_criteria'].with_indifferent_access if self['match_criteria'].present?
  end
  def custom_export_params
    self['custom_export_params'].with_indifferent_access if self['custom_export_params'].present?
  end

  #TODO: This is happening because bulk_export objects cannot be serialized.
  #      Revisit when upgrading to Rails 4.2
  #TODO: This is also happening because this logic is on the controller rather than the User object or Record class
  def permitted_properties=(permitted_properties)
    self.permitted_property_keys = properties_by_module_to_keys(permitted_properties)
  end

  def permitted_properties
    @permitted_properties ||= property_keys_by_module_to_properties(self.permitted_property_keys, model_class)
  end

  def mark_started
    self.status = PROCESSING
    self.started_on = DateTime.now
    #TODO: Log this
    self.save
  end

  def mark_completed
    self.status = COMPLETE
    self.completed_on = DateTime.now
    self.password = nil # TODO: yes yes, I know
    #TODO: Log this
    self.save
  end

  def archive
    self.status = ARCHIVED
    if self.stored_file_name.present? && File.exist?(self.stored_file_name)
      begin
        File.delete(self.stored_file_name)
      rescue
        Rails.logger.warn("Archiving #{self.stored_file_name}: File missing!")
      end
    end
  end

  def stored_file_name
    if self.file_name.present?
      #File.join(EXPORT_DIR,"#{self.file_name}.zip")
      File.join(EXPORT_DIR,"#{self.file_name}")
    end
  end

  def retrieve_and_export_records(exporter)
    #TODO: this is a good candidate for multithreading
    #TODO: Right now this is duplicated code with what appears in the record_actions controller concern

    pagination_ops = {:page => 1, :per_page => 500}
    #records = []
    begin
      search = self.model_class.list_records(
        self.filters, self.order, pagination_ops,
        self.owner.managed_user_names, self.query, self.match_criteria
      )
      results = search.results
      #records.concat(results)
      #yield(exporter, results)
      exporter.export(results, permitted_properties, owner, custom_export_params)
      #Set again the values of the pagination variable because the method modified the variable.
      pagination_ops[:page] = results.next_page
      pagination_ops[:per_page] = 500

    end until results.next_page.nil?
    #return records
  end

  def test_retrieve_and_export_records
    #TODO: this is a good candidate for multithreading
    #TODO: Right now this is duplicated code with what appears in the record_actions controller concern

    pagination_ops = {:page => 1, :per_page => 200}
    records = []
    begin
      search = self.model_class.list_records(
        self.filters, self.order, pagination_ops,
        self.owner.managed_user_names, self.query, self.match_criteria
      )
      results = search.results
      #records.concat(results)
      #yield(exporter, results)
      #Set again the values of the pagination variable because the method modified the variable.
      pagination_ops[:page] = results.next_page
      pagination_ops[:per_page] = 200

    end until results.next_page.nil?
    return records
  end

  def build_export_file(data)
    #TODO: This code is currently duplicated in the application controller
    ZipRuby::Archive.open(self.stored_file_name, ZipRuby::CREATE) do |ar|
      ar.add_or_replace_buffer self.file_name, data
      if self.password
        ar.encrypt self.password
      end
    end
  end

  def fetch_file ; end

  private

  def properties_by_module_to_keys(properties_by_module)
    property_keys = {}
    properties_by_module.each do |module_id, forms_hash|
      forms_keys = {}
      forms_hash.each do |form_name, fields_hash|
        forms_keys[form_name] = fields_hash.keys
      end
      property_keys[module_id] = forms_keys
    end
    return property_keys
  end

  def property_keys_by_module_to_properties(property_keys, model_class)
    model_properties = model_class.properties.reduce({}) do |acc, property|
      acc[property.name] = property ; acc
    end
    properties_by_module = {}
    property_keys.each do |module_id, forms_keys|
      forms_hash = {}
      forms_keys.each do |form_name, keys|
        properties_hash = keys.reduce({}) do |acc, key|
          acc[key] = model_properties[key] ; acc
        end
        forms_hash[form_name] = properties_hash
      end
      properties_by_module[module_id] = forms_hash
    end
    return properties_by_module
  end

end