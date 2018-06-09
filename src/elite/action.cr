module Elite
  class ActionError < Exception
  end

  class ActionArgumentError < ActionError
  end

  abstract class Action
    ACTION_NAME = nil

    ARGUMENT_NAMES = [] of String
    MANDATORY_ARGUMENT_NAMES = [] of String

    macro argument(name, choices = nil, default = nil, optional = false)
      {% if choices && !default %}
        {% raise "A default is required when choices is used" %}
      {% end %}

      @{{ name.var }} : {{ name.type }} | Nil = {{ default }}

      {% Action::ARGUMENT_NAMES << name.var %}
      {% Action::MANDATORY_ARGUMENT_NAMES << name.var unless optional %}

      def {{ name.var }}(value)
        {% if choices %}
          unless {{ choices }}.includes?(value)
            raise ActionArgumentError.new("{{ name.var }} must be one of {{ choices }}")
          end
        {% end %}

        @{{ name.var }} = value
      end
    end

    def arguments
      {% begin %}
        {
          {% for argument_name in ARGUMENT_NAMES %}
            {{ argument_name }}: @{{ argument_name }},
          {% end %}
        }
      {% end %}
    end

    def run
      {% for argument_name in MANDATORY_ARGUMENT_NAMES %}
        unless @{{ argument_name }}
          raise ActionArgumentError.new("argument {{ argument_name }} is mandatory")
        end
      {% end %}

      process
    end

    def process
      raise NotImplementedError.new("please implement a run method for your action")
    end
  end
end

require "./actions/*"
