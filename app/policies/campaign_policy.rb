class CampaignPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def send_now?
    @account_user.administrator?
  end

  def preview_audience?
    @account_user.administrator?
  end

  def statistics?
    @account_user.administrator?
  end
end
