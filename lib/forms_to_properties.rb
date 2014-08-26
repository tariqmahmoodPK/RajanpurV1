module FormToPropertiesConverter
  def properties_hash_for(form_section)
    include_field = lambda do |field|
      field.visible
    end

    form_section.form_group_name

    form_section.fields.select(&include_field).inject({}) do |form_acc, f|
      form_acc.merge(properties_for_field(f))
    end
  end

  private

  def create_embeddable_model(subform)
    properties_hash = properties_hash_for(subform)

    Class.new do
      include CouchRest::Model::Embeddable

      properties_hash.each do |name,options|
        property name, options
      end
    end
  end

  def properties_for_field(field)
    base_options = {
      :read_only => !field.editable,
      :allow_blank => true
    }

    case field.type
    when "subform"
      subform = FormSection.get(field.subform_section_id)

      { field.name => {
          :type => create_embeddable_model(subform),
          :array => true
        }.update(base_options)
      }
    # TODO: add validation for select_box and radio_button options
    when "select_box", "textarea", "text_field", "radio_button", "check_boxes", "numeric_field", "date_field", "tick_box"
      type_map = {
        :select_box => String,
        :textarea => String,
        :text_field => String,
        :radio_button => String,
        :check_boxes => String,
        :numeric_field => Integer,
        :date_field => Date,
        :tick_box => TrueClass,
      }

      { field.name => {
          :type => type_map[field.type.to_sym]
        }.update(base_options)
      }
    when "date_range"
      { 
        "#{field.name}_from" => { :type => Date }.update(base_options),
        "#{field.name}_to" => {:type => Date}.update(base_options),
        "#{field.name}_date_or_date_range" => {:type => String}.update(base_options),
        field.name => {:type => Date}.update(base_options),
      }
    when 'separator', 'photo_upload_box', 'audio_upload_box', 'document_upload_box'
      {}
    else
      raise "Unknown field type #{field.type}"
    end
  end
end

