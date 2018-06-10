module Elite::Actions
  class Info < Action
    ACTION_NAME = "info"

    argument message : String
    add_arguments

    def process
      ok
    end
  end
end
