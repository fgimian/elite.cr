require "json"

module Elite::Actions
  class Brew < Action
    ACTION_NAME = "brew"

    argument name : String
    argument state : Symbol, choices: [:present, :latest, :absent], default: :present
    argument options : Array(String), optional: true, default: [] of String

    def process
      # We"ll work in lowercase as brew is case insensitive
      # TODO: how can we do this more elegantly?  the type can be Nil or a String
      name = @name.to_s.downcase

      # Obtain information about the requested package
      brew_info_proc = run(
        ["brew", "info", "--json=v1", name], capture_output: true, ignore_fail: true
      )

      # Check whether the package is installed and whether it is outdated
      if brew_info_proc.exit_code
        brew_installed = false
      else
        # Determine if the package is installed and/or outdated
        begin
          brew_info_multiple = JSON.parse(brew_info_proc.output.to_s)
          brew_info = brew_info_multiple[0]

          brew_installed = !brew_info["installed"].as_a.empty?
          brew_outdated = brew_info["outdated"]
        # TODO: catch the appropriate exceptions here
        rescue
          raise ActionProcessingError.new("Unable to parse installed package information")
        end
      end

      # Install, upgrade or remove the package as requested
      if @state == :present
        if brew_installed
          ok
        else
          run(
            ["brew", "install"] + @options + [name],
            fail_error: "unable to install the requested package"
          )
          changed
        end
      elsif @state == :latest
        if brew_installed && !brew_outdated
          ok
        elsif brew_installed && brew_outdated
          run(
            ["brew", "upgrade"] + @options + [name],
            fail_error: "unable to upgrade the requested package"
          )
          changed
        else
          run(
            ["brew", "install"] + @options + [name],
            fail_error: "unable to install the requested package"
          )
          changed
        end
      elsif @state == :absent
        unless brew_installed
          ok
        else
          run(
            ["brew", "remove"] + @options + [name],
            fail_error: "unable to remove the requested package"
          )
          changed
        end
      end
    end
  end
end
