require "yaml"

module Elite::Actions
  class Gem < Action
    ACTION_NAME = "gem"

    argument name : String
    argument version : String, optional: true
    argument state : String, choices: ["present", "latest", "absent"], default: "present"
    argument executable : String, optional: true
    argument options : Array(String), optional: true
    add_arguments

    def validate_arguments
      if @state == "latest" && @version
        raise ActionProcessingError.new(
          %(You may not request "state" to be "latest" and provide a "version" argument)
        )
      end
    end

    def process
      name = @name.as(String)

      # Determine the gem executable
      unless @executable
        executable = Process.find_executable("gem")
        unless executable
          raise ActionProcessingError.new("Unable to find a gem executable to use")
        end
      else
        executable = @executable.as(String)
      end

      # Obtain the specification of the requested package containing all installed versions
      # of the requested package
      gem_spec_proc = run([executable, "specification", "--all", name],
                          capture_output: true, ignore_fail: true)

      # Check whether the package is installed and whether it is outdated
      gem_versions = [] of String

      unless gem_spec_proc.exit_code == 0
        gem_installed = false
      else
        gem_installed = true

        # Determine if the package is installed and/or outdated
        begin
          gem_spec = YAML.parse_all(gem_spec_proc.output)
          gem_versions = gem_spec.map { |p| p["version"]["version"] }

          if @state == "latest"
            # Obtain the latest package version details
            gem_spec_remote_proc = run([executable, "specification", "--remote", name],
                                       capture_output: true, ignore_fail: true )
            gem_spec_remote = YAML.parse(gem_spec_remote_proc.output)
            gem_remote_version = gem_spec_remote["version"]["version"]

            # Determine if the latest package is already installed
            gem_outdated = !gem_versions.includes?(gem_remote_version)
          end
        rescue YAML::ParseException | KeyError
          raise ActionProcessingError.new("Unable to parse installed package listing")
        end
      end

      # Prepare any user provided options
      options_a = @options.nil? ? [] of String : @options.as(Array(String))

      # Install, upgrade or remove the package as requested
      case @state
      when "present"
        if @version
          if gem_installed && gem_versions.includes?(@version.as(String))
            ok
          else
            run([executable, "install", "--version", @version.as(String)] + options_a + [name],
                fail_error: "unable to install the requested package version")
            changed
          end
        else
          if gem_installed
            ok
          else
            run(
              [executable, "install"] + options_a + [name],
              fail_error: "unable to install the requested package"
            )
            changed
          end
        end
      when "latest"
        if gem_installed && !gem_outdated
          ok
        else
          run([executable, "install"] + options_a + [name],
              fail_error: "unable to install the requested package")
          changed
        end
      else # "absent"
        if !gem_installed
          ok
        elsif @version
          unless gem_versions.includes?(@version.as(String))
            ok
          end

          run([executable, "uninstall", "--version", @version.as(String)] + options_a + [name],
              fail_error: "unable to remove the requested package version")
          changed
        else
          run([executable, "uninstall", "--all", "--executable"] + options_a + [name],
              fail_error: "unable to remove the requested package")
          changed
        end
      end
    end
  end
end
