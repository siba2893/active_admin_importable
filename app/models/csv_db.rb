require 'csv'
class CsvDb
  attr_accessor :error

  class << self
    def char_code(c)
      c.respond_to?(:ord) ? c.ord : c
    end

    def has_bom(file_data)
      char_code(file_data[0]) == 0xEF &&
          char_code(file_data[1]) == 0xBB &&
          char_code(file_data[2]) == 0xBF
    end

    # @return [String]
    def remove_bom(file_data)
      has_bom(file_data) ? file_data[3..-1] : file_data
    end

    def convert_save(target_model, csv_data, options, &block)
      csv_data = remove_bom(csv_data.read)
      csv_data = csv_data.force_encoding('utf-8') if csv_data.respond_to?(:force_encoding)
      parser_class = (RUBY_VERSION=='1.8.7') ? FasterCSV : CSV
      errors = nil

      begin
        target_model.transaction do
          parser_class.parse(csv_data, :headers => true, :header_converters => :symbol, col_sep: options[:col_sep] || ',') do |row|
            append_row(target_model, row, options, &block)
          end
        end
      rescue => e
        errors = e.message
      ensure
        if options[:reset_pk_sequence]
          target_model.connection.reset_pk_sequence! target_model.table_name
        end
      end

      errors
    end

    def append_row(target_model, row, options, &block)
      data = row.to_hash
      if data.present?
        if (block_given?)
          block.call(target_model, data)
        else

          options[:before_save].call(data) if options[:before_save]

          role = options[:role] || :default

          if new_headers = options[:replace_headers]
            data = data.transform_keys { |k| new_headers[k].present? ? new_headers[k] : k }
          end

          if options[:handle_create_or_update].present?
            options[:handle_create_or_update].call(target_model, data, key_field)
          else
            if key_field = options[:find_by]
              create_or_update! target_model, data, key_field, options
            else
              if role == :default
                target_model.create!(data)
              else
                target_model.create!(data, :as => role) # Old version ActiveRecord
              end
            end
          end
        end
      end
    end

    def create_or_update!(target_model, values, key_field, options)
      key_value = values[key_field.to_sym]
      scope = target_model.where(key_field => key_value)
      if obj = scope.first

        values[:id] = obj.id
        
        if options[:ignore_on_update].present?
          options[:ignore_on_update].each {|k| values.delete(k) }
        end

        obj.update_attributes!(values)
      else
        scope.create!(values)
      end
    end
  end
end