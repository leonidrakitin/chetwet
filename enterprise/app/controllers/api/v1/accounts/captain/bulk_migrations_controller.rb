# frozen_string_literal: true

# Reopen OSS controller so bulk migrations list works on self-hosted (skip cloud-only filter when present).
class Api::V1::Accounts::Captain::BulkMigrationsController
  skip_before_action :check_cloud_env, raise: false
end
