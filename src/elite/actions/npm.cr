module Elite::Actions
  class Npm < Action
    ACTION_NAME = "npm"

    argument name : String
    argument version : String, optional: true
    argument state : String, choices: ["present", "latest", "absent"], default: "present"
    argument path : String, optional: true
    argument mode : String, choices: ["local", "global"], default: "global"
    argument executable : String, optional: true
    argument options : Array(String), optional: true

    def validate_arguments
      if @mode == "global" && @path
        raise ActionProcessingError.new(
          %(You cannot specify the "path" parameter when "mode" is set to "global")
        )
      end

      if @mode == "local" && !@path
        raise ActionProcessingError.new(
          %(You must specify the "path" parameter when "mode" is set to "local")
        )
      end

      if @state == "latest" && @version
        raise ActionProcessingError.new(
          %(You may not request "state" to be "latest" and provide a "version" argument")
        )
      end
    end

    def process
      # Determine the npm executable
      unless @executable
        executable = Process.find_executable("npm")
        unless executable
          raise ActionProcessingError.new("Unable to determine npm executable to use")
        end
      else
        executable = @executable.as(String)
      end

      # Build options relating to where the package will be installed
      location_options = [] of String
      location_options << "--global" if @mode == "global"
      location_options.concat(["--prefix", @path.as(String)]) if @path

      # We"ll work in lowercase as npm is case insensitive
      name = @name.as(String).downcase

      # Obtain a list of the requested package
      npm_list_proc = run([executable, "list", "--json", "--depth 0"] + location_options + [name],
                          capture_output: true, ignore_fail: true)

      # Check whether the package is installed and whether it is outdated
      unless npm_list_proc.exit_code == 0
        npm_installed = false
      else
        # Determine if the package is installed and/or outdated
        begin
          npm_list_multiple = JSON.parse(npm_list_proc.output)
          npm_list = {} of String => String
          npm_list_multiple["dependencies"].as_h.each do |p, i|
            npm_name = p.downcase
            npm_version = i["version"].as_s
            npm_list[npm_name] = npm_version
          end

          npm_installed = npm_list.has_key?(name)

          if npm_installed
            npm_view_proc = run([executable, "view", "--json", name],
                                capture_output: true, ignore_fail: true )

            npm_view = JSON.parse(npm_view_proc.output)
            npm_version = npm_list[name]
            npm_outdated = npm_version != npm_view["version"].as_s
          end
        rescue JSON::ParseException | IndexError | KeyError
          raise ActionProcessingError.new("Unable to parse package information")
        end
      end

      # Prepare any user provided options
      options_a = @options.nil? ? [] of String : @options.as(Array(String))

      # Install, upgrade or remove the package as requested
      case @state
      when "present"
        if @version
          if npm_installed && @version == npm_version
            ok
          elsif npm_installed
            run([executable, "install"] + location_options + options_a + ["#{name}@#{@version}"],
                fail_error: "unable to reinstall the requested package version")
            changed
          else
            run([executable, "install"] + location_options + options_a +
                ["#{name}@#{@version}"],
                fail_error: "unable to install the requested package version")
            changed
          end
        else
          if npm_installed
            ok
          else
            run([executable, "install"] + location_options + options_a + [name],
                fail_error: "Unable to install the requested package")
            changed
          end
        end
      when "latest"
        if npm_installed && !npm_outdated
          ok
        elsif npm_installed && npm_outdated
          run([executable, "install"] + location_options + options_a + [name],
              fail_error: "unable to upgrade the requested package")
          changed(message: "existing outdated package found and upgraded successfully")
        else
          run([executable, "install"] + location_options + options_a + [name],
              fail_error: "unable to install the requested package")
          changed
        end
      else # "absent"
        unless npm_installed
          ok
        else
          run([executable, "uninstall"] + location_options + options_a + [name],
              fail_error: "unable to remove the requested package")
          changed
        end
      end
    end
  end
end
