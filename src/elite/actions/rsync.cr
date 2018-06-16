require "json"

module Elite::Actions
  class Rsync < Action
    ACTION_NAME = "rsync"

    argument path : String
    argument source : String
    argument executable : String, optional: true
    argument archive : Bool, default: true
    argument options : Array(String), optional: true

    def process
      # Ensure that home directories are taken into account
      path = File.expand_path(@path.as(String))
      source = File.expand_path(@source.as(String))

      # Determine the rsync executable
      unless @executable
        executable = Process.find_executable("rsync")
        unless executable
          raise ActionProcessingError.new("Unable to find rsync executable to use")
        end
      else
        executable = @executable.as(String)
      end

      # Create a list to store our rsync options
      options_a = [] of String
      options_a << "--archive" if @archive

      # Add any additional user provided options
      options_a.concat(@options ? @options.as(Array(String)) : [] of String)

      # The output we want from rsync is a series of JSON hashes containing the operation
      # nd filename of each affected file
      options_a << %(--out-format=  {"operation": "%o", "filename": "%n"},)

      # Run rsync to sync the files requested
      rsync_proc = run(
        [executable] + options_a + [source, path], capture_output: true,
        fail_error: "rsync failed to sync the requested source to path"
      )

      # Obtain rsync output and check to see if any changes were made
      rsync_output = rsync_proc.output.chomp
      return ok if rsync_output == ""

      # The JSON output will be an array of hashes, so we must surround the individal
      # items with the [] list brackets and remove the last trailing comma before loading
      begin
        changes_json = JSON.parse("[\n" + rsync_output.chomp(',') + "\n]")
      rescue JSON::ParseException
        raise ActionProcessingError.new("Unable to parse rsync change information")
      end

      changes = changes_json.as_a.map do |d|
        {operation: d["operation"].as_s, filename: d["filename"].as_s}
      end

      # Changes were found and must be reported to the user
      changed(changes: changes)
    end
  end
end
