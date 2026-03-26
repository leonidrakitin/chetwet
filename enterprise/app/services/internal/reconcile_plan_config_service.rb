class Internal::ReconcilePlanConfigService
  def perform
    Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING)
  end
end
