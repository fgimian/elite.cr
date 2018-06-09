module Elite
  class Automator
    def initialize
      @printer = Printer.new
    end

    def header
      @printer.header
    end

    def footer
      @printer.group "Summary"
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
        action.run
      end
    {% end %}
  end
end
