module AttackMode
  # Do not attack any area where any human is present.
  class AvoidCrossfire < Base
    def self.key = "avoid-crossfire"

    def allows?(area) = !area.humans?
  end
end
