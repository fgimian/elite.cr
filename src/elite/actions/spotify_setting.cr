module Elite::Actions
  Elite.data SpotifyData, path : String

  class SpotifySetting < Action
    ACTION_NAME = "spotify_setting"

    alias SpotifyValue = String | Bool | Int32

    argument username : String, optional: true
    argument setting : String
    argument value : SpotifyValue
    file_attribute_arguments

    def process
      # Determine the path of the Spotify prefs file
      if username = @username
        path = "~/Library/Application Support/Spotify/Users/#{username}-user/prefs"
      else
        path = "~/Library/Application Support/Spotify/prefs"
      end

      path = File.expand_path(path)
      setting = @setting.as(String)
      value = @value.as(SpotifyValue)

      # Load the Spotify settings or create a fresh data structure if it doesn"t exist
      settings = {} of String => String

      begin
        File.open(path) do |file|
          file.each_line do |config_setting_line|
            config_setting, config_value = config_setting_line.rstrip.split("=", 2)
            settings[config_setting] = config_value
          end
        end
      rescue IndexError
        raise ActionProcessingError.new("Unable to parse existing Spotify configuration")
      rescue Errno
      end

      # Check if the provided setting and value is the same as what"s in the config file
      if settings.has_key?(setting) && settings[setting] == value.inspect
        changes_made = set_file_attributes(path)
        data = SpotifyData.new(path: path)
        return changes_made ? changed(data) : ok(data)
      end

      # Update the config with the setting and value provided
      settings[setting] = value.inspect

      # Write the updated Spotify config
      begin
        File.open(path, "w") do |file|
          settings.each do |current_setting, current_value|
            file.puts "#{current_setting}=#{current_value}"
          end
        end

        set_file_attributes(path)
        changed(SpotifyData.new(path: path))
      rescue Errno
        raise ActionProcessingError.new("Unable to update the Spotify config file")
      end
    end
  end
end
