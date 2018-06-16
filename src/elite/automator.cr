module Elite
  alias ActionDetails = {action: Action, response: ActionResponse}

  class Automator
    def initialize
      @printer = Printer.new
      @ok_actions = [] of ActionDetails
      @changed_actions = [] of ActionDetails
      @failed_actions = [] of ActionDetails
    end

    def header
      @printer.header
    end

    def footer
      @printer.summary(@ok_actions, @changed_actions, @failed_actions)
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
            @changed_actions << action_info
          else
            @ok_actions << action_info
          end

          response
        rescue ex : ActionError
          action_info = {action: action, response: ex.response}

          @printer.action(**action_info)

          @failed_actions << action_info
          ex.response
        end
      end
    {% end %}
  end
end
