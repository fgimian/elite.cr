module Elite::Actions
  class Cask < Action
    ACTION_NAME = "cask"

    argument name : String
    argument state : String, choices: ["present", "latest", "absent"], default: "present"
    argument options : Array(String), optional: true

    def process
      name = @name.as(String)
      name_short = name.split("/")[-1]
      options_a = @options ? @options.as(Array(String)) : [] of String

      # Obtain information about installed packages
      cask_list_proc = run(%w(brew cask list), capture_output: true, ignore_fail: true)

      # Check whether the package is installed using only its short name
      # (e.g. fgimian/general/cog will check for a cask called cog)
      unless cask_list_proc.exit_code == 0
        cask_installed = false
      else
        cask_list = cask_list_proc.output.chomp.split("\n")
        cask_installed = cask_list.includes?(name_short)
      end

      # Install or remove the package as requested
      case @state
      when "present"
        if cask_installed
          ok
        else
          run(["brew", "cask", "install"] + options_a + [name],
              fail_error="unable to install the requested package")
          changed
        end
      when "latest"
        if cask_installed
          # Determine if the installed package is outdated
          cask_outdated = false

          cask_outdated_proc = run(%w(brew cask outdated),
                                   capture_output: true, ignore_fail: true)
          if cask_outdated_proc.exit_code == 0
            cask_list = cask_outdated_proc.output.chomp.split("\n")
            cask_outdated = cask_list.includes?(name_short)
          end

          unless cask_outdated
            ok
          else
            run(["brew", "cask", "upgrade"] + options_a + [name],
                fail_error: "unable to upgrade the requested package")
            changed
          end
        else
          run(["brew", "cask", "install"] + options_a + [name],
              fail_error: "unable to install the requested package")
          changed
        end
      else # "absent"
        unless cask_installed
          ok
        else
          run(["brew", "cask", "remove"] + options_a + [name],
              fail_error: "unable to remove the requested package")
          changed
        end
      end
    end
  end
end
