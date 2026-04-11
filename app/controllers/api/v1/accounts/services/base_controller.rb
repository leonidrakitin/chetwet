# frozen_string_literal: true

class Api::V1::Accounts::Services::BaseController < Api::V1::Accounts::BaseController
  private

  def current_account
    @current_account ||= Current.account
  end
end
