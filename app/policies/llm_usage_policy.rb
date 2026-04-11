class LlmUsagePolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def for_conversation?
    @account_user.administrator?
  end
end
