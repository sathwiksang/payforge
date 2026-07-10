require "rails_helper"

RSpec.describe Fraud::Services::FeatureExtractor do
  let(:merchant) { create(:merchant, average_transaction_cents: 10_000, transaction_count_30d: 100, chargeback_rate_90d: 0.01, onboarded_at: 90.days.ago) }
  let(:extractor) { described_class.new }

  def create_tx(attrs = {})
    create(:transaction, { merchant: merchant, amount_cents: 5000, card_last_four: "4242", card_brand: "visa", status: "pending" }.merge(attrs))
  end

  describe "#extract" do
    it "returns exactly 23 features" do
      tx = create_tx
      features = extractor.extract(tx)
      expect(features.length).to eq(23)
    end

    it "returns all floats with no nil values" do
      tx = create_tx
      features = extractor.extract(tx)
      features.each_with_index do |f, i|
        expect(f).to be_a(Float), "Feature #{i} (#{Fraud::Services::FeatureExtractor::FEATURE_NAMES[i]}) is #{f.class}, expected Float"
      end
    end

    it "extracts correct amount_cents" do
      tx = create_tx(amount_cents: 15_000)
      features = extractor.extract(tx)
      expect(features[0]).to eq(15_000.0)
    end

    it "computes log_amount correctly" do
      tx = create_tx(amount_cents: 10_000)
      features = extractor.extract(tx)
      expect(features[1]).to be_within(0.01).of(Math.log(1 + 10_000.0))
    end

    it "extracts hour_of_day" do
      tx = create_tx(created_at: Time.zone.parse("2026-01-15 14:30:00"))
      features = extractor.extract(tx)
      expect(features[2]).to eq(14.0)
    end

    it "extracts day_of_week" do
      tx = create_tx(created_at: Time.zone.parse("2026-01-12 12:00:00")) # Monday
      features = extractor.extract(tx)
      expect(features[3]).to eq(1.0)
    end

    it "detects weekend" do
      sat_tx = create_tx(created_at: Time.zone.parse("2026-01-10 12:00:00")) # Saturday
      features = extractor.extract(sat_tx)
      expect(features[4]).to eq(1.0)
    end

    it "detects business hours" do
      bh_tx = create_tx(created_at: Time.zone.parse("2026-01-12 10:00:00")) # Monday 10am
      features = extractor.extract(bh_tx)
      expect(features[5]).to eq(1.0)
    end

    it "encodes card brands correctly" do
      visa_tx = create_tx(card_brand: "visa")
      expect(extractor.extract(visa_tx)[6]).to eq(0.0)

      mc_tx = create_tx(card_brand: "mastercard")
      expect(extractor.extract(mc_tx)[6]).to eq(1.0)

      amex_tx = create_tx(card_brand: "amex")
      expect(extractor.extract(amex_tx)[6]).to eq(2.0)
    end

    it "encodes currencies correctly" do
      usd_tx = create_tx(currency: "USD")
      expect(extractor.extract(usd_tx)[7]).to eq(0.0)
    end

    context "velocity features" do
      it "counts transactions in 5 minutes" do
        card = "9999"
        3.times { create_tx(card_last_four: card, created_at: 2.minutes.ago) }
        tx = create_tx(card_last_four: card)
        features = extractor.extract(tx)
        expect(features[8]).to eq(3.0) # tx_count_5min
      end

      it "sums amounts in last hour" do
        card = "8888"
        create_tx(card_last_four: card, amount_cents: 1000, created_at: 30.minutes.ago)
        create_tx(card_last_four: card, amount_cents: 2000, created_at: 45.minutes.ago)
        tx = create_tx(card_last_four: card, amount_cents: 500)
        features = extractor.extract(tx)
        expect(features[11]).to eq(3500.0) # sum_amount_1hr (includes current tx in sum)
      end

      it "counts distinct merchants in 24 hours" do
        card = "7777"
        other_merchant = create(:merchant)
        create_tx(card_last_four: card, merchant: other_merchant, created_at: 2.hours.ago)
        create_tx(card_last_four: card, created_at: 3.hours.ago)
        tx = create_tx(card_last_four: card)
        features = extractor.extract(tx)
        expect(features[13]).to eq(2.0) # distinct_merchants_24hr
      end
    end

    context "merchant features" do
      it "uses merchant average transaction" do
        tx = create_tx
        features = extractor.extract(tx)
        expect(features[14]).to eq(10_000.0)
      end

      it "uses merchant transaction count" do
        tx = create_tx
        features = extractor.extract(tx)
        expect(features[15]).to eq(100.0)
      end

      it "uses merchant chargeback rate" do
        tx = create_tx
        features = extractor.extract(tx)
        expect(features[16]).to be_within(0.001).of(0.01)
      end
    end

    context "behavioral features" do
      it "calculates amount deviation from merchant average" do
        tx = create_tx(amount_cents: 20_000) # 2x merchant avg of 10k
        features = extractor.extract(tx)
        expect(features[19]).to eq(1.0) # |20000-10000|/10000 = 1.0
      end

      it "detects first transaction from card" do
        tx = create_tx(card_last_four: "1111")
        features = extractor.extract(tx)
        expect(features[21]).to eq(1.0)
      end

      it "detects non-first transaction from card" do
        create_tx(card_last_four: "2222", created_at: 1.day.ago)
        tx = create_tx(card_last_four: "2222")
        features = extractor.extract(tx)
        expect(features[21]).to eq(0.0)
      end

      it "calculates time since last transaction" do
        create_tx(card_last_four: "3333", created_at: 1.hour.ago)
        tx = create_tx(card_last_four: "3333")
        features = extractor.extract(tx)
        expect(features[20]).to be_within(60).of(3600.0)
      end

      it "returns 999999 for first transaction time_since_last" do
        tx = create_tx(card_last_four: "4444")
        features = extractor.extract(tx)
        expect(features[20]).to eq(999_999.0)
      end
    end

    context "nil handling" do
      it "handles nil card_brand" do
        tx = create_tx(card_brand: nil)
        features = extractor.extract(tx)
        expect(features[6]).to eq(4.0) # unknown encoding
      end

      it "handles zero merchant average" do
        merchant.update!(average_transaction_cents: 0)
        tx = create_tx
        features = extractor.extract(tx)
        expect(features[19]).to eq(0.0) # amount_deviation returns 0.0 for zero avg
      end
    end
  end
end
