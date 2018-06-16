module Elite
  abstract struct ActionData
  end

  macro data(name, *properties)
    struct {{name.id}} < ActionData
      {% for property in properties %}
        getter {{property.var}} : {{property.type}}
      {% end %}

      def initialize({{
                       *properties.map do |field|
                         "@#{field.id}".id
                       end
                     }})
      end
    end
  end

  # Error messages may also be Nil as the base Exception class allows this
  data ErrorData, message : String | Nil

  class ActionError < Exception
    def response
      {state: State::Failed, data: ErrorData.new(message: @message)}
    end
  end

  class ActionArgumentError < ActionError
  end

  class ActionProcessingError < ActionError
  end

  record ActionResponse, state : State, data : ActionData | Nil
  record ProcessResponse, exit_code : Int32, output : String, error : String

  abstract class Action
    ACTION_NAME = nil

    # We must define dedicated class constants for all inherited classes or we end up sharing
    # the abstract class constants which causes issues.
    macro inherited
      ARGUMENT_NAMES = [] of String
      MANDATORY_ARGUMENT_NAMES = [] of String
    end

    macro argument(name, choices = [] of Symbol, default = nil, optional = false)
      {% if !choices.empty? && default == nil %}
        {% raise "A default is required when choices is used" %}
      {% end %}

      {% ARGUMENT_NAMES << name.var.stringify %}
      {% MANDATORY_ARGUMENT_NAMES << name.var.stringify if !optional && default == nil %}

      @{{ name.var }} : {{ name.type }}? = {{ default }}

      def {{ name.var }}(value)
        {% unless choices.empty? %}
          unless {{ choices }}.includes?(value)
            choices_s = {{ choices[0...-1].join(", ") }} + " or " + {{ choices[-1] }}
            raise ActionArgumentError.new("{{ name.var }} must be one of #{choices_s}")
          end
        {% end %}

        @{{ name.var }} = value
      end
    end

    def validate_arguments
    end

    def process
      raise NotImplementedError.new("please implement a process method for your action")
    end

    def ok(data = nil)
      {state: State::OK, data: data}
    end

    def changed(data = nil)
      {state: State::Changed, data: data}
    end

    # Runs the #command provided and deals with output and errors.
    def run(command : Array(String), capture_output = false, capture_error = false,
            ignore_fail = false, fail_error = nil, **options)
      # Ensure that errors are caught regardless if we intend to report errors
      capture_error = capture_error || !ignore_fail && !fail_error

      # Run the requested process
      process = Process.new(
        command.first, command[1..-1], **options,
        output: capture_output ? Process::Redirect::Pipe : Process::Redirect::Close,
        error: capture_error ? Process::Redirect::Pipe : Process::Redirect::Close
      )

      # Capture output if required
      output = capture_output ? process.output.gets_to_end : ""
      error = capture_error ? process.error.gets_to_end : ""

      # Wait for the process to complete
      status = process.wait

      # Process the results
      if status.exit_code > 0 && !ignore_fail
        if fail_error
          raise ActionProcessingError.new(fail_error)
        elsif error && error != ""
          # Workaround: Ensure that we handle inexistent executables
          # (see https://github.com/crystal-lang/crystal/issues/3517)
          if status.exit_code == 127
            error = "No such file or directory: #{command.first}"
          end

          raise ActionProcessingError.new(error.chomp)
        else
          raise ActionProcessingError.new("Unable to execute command: #{command}")
        end
      end

      return ProcessResponse.new(status.exit_code, output, error)
    end
  end

  macro finished
    {% for action_class in Action.subclasses %}
      class {{ action_class.id }}
        def arguments
          NamedTuple.new(
            {% for argument_name in action_class.constant("ARGUMENT_NAMES") %}
              {{ argument_name.id }}: @{{ argument_name.id }},
            {% end %}
          )
        end

        def invoke
          {% for argument_name in action_class.constant("MANDATORY_ARGUMENT_NAMES") %}
            if @{{ argument_name.id }}.nil?
              raise ActionArgumentError.new("argument {{ argument_name.id }} is mandatory")
            end
          {% end %}

          validate_arguments
          process
        end
      end
    {% end %}
  end
end
