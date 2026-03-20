class DeviseOverrides::OmniauthCallbacksController < DeviseTokenAuth::OmniauthCallbacksController
  include EmailHelper
  include OauthSignupTokenable

  def omniauth_success
    get_resource_from_auth_hash

    @resource.present? ? sign_in_user : sign_up_user
  end

  private

  def sign_in_user
    @resource.skip_confirmation! if confirmable_enabled?

    # once the resource is found and verified
    # we can just send them to the login page again with the SSO params
    # that will log them in
    encoded_email = ERB::Util.url_encode(@resource.email)
    redirect_to login_page_url(email: encoded_email, sso_auth_token: @resource.generate_sso_auth_token)
  end

  def sign_in_user_on_mobile
    @resource.skip_confirmation! if confirmable_enabled?

    # once the resource is found and verified
    # we can just send them to the login page again with the SSO params
    # that will log them in
    encoded_email = ERB::Util.url_encode(@resource.email)
    params = { email: encoded_email, sso_auth_token: @resource.generate_sso_auth_token }.to_query

    mobile_deep_link_base = GlobalConfigService.load('MOBILE_DEEP_LINK_BASE', 'chatwootapp')
    redirect_to "#{mobile_deep_link_base}://auth/saml?#{params}", allow_other_host: true
  end

  def sign_up_user
    token = generate_oauth_signup_token(
      email: auth_hash['info']['email'],
      name: auth_hash['info']['name'],
      provider: auth_hash['provider'],
      avatar_url: auth_hash['info']['image'],
      email_verified: auth_hash['info']['email_verified']
    )
    encoded_email = ERB::Util.url_encode(auth_hash['info']['email'])
    redirect_to complete_signup_page_url(signup_token: token, email: encoded_email)
  end

  def login_page_url(error: nil, email: nil, sso_auth_token: nil, redirect: nil)
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    params = { email: email, sso_auth_token: sso_auth_token, redirect: redirect }.compact
    params[:error] = error if error.present?

    "#{frontend_url}/app/login?#{params.to_query}"
  end

  def complete_signup_page_url(signup_token:, email:)
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    params = { signup_token: signup_token, email: email }.to_query
    "#{frontend_url}/app/auth/complete-signup?#{params}"
  end

  def account_signup_allowed?
    GlobalConfigService.account_signup_enabled?
  end

  def resource_class(_mapping = nil)
    User
  end

  def get_resource_from_auth_hash # rubocop:disable Naming/AccessorMethodName
    email = auth_hash.dig('info', 'email')
    @resource = resource_class.from_email(email)
  end

  def validate_signup_email_is_business_domain?
    # return true if the user is a business account, false if it is a blocked domain account
    Account::SignUpEmailValidationService.new(auth_hash['info']['email']).perform
  rescue CustomExceptions::Account::InvalidEmail
    false
  end

  def default_devise_mapping
    'user'
  end
end

DeviseOverrides::OmniauthCallbacksController.prepend_mod_with('DeviseOverrides::OmniauthCallbacksController')
