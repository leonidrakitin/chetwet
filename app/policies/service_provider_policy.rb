# frozen_string_literal: true

class ServiceProviderPolicy < ApplicationPolicy
  def index?
    @account_user&.administrator? || @account_user&.agent?
  end

  def show?
    index?
  end

  def create?
    @account_user&.administrator?
  end

  def update?
    @account_user&.administrator?
  end

  def destroy?
    @account_user&.administrator?
  end

  private

  def service_provider
    @record
  end
end
