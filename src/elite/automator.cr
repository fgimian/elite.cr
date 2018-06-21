require "unixium"

module Elite
  alias ActionDetails = {action: Action, response: ActionResponse}

  class Automator
    @current_options : NamedTuple(changed: Bool?, continue_on_failure: Bool, sudo: Bool)?

    def initialize
      @printer = Printer.new
      @executed_actions = Hash(State, Array(ActionDetails)).new do |hash, key|
        hash[key] = [] of ActionDetails
      end
      @current_options = nil
      @root_env = {} of String => String
      @user_uid = 0_u32
      @user_gid = 0_u32
      @user_env = {} of String => String
    end

    def header
      @printer.header

      @printer.group "Preparation"

      user_uid_s, user_gid_s, user_name = ENV["SUDO_UID"]?, ENV["SUDO_GID"]?, ENV["SUDO_USER"]?
      unless (Unixium::Permissions.uid == 0 && Unixium::Permissions.gid == 0 &&
              user_uid_s && user_gid_s && user_name &&
              user_uid_s != "0" && user_gid_s != "0" && user_name != "root")
        # TODO: print a sexy error
        puts "Error: Elite must be run using sudo via a regular user account"
        exit 1
      end

      begin
        @user_uid = user_uid_s.to_u32
        @user_gid = user_gid_s.to_u32
      rescue ArgumentError
        # TODO: print a sexy error
        puts "The sudo uid and/or gids contain an invalid value"
        exit 1
      end

      # Copy root's environment variables for future use
      @root_env = ENV.to_h

      # Build the user's environment using various details
      user = Unixium::Users.get(user_name)
      @user_env = ENV.to_h
      @user_env.merge!({"USER" => user.name, "LOGNAME" => user.name, "HOME" => user.dir,
                        "SHELL" => user.shell, "PWD" => Dir.current})
      ["OLDPWD", "USERNAME", "MAIL"].each { |key| @user_env.delete(key) }

      # Set effective permissions and environment to that of the calling user (demotion)
      Unixium::Permissions.egid(@user_gid)
      Unixium::Permissions.euid(@user_uid)
      ENV.from(@user_env)
    end

    def footer(interrupt = false)
      @printer.interrupt if interrupt

      @printer.group "Summary"
      [State::Changed, State::Failed].each do |state|
        next if @executed_actions[state].empty?
        @printer.task state.to_s
        @executed_actions[state].each { |action| @printer.action(**action) }
      end

      @printer.task "Totals"
      [State::OK, State::Changed, State::Failed].each do |state|
        @printer.total @executed_actions[state].size, state
      end
      @printer.total @executed_actions.map { |state, actions| actions.size }.sum

      @printer.footer
    end

    def group(name : String)
      @printer.group(name)
      with self yield
    end

    def task(name : String)
      @printer.task(name)
      with self yield
    end

    def options(sudo = false, changed : Bool? = nil, continue_on_failure = false,
                environment = {} of String => String)
      @current_options = {changed: changed, continue_on_failure: continue_on_failure, sudo: sudo}
      ENV.from(@root_env) if sudo
      environment.each { |key, value| ENV[key] = value } if environment

      begin
        with self yield
      ensure
        @current_options = nil
        ENV.from(@user_env) if sudo || environment
      end
    end

    {% for action_class in Action.subclasses %}
      def {{ action_class.constant("ACTION_NAME").id }}
        if @current_options && @current_options.as(NamedTuple)[:sudo]
          uid, gid = 0_u32, 0_u32
          Unixium::Permissions.egid(0_u32)
          Unixium::Permissions.euid(0_u32)
        else
          uid, gid = @user_uid, @user_gid
        end

        action = {{ action_class }}.new(uid, gid)
        with action yield

        begin
          @printer.action(action: action, response: nil)
          response = action.invoke
        rescue ex : ActionError
          response = ex.response
        ensure
          if @current_options && @current_options.as(NamedTuple)[:sudo]
            Unixium::Permissions.egid(@user_gid)
            Unixium::Permissions.euid(@user_uid)
          end
        end

        if @current_options && !@current_options.as(NamedTuple)[:changed].nil?
          changed = @current_options.as(NamedTuple)[:changed].as(Bool)
          state = changed ? State::Changed : State::OK
          if [State::OK, State::Changed].includes?(response.state) && response.state != state
            response = ActionResponse.new(state: state, data: response.data)
          end
        end

        action_details = ActionDetails.new(action: action, response: response)
        @printer.action(**action_details)
        @executed_actions[response.state] << action_details

        raise ex if ex && !(@current_options && @current_options.as(NamedTuple)[:continue_on_failure])
        response
      end

      # Provide an overload when no block is needed (in the case that an action has no arguments)
      def {{ action_class.constant("ACTION_NAME").id }}
        {{ action_class.constant("ACTION_NAME").id }} {}
      end
    {% end %}
  end
end
