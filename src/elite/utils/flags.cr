module Elite
  FLAGS = {
      # archived flag (super-user only)
      "archived" => 0b10000000000000000,
      # opaque flag (owner or super-user only).
      # [Directory is opaque when viewed through a union mount]
      "opaque" => 0b1000,
      # nodump flag (owner or super-user only)
      "nodump" => 0b1,
      # system append-only flag (super-user only)
      "system_append" => 0b1000000000000000000,
      # system immutable flag (super-user only)
      "system_immutable" => 0b100000000000000000,
      # user append-only flag (owner or super-user only)
      "user_append" => 0b100,
      # user immutable flag (owner or super-user only)
      "user_immutable" => 0b10,
      # hidden flag [Hide item from GUI]
      "hidden" => 0b1000000000000000
  }
end
