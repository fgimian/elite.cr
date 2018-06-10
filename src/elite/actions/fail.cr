module Elite::Actions
  class Fail < Action
    ACTION_NAME = "fail"

    argument message : String
    add_arguments

    def process
      raise ActionProcessingError.new
    end
  end
end
