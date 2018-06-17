module Elite
  alias ActionDetails = {action: Action, response: ActionResponse}

  class Automator
    @current_options : NamedTuple(changed: Bool?, continue_on_failure: Bool)?

    def initialize
      @printer = Printer.new
      @actions = Hash(State, Array(ActionDetails)).new do |hash, key|
        hash[key] = [] of ActionDetails
      end
      @current_options = nil
    end

    def header
      @printer.header
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
        env_original = {} of String => String
        ENV.each { |key, value| env_original[key] = value }

        # Modify the environment as requested
        environment.each { |key, value| ENV[key] = value }
      end

      @current_options = {changed: changed, continue_on_failure: continue_on_failure}
      begin
        with self yield
      ensure
        @current_options = nil

        # Restore the original environment
        if environment && env_original
          ENV.clear
          env_original.each { |key, value| ENV[key] = value }
        end
      end
    end

    {% for action_class in Action.subclasses %}
      def {{ action_class.constant("ACTION_NAME").id }}
        action = {{ action_class }}.new
        with action yield

        begin
          @printer.action(action: action, response: nil)
          response = action.invoke
        rescue ex : ActionError
          response = ex.response
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
