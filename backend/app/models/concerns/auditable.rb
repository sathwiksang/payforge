module Auditable
  extend ActiveSupport::Concern

  included do
    has_paper_trail(
      on: %i[create update destroy],
      meta: {
        actor_id: ->(_record) { PaperTrail.request.whodunnit },
        actor_ip: ->(_record) { RequestStore.store[:paper_trail_ip] },
        action_type: ->(_record) { RequestStore.store[:paper_trail_action] },
        merchant_id: ->(record) { record.respond_to?(:merchant_id) ? record.merchant_id : nil }
      }
    )
  end
end
