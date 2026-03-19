class Api::V1::OauthSignupsController < Api::BaseController
  include OauthSignupTokenable
  include AuthHelper
  include EmailHelper

  skip_before_action :authenticate_user!

  def create
    data = verify_oauth_signup_token(params[:signup_token])
    return render json: { error: 'invalid_or_expired_token' }, status: :unprocessable_entity unless data

    @user, @account = AccountBuilder.new(
      account_name: extract_domain_without_tld(data[:email]),
      user_full_name: data[:name],
      email: data[:email],
      user_password: params[:password],
      locale: I18n.locale,
      confirmed: data[:email_verified],
      allow_disposable: true
    ).perform

    @user.skip_confirmation! if data[:email_verified]
    Avatar::AvatarFromUrlJob.perform_later(@user, data[:avatar_url]) if data[:avatar_url].present?

    send_auth_headers(@user)
    render 'api/v1/accounts/create', format: :json, locals: { resource: @user }
  end
end
