# frozen_string_literal: true

require 'flipper'

FLIPPER = Flipper.new(Flipper::Adapters::Memory.new)

Flipper.configure do |config|
  config.default { FLIPPER }
end

Flipper.enable(:ais_event_recording)
