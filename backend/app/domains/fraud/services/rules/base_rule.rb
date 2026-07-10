module Fraud
  module Services
    module Rules
      class BaseRule
        attr_reader :name, :severity, :description

        def initialize(name:, severity:, description: nil)
          @name = name
          @severity = severity
          @description = description
        end

        def matches?(_transaction)
          raise NotImplementedError
        end
      end
    end
  end
end
