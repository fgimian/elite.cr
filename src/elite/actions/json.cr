require "json"

module Elite::Actions
  Elite.data JSONData, path : String

  # TODO: Consider a better name?
  class JSON2 < Action
    ACTION_NAME = "json"

    argument path : String
    argument values : JSON::Any
    argument indent : Int32, default: 2
    file_attribute_arguments

    def process
      # Ensure that home directories are taken into account
      path = ::File.expand_path(@path.as(String))

      indent = @indent.as(Int32)
      values = @values.as(JSON::Any)

      # Load the JSON or create a fresh data structure if it doesn"t exist
      begin
        json = ::File.open(path, "r") do |file|
          JSON.parse(file)
        end
      rescue Errno
        json = JSON::Any.new({} of String => JSON::Any)
      rescue JSON::ParseException
        raise ActionProcessingError.new("An invalid JSON file already exists")
      end

      # Check if the current JSON is the same as the values provided
      if Elite::Utils::JSON2.deep_equal?(values, json)
        changes_made = set_file_attributes(path)
        data = JSONData.new(path: path)
        return changes_made ? changed(data) : ok(data)
      end

      # Update the JSON with the values provided
      updated_json = Elite::Utils::JSON2.deep_merge(values, json)

      # Write the updated JSON file
      begin
        ::File.open(path, "w") do |file|
          updated_json.to_pretty_json(file, indent: " " * indent)
          file.puts
        end

        set_file_attributes(path)
        changed(JSONData.new(path: path))
      rescue Errno
        raise ActionProcessingError.new("Unable to update the requested JSON file")
      end
    end
  end
end
