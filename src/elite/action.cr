module Elite
  abstract class Action
    ACTION_NAME = nil

    def run
      raise NotImplementedError.new("please implement a run method for your action")
    end
  end
end

require "./actions/*"
