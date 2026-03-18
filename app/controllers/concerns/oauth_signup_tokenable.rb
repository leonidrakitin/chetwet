module OauthSignupTokenable
  extend ActiveSupport::Concern

  private

  def generate_oauth_signup_token(data)
    payload = data.merge(exp: 15.minutes.from_now.to_i)
    oauth_signup_verifier.generate(payload)
  end

  def verify_oauth_signup_token(token)
    data = oauth_signup_verifier.verify(token)
    data = data.with_indifferent_access
    return nil if data[:exp] < Time.current.to_i

    data
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def oauth_signup_verifier
    Rails.application.message_verifier('oauth_signup')
  end
end
