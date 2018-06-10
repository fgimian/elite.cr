require "json"

module Elite::Actions
  class Pip < Action
    ACTION_NAME = "pip"

    argument name : String
    argument version : String, optional: true
    argument state : String, choices: ["present", "latest", "absent"], default: "present"
    argument executable : String, optional: true
    argument virtualenv : String, optional: true
    argument options : Array(String), optional: true
    add_arguments

    def validate_arguments
      if @virtualenv && @executable
        raise ActionProcessingError.new(
          %(You must not specify both the "virtualenv" and "executable" arguments)
        )
      end

      if @state == "latest" && @version
        raise ActionProcessingError.new(
          %(You may not request "state" to be "latest" and provide a "version" argument)
        )
      end
    end

    def process
      # Determine the pip executable
      executable : String | Nil = nil

      if @virtualenv
        ["pip", "pip3", "pip2"].each do |pip|
          pip_path = File.join([@virtualenv.as(String), "bin", pip])
          if File.exists?(pip_path)
            executable = pip_path
            break
          end
        end

        unless executable
          raise ActionProcessingError.new(
            "Unable to find a pip executable in the virtualenv supplied"
          )
        end
      elsif !@executable
        ["pip", "pip3", "pip2"].each do |pip|
          executable = Process.find_executable(pip)
          break if executable
        end

        unless executable
          raise ActionProcessingError.new("Unable to determine pip executable to use")
        end
      else
        executable = @executable
      end

      executable = executable.as(String)

      # We"ll work in lowercase as pip is case insensitive
      name = @name.as(String).downcase

      # Obtain a list of installed packages
      pip_list_proc = run([executable, "list", "--format", "json"],
                          output=true, ignore_fail=true)

      # Check whether the package is installed and whether it is outdated
      unless pip_list_proc.exit_code == 0
        pip_installed = false
      else
        # Determine if the package is installed and/or outdated
        begin
          pip_list_multiple = JSON.parse(pip_list_proc.output)
          pip_list = {} of String => String
          pip_list_multiple.as_a.each do |p|
            pip_name = p["name"].as_s.downcase
            pip_version = p["version"].as_s
            pip_list[pip_name] = pip_version
          end

          pip_installed = pip_list.has_key?(name)

          if pip_installed
            pip_version = pip_list[name]
          end

          if pip_installed && @state == "latest"
            pip_list_outdated_proc = run(
              [executable, "list", "--format", "json", "--outdated"],
              output=true, ignore_fail=true
            )

            pip_list_outdated_multiple = JSON.parse(pip_list_outdated_proc.output)
            pip_list_outdated_names = pip_list_outdated_multiple.as_a.map do |p|
              p["name"].as_s.downcase
            end

            pip_outdated = pip_list_outdated_names.includes?(name)
          end
        rescue JSON::ParseException | IndexError | KeyError
          raise ActionProcessingError.new("Unable to parse installed package listing")
        end
      end

      # Prepare any user provided options
      options_a = @options.nil? ? [] of String : @options.as(Array(String))

      # Install, upgrade or remove the package as requested
      case @state
      when "present"
        if @version
          if pip_installed && @version == pip_version
            ok
          elsif pip_installed
            run([executable, "install"] + options_a + ["#{name}==#{@version}"],
                fail_error="unable to reinstall the requested package version")
            changed
          else
            run([executable, "install"] + options_a + ["#{name}==#{@version}"],
                fail_error="unable to install the requested package version")
            changed
          end
        else
          if pip_installed
            ok
          else
            run([executable, "install"] + options_a + [name],
                fail_error="unable to install the requested package")
            changed
          end
        end
      when "latest"
        if pip_installed && !pip_outdated
          ok
        elsif pip_installed && pip_outdated
          run([executable, "install", "--upgrade"] + options_a + [name],
              fail_error="unable to upgrade the requested package")
          changed
        else
          run([executable, "install"] + options_a + [name],
              fail_error="unable to install the requested package")
          changed
        end
      else # "absent"
        unless pip_installed
          ok
        else
          run([executable, "uninstall", "--yes"] + options_a + [name],
              fail_error="unable to remove the requested package")
          changed
        end
      end
    end
  end
end
