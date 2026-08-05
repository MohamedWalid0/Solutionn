module ObjectiveSelection
  # Step 1 — parse and validate the request.
  #
  # The body is read raw rather than through params: the control unit sends the
  # objective request either bare or wrapped in an array, and Rails would file
  # the wrapped form away under params[:_json].
  #
  # Bad input is refused here and nowhere else: an unparseable body raises
  # JSON::ParserError, an unusable attack-mode list raises AttackMode::Error,
  # and RadarController turns both into a status code. A bad *reading* is not
  # bad input — the radar is passed on untouched for step 2 to make sense of.
  class ParseRequest
    Request = Struct.new(:modes, :radar)

    def initialize(body)
      @body = body
    end

    # Modes are resolved before the radar is even looked at, so an unusable
    # attack-mode list is still reported when the sweep came back empty.
    def call
      payload = parse
      Request.new(AttackMode.build(payload["attack-mode"]), Array.wrap(payload["radar"]))
    end

    private

    attr_reader :body

    def parse
      parsed = JSON.parse(body)
      parsed = parsed.first if parsed.is_a?(Array)
      parsed.is_a?(Hash) ? parsed : {}
    end
  end
end
