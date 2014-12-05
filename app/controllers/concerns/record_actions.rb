module RecordActions
  extend ActiveSupport::Concern

  include ImportActions
  include ExportActions

  included do
    skip_before_filter :verify_authenticity_token
    skip_before_filter :check_authentication, :only => [:reindex]

    before_filter :load_record, :except => [:new, :create, :index, :reindex]
    before_filter :current_user, :except => [:reindex]
    before_filter :get_lookups, :only => [:new, :edit, :index]
    before_filter :current_modules, :only => [:show, :index]
    before_filter :is_manager, :only => [:index]
    before_filter :is_cp, :only => [:index]
    before_filter :is_gbv, :only => [:index]
    before_filter :is_mrm, :only => [:index]
  end

  def list_variable_name
    model_class.name.pluralize.underscore
  end

  # GET /{record type}
  # GET /{record type}.xml
  def index
    authorize! :index, model_class

    @page_name = t("home.view_records")
    @aside = 'shared/sidebar_links'
    @associated_users = current_user.managed_user_names
    @records, @total_records = retrieve_records_and_total(record_filter(filter))

    # Alias @records to the record-specific name since ERB templates use that
    # right now
    # TODO: change the ERB templates to just accept the @records instance
    # variable
    instance_variable_set("@#{list_variable_name}", @records)

    @per_page = per_page

    @highlighted_fields = []

    respond_to do |format|
      format.html
      format.xml { render :xml => @records }
      unless params[:format].nil?
        if @records.empty?
          flash[:notice] = t('exports.no_records')
          redirect_to :action => :index and return
        end
      end
      respond_to_export format, @records
    end
  end

  # GET /{record type}/1
  # GET /{record type}/1.xml
  def show
    if @record.nil?
      redirect_on_not_found
      return
    end

    authorize! :read, @record
    @page_name = t "#{model_class.locale_prefix}.view", :short_id => @record.short_id
    @body_class = 'profile-page'
    @duplicates = model_class.duplicates_of(params[:id])
    @form_sections = @record.allowed_formsections(current_user)

    respond_to do |format|
      format.html
      format.xml { render :xml => @record }

      respond_to_export format, [ @record ]
    end
  end

  def new
    authorize! :create, model_class

    # Ugh...why did we make two separate locale namespaces for each record type (cases/children have four)?
    @page_name = t("#{model_class.locale_prefix.pluralize}.register_new_#{model_class.locale_prefix}")

    @record = make_new_record
    # TODO: make the ERB templates use @record
    instance_variable_set("@#{model_class.name.underscore}", @record)

    @form_sections = @record.allowed_formsections(current_user)

    respond_to do |format|
      format.html
      format.xml { render :xml => @record }
    end
  end

  def create
    authorize! :create, model_class
    reindex_hash record_params
    @record = create_or_update_record(params[:id])
    initialize_created_record(@record)
    respond_to do |format|
      @form_sections = @record.allowed_formsections(current_user)
      if @record.save
        flash[:notice] = t("#{model_class.locale_prefix}.messages.creation_success", record_id: @record.short_id)
        format.html { redirect_after_update }
        format.xml { render :xml => @record, :status => :created, :location => @record }
      else
        format.html {
          render :action => "new"
        }
        format.xml { render :xml => @record.errors, :status => :unprocessable_entity }
      end
    end
  end

  # GET /{record type}/1/edit
  def edit
    if @record.nil?
      redirect_on_not_found
      return
    end

    authorize! :update, @record

    @form_sections = @record.allowed_formsections(current_user)
    @page_name = t("#{model_class.locale_prefix}.edit")
  end

  def update
    respond_to do |format|
      format.html do
        create_or_update_record(params[:id])

        if @record.save
          flash[:notice] = I18n.t("#{model_class.locale_prefix}.messages.update_success", record_id: @record.short_id)
          if params[:redirect_url]
            redirect_to "#{params[:redirect_url]}?follow=true"
          else
            redirect_after_update
          end
        else
          render :action => "edit"
        end
      end

      format.xml do
        @record = update_record_from(params[:id])
        if @record.save
          head :ok
        else
          render :xml => @record.errors, :status => :unprocessable_entity
        end
      end
    end
  end

  def destroy
    authorize! :destroy, @record
    @record.destroy

    respond_to do |format|
      format.html { redirect_after_deletion }
      format.xml { head :ok }
    end
  end

  def redirect_on_not_found
    respond_to do |format|
      format.html do
        flash[:error] = "#{model_class.name.underscore.capitalize.sub('_', ' ')} with the given id is not found"
        redirect_to :action => :index
        return
      end
    end
  end

  def retrieve_records_and_total(filter)
    if params["page"] == "all"
      pagination_ops = {:page => 1, :per_page => 100}
      records = []
      begin
        search = model_class.list_records filter, order, pagination_ops, users_filter, params[:query], @match_criteria
        results = search.results
        records.concat(results)
        #Set again the values of the pagination variable because the method modified the variable.
        pagination_ops[:page] = results.next_page
        pagination_ops[:per_page] = 100
      end until results.next_page.nil?
      total_records = search.total
    else
      search = model_class.list_records filter, order, pagination, users_filter, params[:query], @match_criteria
      records = search.results
      total_records = search.total
    end
    [records, total_records]
  end

  #TODO - Primero - Refactor needed.  Determine more elegant way to load the lookups.
  def get_lookups
    @lookups = Lookup.all
  end

  # This is to ensure that if a hash has numeric keys, then the keys are sequential
  # This cleans up instances where multiple forms are added, then 1 or more forms in the middle are removed
  def reindex_hash(a_hash)
    a_hash.each do |key, value|
      if value.is_a?(Hash) and value.present?
        #if this is a hash with numeric keys, do the re-index, else keep searching
        if value.keys[0].is_number?
          new_hash = {}
          count = 0
          value.each do |k, v|
            new_hash[count.to_s] = v
            count += 1
          end
          value.replace(new_hash)
        else
          reindex_hash(value)
        end
      end
    end
  end

  def exported_properties
    model_class.properties
  end

  def current_modules
    record_type = model_class.parent_form
    @current_modules ||= current_user.modules.select{|m| m.associated_record_types.include? record_type}
  end

  def is_manager
    @is_manager ||= @current_user.is_manager?
  end

  def is_cp
    @is_cp ||= @current_user.has_module?(PrimeroModule::CP)
  end

  def is_gbv
    @is_gbv ||= @current_user.has_module?(PrimeroModule::GBV)
  end

  def is_mrm
    @is_mrm ||= @current_user.has_module?(PrimeroModule::MRM)
  end

  def record_params
    param_root = model_class.name.underscore
    params[param_root] || {}
  end

  # All the stuff that isn't properties that should be allowed
  def extra_permitted_parameters
    ['base_revision', 'unique_identifier']
  end

  # Filters out any unallowed parameters for a record and the current user
  def filter_params(record)
    permitted_keys = record.permitted_property_names(current_user) + extra_permitted_parameters
    record_params.select {|k,v| permitted_keys.include?(k) }
  end

  def record_short_id
    record_params.try(:fetch, :short_id, nil) || record_params.try(:fetch, :unique_identifier, nil).try(:last, 7)
  end

  def load_record
    if params[:id].present?
      @record = model_class.get(params[:id])
    end

    # Alias the record to a more specific name since the record controllers
    # already use it
    instance_variable_set("@#{model_class.name.underscore}", @record)
  end

  private 

  def create_or_update_record(id)
    @record = model_class.by_short_id(:key => record_short_id).first if record_params[:unique_identifier]

    if @record.nil?
      @record = model_class.new_with_user_name(current_user, record_params)
    else
      @record = update_record_from(id)
    end

    instance_variable_set("@#{model_class.name.underscore}", @record)
  end

  def update_record_from(id)
    authorize! :update, @record

    reindex_hash record_params
    update_record_with_attachments(@record)
  end
end
