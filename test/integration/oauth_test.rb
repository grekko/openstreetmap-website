require "test_helper"

class OAuthTest < ActionDispatch::IntegrationTest
  include OAuth::Helper

  def test_oauth10_web_app
    client = create(:client_application, :callback_url => "http://some.web.app.example.org/callback", :allow_read_prefs => true, :allow_write_api => true, :allow_read_gpx => true)
    user = create(:user)

    session_for(user)

    oauth10_without_callback(client)
    oauth10_with_callback(client, "http://another.web.app.example.org/callback")
    oauth10_refused(client)
  end

  def test_oauth10_desktop_app
    client = create(:client_application, :allow_read_prefs => true, :allow_write_api => true, :allow_read_gpx => true)
    user = create(:user)

    session_for(user)

    oauth10_without_callback(client)
    oauth10_refused(client)
  end

  def test_oauth10a_web_app
    client = create(:client_application, :callback_url => "http://some.web.app.example.org/callback", :allow_read_prefs => true, :allow_write_api => true, :allow_read_gpx => true)
    user = create(:user)

    session_for(user)

    oauth10a_without_callback(client)
    oauth10a_with_callback(client, "http://another.web.app.example.org/callback")
    oauth10a_refused(client)
  end

  def test_oauth10a_desktop_app
    client = create(:client_application, :allow_read_prefs => true, :allow_write_api => true, :allow_read_gpx => true)
    user = create(:user)

    session_for(user)

    oauth10a_without_callback(client)
    oauth10a_refused(client)
  end

  private

  def oauth10_without_callback(client)
    token = get_request_token(client)

    get "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize

    post "/oauth/authorize",
         :params => { :oauth_token => token.token,
                      :allow_read_prefs => "1", :allow_write_prefs => "1" }
    if client.callback_url
      assert_redirected_to "#{client.callback_url}?oauth_token=#{token.token}"
    else
      assert_response :success
      assert_template :authorize_success
    end
    token.reload
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_nil token.invalidated_at
    assert_allowed token, [:allow_read_prefs]

    signed_get "/oauth/access_token", :oauth => { :token => token }
    assert_response :success
    token.reload
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_not_nil token.invalidated_at
    token = parse_token(response)
    assert_instance_of AccessToken, token
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_nil token.invalidated_at
    assert_allowed token, [:allow_read_prefs]

    post logout_path

    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :success

    signed_get "/api/0.6/gpx/2", :oauth => { :token => token }
    assert_response :forbidden

    token.user.suspend!
    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :forbidden

    token.user.hide!
    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :forbidden

    token.user.unhide!
    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :success

    session_for(token.user)

    post "/oauth/revoke", :params => { :token => token.token }
    assert_redirected_to oauth_clients_url(token.user.display_name)
    token = OauthToken.find_by(:token => token.token)
    assert_not_nil token.invalidated_at

    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :unauthorized
  end

  def oauth10_refused(client)
    token = get_request_token(client)

    get "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize

    post "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize_failure
    assert_select "p", "You have denied application #{client.name} access to your account."
    token.reload
    assert_nil token.authorized_at
    assert_not_nil token.invalidated_at

    get "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize_failure
    assert_select "p", "The authorization token is not valid."
    token.reload
    assert_nil token.authorized_at
    assert_not_nil token.invalidated_at

    post "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize_failure
    assert_select "p", "The authorization token is not valid."
    token.reload
    assert_nil token.authorized_at
    assert_not_nil token.invalidated_at
  end

  def oauth10_with_callback(client, callback_url)
    token = get_request_token(client)

    get "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize

    post "/oauth/authorize",
         :params => { :oauth_token => token.token, :oauth_callback => callback_url,
                      :allow_write_api => "1", :allow_read_gpx => "1" }
    assert_redirected_to "#{callback_url}?oauth_token=#{token.token}"
    token.reload
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_nil token.invalidated_at
    assert_allowed token, [:allow_write_api, :allow_read_gpx]

    signed_get "/oauth/access_token", :oauth => { :token => token }
    assert_response :success
    token.reload
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_not_nil token.invalidated_at
    token = parse_token(response)
    assert_instance_of AccessToken, token
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_nil token.invalidated_at
    assert_allowed token, [:allow_write_api, :allow_read_gpx]

    post logout_path

    trace = create(:trace, :user => token.user)
    signed_get "/api/0.6/gpx/#{trace.id}", :oauth => { :token => token }
    assert_response :success

    signed_get "/api/0.6/user/details", :oauth => { :token => token }
    assert_response :forbidden

    token.user.suspend!
    signed_get "/api/0.6/gpx/#{trace.id}", :oauth => { :token => token }
    assert_response :forbidden

    token.user.hide!
    signed_get "/api/0.6/gpx/#{trace.id}", :oauth => { :token => token }
    assert_response :forbidden

    token.user.unhide!
    signed_get "/api/0.6/gpx/#{trace.id}", :oauth => { :token => token }
    assert_response :success

    session_for(token.user)

    post "/oauth/revoke", :params => { :token => token.token }
    assert_redirected_to oauth_clients_url(token.user.display_name)
    token = OauthToken.find_by(:token => token.token)
    assert_not_nil token.invalidated_at

    signed_get "/api/0.6/gpx/2", :oauth => { :token => token }
    assert_response :unauthorized
  end

  def oauth10a_without_callback(client)
    token = get_request_token(client, :oauth_callback => "oob")

    get "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize

    post "/oauth/authorize",
         :params => { :oauth_token => token.token,
                      :allow_read_prefs => "1", :allow_write_prefs => "1" }
    if client.callback_url
      assert_response :redirect
      verifier = parse_verifier(response)
      assert_redirected_to "http://some.web.app.example.org/callback?oauth_token=#{token.token}&oauth_verifier=#{verifier}"
    else
      assert_response :success
      assert_template :authorize_success
      m = response.body.match("<p>The verification code is ([A-Za-z0-9]+).</p>")
      assert_not_nil m
      verifier = m[1]
    end
    token.reload
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_nil token.invalidated_at
    assert_allowed token, [:allow_read_prefs]

    signed_get "/oauth/access_token", :oauth => { :token => token }
    assert_response :unauthorized

    signed_get "/oauth/access_token", :oauth => { :token => token, :oauth_verifier => verifier }
    assert_response :success
    token.reload
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_not_nil token.invalidated_at
    token = parse_token(response)
    assert_instance_of AccessToken, token
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_nil token.invalidated_at
    assert_allowed token, [:allow_read_prefs]

    post logout_path

    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :success

    trace = create(:trace, :user => token.user)
    signed_get "/api/0.6/gpx/#{trace.id}", :oauth => { :token => token }
    assert_response :forbidden

    token.user.suspend!
    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :forbidden

    token.user.hide!
    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :forbidden

    token.user.unhide!
    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :success

    session_for(token.user)

    post "/oauth/revoke", :params => { :token => token.token }
    assert_redirected_to oauth_clients_url(token.user.display_name)
    token = OauthToken.find_by(:token => token.token)
    assert_not_nil token.invalidated_at

    signed_get "/api/0.6/user/preferences", :oauth => { :token => token }
    assert_response :unauthorized
  end

  def oauth10a_with_callback(client, callback_url)
    token = get_request_token(client, :oauth_callback => callback_url)

    get "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize

    post "/oauth/authorize",
         :params => { :oauth_token => token.token,
                      :allow_write_api => "1", :allow_read_gpx => "1" }
    assert_response :redirect
    verifier = parse_verifier(response)
    assert_redirected_to "#{callback_url}?oauth_token=#{token.token}&oauth_verifier=#{verifier}"
    token.reload
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_nil token.invalidated_at
    assert_allowed token, [:allow_write_api, :allow_read_gpx]

    signed_get "/oauth/access_token", :oauth => { :token => token }
    assert_response :unauthorized

    signed_get "/oauth/access_token", :oauth => { :token => token, :oauth_verifier => verifier }
    assert_response :success
    token.reload
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_not_nil token.invalidated_at
    token = parse_token(response)
    assert_instance_of AccessToken, token
    assert_not_nil token.created_at
    assert_not_nil token.authorized_at
    assert_nil token.invalidated_at
    assert_allowed token, [:allow_write_api, :allow_read_gpx]

    post logout_path

    trace = create(:trace, :user => token.user)
    signed_get "/api/0.6/gpx/#{trace.id}", :oauth => { :token => token }
    assert_response :success

    signed_get "/api/0.6/user/details", :oauth => { :token => token }
    assert_response :forbidden

    token.user.suspend!
    signed_get "/api/0.6/gpx/#{trace.id}", :oauth => { :token => token }
    assert_response :forbidden

    token.user.hide!
    signed_get "/api/0.6/gpx/#{trace.id}", :oauth => { :token => token }
    assert_response :forbidden

    token.user.unhide!
    signed_get "/api/0.6/gpx/#{trace.id}", :oauth => { :token => token }
    assert_response :success

    session_for(token.user)

    post "/oauth/revoke", :params => { :token => token.token }
    assert_redirected_to oauth_clients_url(token.user.display_name)
    token = OauthToken.find_by(:token => token.token)
    assert_not_nil token.invalidated_at

    signed_get "/api/0.6/gpx/2", :oauth => { :token => token }
    assert_response :unauthorized
  end

  def oauth10a_refused(client)
    token = get_request_token(client, :oauth_callback => "oob")

    get "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize

    post "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize_failure
    assert_select "p", "You have denied application #{client.name} access to your account."
    token.reload
    assert_nil token.authorized_at
    assert_not_nil token.invalidated_at

    get "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize_failure
    assert_select "p", "The authorization token is not valid."
    token.reload
    assert_nil token.authorized_at
    assert_not_nil token.invalidated_at

    post "/oauth/authorize", :params => { :oauth_token => token.token }
    assert_response :success
    assert_template :authorize_failure
    assert_select "p", "The authorization token is not valid."
    token.reload
    assert_nil token.authorized_at
    assert_not_nil token.invalidated_at
  end

  def get_request_token(client, options = {})
    signed_get "/oauth/request_token", :oauth => options.merge(:consumer => client)
    assert_response :success
    token = parse_token(response)
    assert_instance_of RequestToken, token
    assert_not_nil token.created_at
    assert_nil token.authorized_at
    assert_nil token.invalidated_at
    assert_equal_allowing_nil options[:oauth_callback], token.callback_url
    assert_allowed token, client.permissions

    token
  end

  def parse_token(response)
    params = CGI.parse(response.body)

    token = OauthToken.find_by(:token => params["oauth_token"].first)
    assert_equal token.secret, params["oauth_token_secret"].first

    token
  end

  def parse_verifier(response)
    params = CGI.parse(URI.parse(response.location).query)

    assert_not_nil params["oauth_verifier"]
    assert_predicate params["oauth_verifier"].first, :present?

    params["oauth_verifier"].first
  end

  def assert_allowed(token, allowed)
    ClientApplication.all_permissions.each do |p|
      assert_equal allowed.include?(p), token.attributes[p.to_s]
    end
  end
end
