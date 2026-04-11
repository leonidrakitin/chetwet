# frozen_string_literal: true

class ServiceSchedulePolicy < ApplicationPolicy
  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def update?
    @account_user.administrator?
  end
end
