MoneyRails.configure do |config|
  config.default_currency = :usd
  config.rounding_mode = BigDecimal::ROUND_HALF_UP
  config.no_cents_if_whole = false
  config.raise_error_on_money_parsing = true
end

Money.rounding_mode = BigDecimal::ROUND_HALF_UP
Money.locale_backend = :i18n
