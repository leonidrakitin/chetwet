# frozen_string_literal: true

class ServiceBookingPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    index?
  end

  def create?
    @account_user.administrator? || @account_user.agent?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def available_slots?
    @account_user.administrator? || @account_user.agent?
  end

  def upcoming?
    index?
  end

  def confirm?
    @account_user.administrator? || @account_user.agent?
  end

  def cancel?
    @account_user.administrator? || @account_user.agent?
  end
end
