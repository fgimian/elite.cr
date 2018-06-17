module Elite
  alias ActionDetails = {action: Action, response: ActionResponse}

  class Automator
    def initialize
      @printer = Printer.new
      @actions = Hash(State, Array(ActionDetails)).new do |hash, key|
        hash[key] = [] of ActionDetails
      end
    end

    def header
      @printer.header
    end

    def footer(interrupt = false)
      @printer.interrupt if interrupt

      @printer.group "Summary"
      [State::Changed, State::Failed].each do |state|
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

        action_details = ActionDetails.new(action: action, response: response)
        @printer.action(**action_details)
        @actions[response.state] << action_details
        response
      end
    {% end %}
  end
end
