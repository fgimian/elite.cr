module Elite
  alias ActionDetails = {action: Action, response: ActionResponse}

  class Automator
    def initialize
      @printer = Printer.new
      @actions_ok = [] of ActionDetails
      @actions_changed = [] of ActionDetails
      @actions_failed = [] of ActionDetails
    end

    def header
      @printer.header
    end

    def footer(interrupt = false)
      @printer.interrupt if interrupt

      @printer.group "Summary"
      [
        {"Changed", @actions_changed},
        {"Failed", @actions_failed}
      ].each do |type, actions|
        @printer.task type
        actions.each { |action| @printer.action(**action) }
      end

      total_actions = @actions_ok.size + @actions_changed.size + @actions_failed.size
      @printer.task "Totals"
      [
        {@actions_ok.size, State::OK},
        {@actions_changed.size, State::Changed},
        {@actions_failed.size, State::Failed},
        {total_actions, nil}
      ].each do |number, state|
        @printer.total number, state
      end

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
          action_info = {action: action, response: response}

          @printer.action(**action_info)
          if response.state == State::Changed
            @actions_changed << action_info
          else
            @actions_ok << action_info
          end

          response
        rescue ex : ActionError
          action_info = {action: action, response: ex.response}

          @printer.action(**action_info)
          @actions_failed << action_info

          ex.response
        end
      end
    {% end %}
  end
end
