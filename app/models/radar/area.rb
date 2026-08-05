module Radar
  # A group of targets sitting at one position on the radar.
  class Area
    attr_reader :x, :y, :targets, :index

    # Returns nil for a reading we cannot act on, so one garbled area never
    # takes the whole radar sweep down with it.
    def self.from(raw, index:)
      return nil unless raw.is_a?(Hash)

      position = raw["position"]
      return nil unless position.is_a?(Hash)
      return nil unless position["x"].is_a?(Numeric) && position["y"].is_a?(Numeric)

      new(
        x: position["x"],
        y: position["y"],
        # The vision module has been seen reporting a lone object where a list
        # is expected, so normalise before parsing.
        targets: Array.wrap(raw["targets"]).filter_map { |target| Target.from(target) },
        index: index
      )
    end

    def initialize(x:, y:, targets:, index:)
      @x = x
      @y = y
      @targets = targets
      @index = index
    end

    def attackable_targets
      @attackable_targets ||= targets.select(&:attackable?)
    end

    def attackable? = attackable_targets.any?

    def humans? = targets.any?(&:human?)

    def holds?(type) = attackable_targets.any? { |target| target.type == type }

    # How dangerous this area is: the only measure of importance the briefing
    # gives us, and what settles the choice when no mode has an opinion.
    def total_damage = attackable_targets.sum(&:damage)

    # Squared, because distances are only ever compared against each other:
    # no square root, no floats, no rounding to argue about.
    def distance_squared = (x**2) + (y**2)
  end
end
