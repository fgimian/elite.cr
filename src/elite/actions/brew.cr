require "json"

module Elite::Actions
  class Brew < Action
    ACTION_NAME = "brew"

    argument name : String
    argument state : String, choices: ["present", "latest", "absent"], default: "present"
    argument options : Array(String), optional: true

    def process
      # We"ll work in lowercase as brew is case insensitive
      name = @name.as(String).downcase
      options_a = @options ? @options.as(Array(String)) : [] of String

      # Obtain information about the requested package
      brew_info_proc = run(["brew", "info", "--json=v1", name],
                           capture_output: true, ignore_fail: true)

      # Check whether the package is installed and whether it is outdated
      unless brew_info_proc.exit_code == 0
        brew_installed = false
      else
        # Determine if the package is installed and/or outdated
        begin
          brew_info_multiple = JSON.parse(brew_info_proc.output.to_s)
          brew_info = brew_info_multiple[0]

          brew_installed = !brew_info["installed"].as_a.empty?
          brew_outdated = brew_info["outdated"].as_bool
        rescue JSON::ParseException | IndexError | KeyError
          raise ActionProcessingError.new("Unable to parse installed package information")
        end
      end

      # Install, upgrade or remove the package as requested
      case @state
      when "present"
        if brew_installed
          ok
        else
          run(["brew", "install"] + options_a + [name],
              fail_error: "Unable to install the requested package")
          changed
        end
      when "latest"
        if brew_installed && !brew_outdated
          ok
        elsif brew_installed && brew_outdated
          run(["brew", "upgrade"] + options_a + [name],
              fail_error: "Unable to upgrade the requested package")
          changed
        else
          run(["brew", "install"] + options_a + [name],
              fail_error: "Unable to install the requested package")
          changed
        end
      else # "absent"
        unless brew_installed
          ok
        else
          run(["brew", "remove"] + options_a + [name],
              fail_error: "Unable to remove the requested package")
          changed
        end
      end
    end
  end
end
