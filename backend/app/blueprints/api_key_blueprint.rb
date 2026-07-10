class ApiKeyBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :key_prefix, :environment

  field :created_at do |key|
    key.created_at.iso8601
  end

  field :last_used_at do |key|
    key.last_used_at&.iso8601
  end

  field :expires_at do |key|
    key.expires_at&.iso8601
  end

  field :revoked do |key|
    key.revoked?
  end
end
