class Accounts::ApplyPlanService
  def initialize(account:, plan:)
    @account = account
    @plan = plan
  end

  def perform
    return unless @plan

    all_features = Featurable::FEATURE_LIST.pluck('name')
    plan_features = @plan.feature_list.map(&:to_s)

    features_to_disable = all_features - plan_features
    features_to_enable  = plan_features

    @account.disable_features(*features_to_disable) if features_to_disable.any?
    @account.enable_features(*features_to_enable)   if features_to_enable.any?
    @account.save
  end
end
