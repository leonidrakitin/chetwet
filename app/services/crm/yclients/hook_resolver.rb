class Crm::Yclients::HookResolver
  class << self
    def hooks_for(account, company_id: nil)
      scope = account.hooks.where(app_id: 'yclients', status: :enabled).order(:id)
      return scope if company_id.blank?

      scope.where("(settings->>'company_id') = ?", company_id.to_s)
    end

    def single_hook_for(account, company_id: nil)
      hooks = hooks_for(account, company_id: company_id)
      return hooks.first if company_id.present?

      return hooks.first if hooks.count == 1

      nil
    end

    def company_id_for(hook)
      hook&.settings&.fetch('company_id', nil)&.to_s
    end
  end
end
