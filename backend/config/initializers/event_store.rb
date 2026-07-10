require "rails_event_store"
require "rails_event_store_active_record"

Rails.configuration.to_prepare do
  Rails.configuration.event_store = RailsEventStore::Client.new(
    repository: RailsEventStoreActiveRecord::EventRepository.new(
      serializer: RubyEventStore::Serializers::YAML
    ),
    message_broker: RubyEventStore::Broker.new(
      subscriptions: RubyEventStore::Subscriptions.new,
      dispatcher: RubyEventStore::ComposedDispatcher.new(
        RailsEventStore::AfterCommitAsyncDispatcher.new(
          scheduler: RailsEventStore::ActiveJobScheduler.new(
            serializer: RubyEventStore::Serializers::YAML
          )
        ),
        RubyEventStore::Dispatcher.new
      )
    )
  )

  Rails.configuration.event_store.tap do |store|
    store.subscribe(
      Payments::ReadModels::TransactionReadModel.new,
      to: [
        Payments::Events::PaymentInitiated,
        Payments::Events::PaymentAuthorized,
        Payments::Events::PaymentAuthorizationFailed,
        Payments::Events::FraudCheckPassed,
        Payments::Events::FraudCheckFailed,
        Payments::Events::PaymentCaptured,
        Payments::Events::PaymentSettled,
        Payments::Events::PaymentFailed,
        Payments::Events::PaymentRefunded,
        Payments::Events::PaymentPartiallyRefunded,
        Payments::Events::PaymentVoided
      ]
    )
  end
end
