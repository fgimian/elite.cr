module Elite::Actions
  class Info < Action
    ACTION_NAME = "info"

    argument message : String

    def process
      ok
    end
  end
end
