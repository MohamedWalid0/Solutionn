module AttackMode
  # The contract every attack mode implements. A mode may rule areas out, order
  # areas, order the targets inside the chosen area, or any combination of the
  # three; whatever it does not care about keeps the neutral answer below.
  class Base
    class << self
      # Name the control unit uses in the "attack-mode" list.
      def key = raise(NotImplementedError, "#{self} must define .key")

      # The decision this mode owns. Two modes sharing an axis are opposites and
      # cannot be chained; nil means the mode has no opposite.
      def axis = nil

      # Which mode ranks areas first when several are chained. Lower wins.
      def priority = 100
    end

    delegate :key, :axis, :priority, to: :class

    # Whether this area may be attacked at all.
    def allows?(_area) = true

    # Contribution to the area ordering. Lower is attacked first; the neutral 0
    # keeps every sort key the same length, and so always comparable.
    def area_rank(_area) = 0

    # Contribution to the ordering of the targets inside the chosen area.
    def target_rank(_target) = 0
  end
end
