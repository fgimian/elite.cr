module Elite::Actions
  class Tap < Action
    ACTION_NAME = "tap"

    argument name : String
    argument state : String, choices: ["present", "absent"], default: "present"
    argument url : String, optional: true

    def process
      # We"ll work in lowercase as brew is case insensitive
      name = @name.as(String).downcase

      # Prepare the URL if provided options
      url_a = @url ? [@url.as(String)] : [] of String

      # Obtain information about installed taps
      tap_list_proc = run(%w(brew tap), capture_output: true, ignore_fail: true)

      # Check whether the package is installed
      if tap_list_proc.exit_code == 0
        tap_list = tap_list_proc.output.chomp.split("\n")
        tapped = tap_list.includes?(name)
      else
        tapped = false
      end

      # Install or remove the package as requested
      case @state
      when "present"
        if tapped
          ok
        else
          run(["brew", "tap"] + [name] + url_a,
              fail_error: "unable to tap the requested repository")
          changed
        end
      else # "absent"
        if tapped
          run(["brew", "untap", name],
              fail_error: "unable to untap the requested repository")
          changed
        else
          ok
        end
      end
    end
  end
end
