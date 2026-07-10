module Fraud
  module Services
    class FraudScoringEngine
      SCORE_THRESHOLD_BLOCK = 0.85
      SCORE_THRESHOLD_REVIEW = 0.60

      def initialize
        @model = load_model
        @feature_extractor = FeatureExtractor.new
        @rule_engine = RuleEngine.new
      end

      def score(transaction)
        # Step 1: Rule-based pre-screening (fast path)
        rule_result = @rule_engine.evaluate(transaction)
        if rule_result.hard_block?
          return build_result(
            score: 1.0,
            decision: "block",
            shap_values: {},
            matched_rules: rule_result.matched_rules,
            model_used: "rule_engine",
            latency_ms: rule_result.latency_ms,
            transaction: transaction
          )
        end

        # Step 2: ML scoring (LightGBM in Ruby)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        features = @feature_extractor.extract(transaction)

        if @model
          prediction = run_inference(features)
        else
          prediction = rule_based_score(rule_result)
        end

        latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

        # Step 3: Determine decision
        decision = if prediction >= SCORE_THRESHOLD_BLOCK
                     "block"
                   elsif prediction >= SCORE_THRESHOLD_REVIEW
                     "review"
                   else
                     "pass"
                   end

        # Step 4: SHAP explanation (sync for block/review, async for pass)
        shap_values = if decision != "pass"
                        request_shap_explanation(features)
                      else
                        {}
                      end

        build_result(
          score: prediction.round(4),
          decision: decision,
          shap_values: shap_values,
          matched_rules: rule_result.matched_rules,
          model_used: @model ? model_name : "rule_engine_fallback",
          latency_ms: latency_ms,
          transaction: transaction,
          feature_vector: features
        )
      rescue => e
        Rails.logger.error("ML scoring failed: #{e.message}")
        fallback_rule_only_scoring(transaction)
      end

      private

      def load_model
        onnx_path = Rails.root.join("ml_models", "fraud_lgbm.onnx")
        if File.exist?(onnx_path)
          @model_type = :onnx
          return OnnxRuntime::Model.new(onnx_path.to_s)
        end

        txt_path = Rails.root.join("ml_models", "fraud_lgbm.txt")
        if File.exist?(txt_path)
          @model_type = :lightgbm
          return LightGBM::Booster.new(model_file: txt_path.to_s)
        end

        Rails.logger.warn("No fraud model found, using rule-engine-only scoring")
        nil
      rescue => e
        Rails.logger.error("Model load failed: #{e.message}")
        nil
      end

      def run_inference(features)
        case @model_type
        when :onnx
          output = @model.predict({ "features" => [features.map(&:to_f)] })
          # ONNX LightGBM classifier outputs probabilities
          probabilities = output.values.last
          probabilities.is_a?(Array) ? probabilities.flatten.last : probabilities.to_f
        when :lightgbm
          @model.predict([features]).first
        else
          0.0
        end
      rescue => e
        Rails.logger.error("Inference failed: #{e.message}")
        0.0
      end

      def model_name
        case @model_type
        when :onnx then "lightgbm_onnx_v1"
        when :lightgbm then "lightgbm_native_v1"
        else "unknown"
        end
      end

      def rule_based_score(rule_result)
        return 0.0 if rule_result.matched_rules.empty?

        severity_scores = { "critical" => 0.9, "high" => 0.5, "medium" => 0.3, "low" => 0.1 }
        max_severity = rule_result.matched_rules.map { |r| severity_scores[r[:severity]] || 0.0 }.max
        [max_severity, 1.0].min
      end

      def request_shap_explanation(features)
        sidecar_url = ENV.fetch("ML_SIDECAR_URL", "http://localhost:3201")
        response = Faraday.post("#{sidecar_url}/explain/") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = { features: features }.to_json
          req.options.timeout = 2
        end

        JSON.parse(response.body) if response.success?
      rescue Faraday::Error => e
        Rails.logger.warn("SHAP explanation unavailable: #{e.message}")
        {}
      end

      def fallback_rule_only_scoring(transaction)
        rule_result = @rule_engine.evaluate(transaction)
        score = rule_based_score(rule_result)
        decision = if score >= SCORE_THRESHOLD_BLOCK
                     "block"
                   elsif score >= SCORE_THRESHOLD_REVIEW
                     "review"
                   else
                     "pass"
                   end

        build_result(
          score: score.round(4),
          decision: decision,
          shap_values: {},
          matched_rules: rule_result.matched_rules,
          model_used: "rule_engine_fallback",
          latency_ms: rule_result.latency_ms,
          transaction: transaction
        )
      end

      def build_result(score:, decision:, shap_values:, matched_rules:, model_used:, latency_ms:, transaction:, feature_vector: [])
        result = ScoringResult.new(
          score: score,
          decision: decision,
          shap_values: shap_values,
          matched_rules: matched_rules,
          model_used: model_used,
          latency_ms: latency_ms
        )

        # Create fraud case for review/block decisions
        if decision != "pass"
          priority = case decision
                     when "block" then score >= 0.95 ? :critical : :high
                     when "review" then score >= 0.75 ? :high : :medium
                     else :low
                     end

          Fraud::Models::FraudCase.create!(
            payment_transaction: transaction,
            merchant: transaction.merchant,
            status: "open",
            priority: priority,
            risk_score: score,
            decision: decision,
            model_used: model_used,
            latency_ms: latency_ms,
            matched_rules: matched_rules,
            shap_values: shap_values,
            feature_vector: feature_vector
          )
        end

        result
      end
    end

    ScoringResult = Struct.new(:score, :decision, :shap_values, :matched_rules,
                               :model_used, :latency_ms, keyword_init: true)
  end
end
