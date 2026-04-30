require 'listen'

module Listen
  module Adapter
    def self.select(_options = {})
      Polling
    end
  end
end
