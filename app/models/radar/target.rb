module Radar
  # One target reported by the vision module.
  class Target
    HUMAN = "Human".freeze

    attr_reader :type, :damage

    # Returns nil for a reading we cannot make sense of.
    def self.from(raw)
      return nil unless raw.is_a?(Hash)

      new(type: raw["type"], damage: raw["damage"])
    end

    def initialize(type:, damage:)
      @type = type
      @damage = damage
    end

    # Two rules, and the module holds to both. A human is never an attack
    # target, whatever the vision module claims about it. And a reading without
    # numeric damage is one we cannot make sense of — that is how the vision
    # module reports a human today, and how it reports its own garbled output.
    def attackable? = type.present? && !human? && damage.is_a?(Numeric)

    def human? = type == HUMAN
  end
end
