class Captain::AssistantPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def tools?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def create_assistant?
    create?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def playground?
    true
  end

  def built_in_tools?
    true
  end
end
