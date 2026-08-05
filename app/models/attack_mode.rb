# Attack modes are the strategies the control unit chains together to describe
# how the next objective must be chosen.
#
# Adding a mode: subclass AttackMode::Base in app/models/attack_mode/ and add it
# to .registry. Nothing else in the module has to change.
module AttackMode
  Error = Class.new(StandardError)
  UnknownMode = Class.new(Error)
  ConflictingModes = Class.new(Error)

  # Rebuilt on every call rather than memoised, so reloading in development
  # never leaves us holding references to stale, unloaded classes.
  def self.registry
    [ ClosestFirst, FurthestFirst, AvoidCrossfire, PriorizeTX ].index_by(&:key)
  end

  # Turns the raw "attack-mode" list into mode instances, ordered so the most
  # significant one gets to rank areas first.
  def self.build(names)
    modes = Array(names).map { |name| fetch(name).new }
    reject_opposites!(modes)
    modes.sort_by(&:priority)
  end

  def self.fetch(name)
    registry[name] || raise(UnknownMode, "unknown attack mode: #{name}")
  end

  # Two modes steering the same decision are opposites, like closest-first and
  # furthest-first, and the control unit must not chain them.
  def self.reject_opposites!(modes)
    clash = modes.group_by(&:axis).except(nil).values.find { |group| group.size > 1 }
    return if clash.nil?

    raise ConflictingModes, "conflicting attack modes: #{clash.map(&:key).join(', ')}"
  end

  private_class_method :fetch, :reject_opposites!
end
