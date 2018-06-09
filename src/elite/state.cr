module Elite
  # Denotes the current state of an Elite action.
  enum State
    Running
    OK
    Changed
    Failed
  end
end
