module ActiveAdminImportable
  module DSL
    def active_admin_importable(options = {}, &block)

      action_item :edit, :only => :index do
        link_to "Import #{active_admin_config.resource_name.to_s.pluralize}", :action => 'upload_csv'
      end

      collection_action :upload_csv do
        render options[:view].present? ? options[:view] : "admin/csv/upload_csv"
      end

      collection_action :import_csv, :method => :post do

        if params[:dump].nil? || params[:dump][:file].nil?
          flash[:alert] = "You should choose file for import"
          redirect_to action: :upload_csv and return
        end

        extension =
          case params[:dump][:file].content_type
            when 'text/csv'
              'csv'
            when 'application/json'
              'json'
            when 'text/xml'
              'xml'
            else
              params[:dump][:file].content_type
          end

        if options[:validate_extension].to_b
          unless extension.in? %w{csv}
            flash[:alert] = "#{extension} is not a valid extension. You can import file only with extension .csv"
            redirect_to action: :upload_csv and return
          end
        end

        role = resources_configuration[:self][:role]

        result_options = options.dup

        if params[:dump][:custom_options].present?
          custom_options = params[:dump][:custom_options].permit!.to_h.symbolize_keys
          result_options = options.merge(custom_options)
        end

        result_options = result_options.merge(:role=>role)

        errors = CsvDb.convert_save(active_admin_config.resource_class, params[:dump][:file], result_options, &block)

        if errors.present?
          flash[:error] = errors
          redirect_to action: :upload_csv
        else
          flash[:notice] = "#{active_admin_config.resource_name.to_s} imported successfully!"
          redirect_to :action => :index
        end
      end
    end
  end
end