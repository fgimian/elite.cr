require "unixium"

module Elite
  alias ActionDetails = {action: Action, response: ActionResponse}

  class Automator
    @current_options : NamedTuple(changed: Bool?, continue_on_failure: Bool, sudo: Bool)?

    def initialize
      @printer = Printer.new
      @actions = Hash(State, Array(ActionDetails)).new do |hash, key|
        hash[key] = [] of ActionDetails
      end
      @current_options = nil

      @user_uid = 0_u32
      @user_gid = 0_u32

      @root_env = {} of String => String
      @user_env = {} of String => String
    end

    def header
      @printer.header

      @printer.group "Preparation"

      user_uid_s, user_gid_s, user_name = ENV["SUDO_UID"]?, ENV["SUDO_GID"]?, ENV["SUDO_USER"]?
      unless (Unixium::Permissions.uid == 0 && Unixium::Permissions.gid == 0 &&
              user_uid_s && user_gid_s && user_name)
        # TODO: print a sexy error
        puts "Error: Elite must be run using sudo"
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

      @root_env = ENV.to_h

      # Build the user's environment using various details
      @user_env = ENV.to_h
      user = Unixium::Users.get(ENV["SUDO_USER"])
      @user_env.merge!({"USER" => user.name, "LOGNAME" => user.name, "HOME" => user.dir,
                        "SHELL" => user.shell, "PWD" => Dir.current})
      ["OLDPWD", "USERNAME", "MAIL"].each { |key| @user_env.delete(key) }

      Unixium::Permissions.egid(@user_gid)
      Unixium::Permissions.euid(@user_uid)
      ENV.from(@user_env)
    end

    def footer(interrupt = false)
      @printer.interrupt if interrupt

      @printer.group "Summary"
      [State::Changed, State::Failed].each do |state|
        next if @actions[state].empty?
        @printer.task state.to_s
        @actions[state].each { |action| @printer.action(**action) }
      end

      @printer.task "Totals"
      [State::OK, State::Changed, State::Failed].each do |state|
        @printer.total @actions[state].size, state
      end
      @printer.total @actions.map { |state, actions| actions.size }.sum

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
      # TODO: Implement sudo capabilities

      if environment
        # Backup the original environment
        env_original = ENV.to_h

        # Modify the environment as requested
        environment.each { |key, value| ENV[key] = value }
      end

      @current_options = {changed: changed, continue_on_failure: continue_on_failure, sudo: sudo}
      begin
        with self yield
      ensure
        @current_options = nil

        # Restore the original environment
        if environment && env_original
          ENV.from(env_original)
        end
      end
    end

    {% for action_class in Action.subclasses %}
      def {{ action_class.constant("ACTION_NAME").id }}

        if @current_options && @current_options.as(NamedTuple)[:sudo]
          action = {{ action_class }}.new(uid: 0_u32, gid: 0_u32)
          ENV.from(@root_env)
        else
          action = {{ action_class }}.new(uid: @user_uid, gid: @user_gid)
        end
        with action yield

        begin
          @printer.action(action: action, response: nil)
          response = action.invoke
        rescue ex : ActionError
          response = ex.response
        ensure
          if @current_options && @current_options.as(NamedTuple)[:sudo]
            ENV.from(@user_env)
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
        @actions[response.state] << action_details

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
