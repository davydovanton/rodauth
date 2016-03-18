require File.expand_path("spec_helper", File.dirname(__FILE__))

describe 'Rodauth OTP feature' do
  it "should allow two factor authentication setup, login, recovery, removal" do
    rodauth{enable :login, :logout, :otp}
    roda do |r|
      #puts r.remaining_path
      r.rodauth

      r.redirect '/login' unless rodauth.logged_in?

      if rodauth.has_otp?
        r.redirect '/otp' unless rodauth.otp_authenticated?
        view :content=>"With OTP"
      else    
        view :content=>"Without OTP"
      end
    end

    visit '/'
    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'
    page.html.must_include('Without OTP')

    visit '/otp/disable'
    page.find('#notice_flash').text.must_equal 'This account has not been setup for two factor authentication'
    page.current_path.must_equal '/otp/setup'

    visit '/otp/recovery'
    page.find('#notice_flash').text.must_equal 'This account has not been setup for two factor authentication'
    page.current_path.must_equal '/otp/setup'

    visit '/otp/recovery-codes'
    page.find('#notice_flash').text.must_equal 'This account has not been setup for two factor authentication'
    page.current_path.must_equal '/otp/setup'

    visit '/otp'
    page.find('#notice_flash').text.must_equal 'This account has not been setup for two factor authentication'
    page.current_path.must_equal '/otp/setup'

    page.title.must_equal 'Setup Two Factor Authentication'
    page.html.must_include '<svg' 
    secret = page.html.match(/Secret: ([a-z2-7]{16})/)[1]
    totp = ROTP::TOTP.new(secret)
    fill_in 'Password', :with=>'asdf'
    click_button 'Setup Two Factor Authentication'
    page.find('#error_flash').text.must_equal 'Error setting up two factor authentication'
    page.html.must_include 'invalid password'

    fill_in 'Password', :with=>'0123456789'
    fill_in 'Authentication Code', :with=>"asdf"
    click_button 'Setup Two Factor Authentication'
    page.find('#error_flash').text.must_equal 'Error setting up two factor authentication'
    page.html.must_include 'Invalid authentication code'

    fill_in 'Password', :with=>'0123456789'
    fill_in 'Authentication Code', :with=>totp.now
    click_button 'Setup Two Factor Authentication'
    page.find('#notice_flash').text.must_equal 'Two factor authentication is now setup'
    page.current_path.must_equal '/'
    page.html.must_include 'With OTP'

    visit '/logout'
    click_button 'Logout'

    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'

    page.current_path.must_equal '/otp'

    visit '/otp/disable'
    page.find('#notice_flash').text.must_equal 'You need to authenticate via 2nd factor before continuing.'
    page.current_path.must_equal '/otp'

    visit '/otp/recovery-codes'
    page.find('#notice_flash').text.must_equal 'You need to authenticate via 2nd factor before continuing.'
    page.current_path.must_equal '/otp'

    visit '/otp/setup'
    page.find('#notice_flash').text.must_equal 'You have already setup two factor authentication'
    page.current_path.must_equal '/otp'

    page.title.must_equal 'Enter Authentication Code'
    fill_in 'Authentication Code', :with=>"asdf"
    click_button 'Authenticate via 2nd Factor'
    page.find('#error_flash').text.must_equal 'Error logging in via two factor authentication'
    page.html.must_include 'Invalid authentication code'

    fill_in 'Authentication Code', :with=>totp.now
    click_button 'Authenticate via 2nd Factor'
    page.find('#notice_flash').text.must_equal 'You have been authenticated via 2nd factor'
    page.html.must_include 'With OTP'

    visit '/otp'
    page.find('#notice_flash').text.must_equal 'Already authenticated via 2nd factor'

    visit '/otp/setup'
    page.find('#notice_flash').text.must_equal 'You have already setup two factor authentication'

    visit '/otp/recovery'
    page.find('#notice_flash').text.must_equal 'Already authenticated via 2nd factor'

    visit '/otp/recovery-codes'
    page.title.must_equal 'View Authentication Recovery Codes'
    fill_in 'Password', :with=>'012345678'
    click_button 'View Authentication Recovery Codes'
    page.find('#error_flash').text.must_equal 'Unable to view recovery codes.'
    page.html.must_include 'invalid password'

    fill_in 'Password', :with=>'0123456789'
    click_button 'View Authentication Recovery Codes'
    page.title.must_equal 'Authentication Recovery Codes'
    recovery_codes = find('#otp-recovery-codes').text.split
    recovery_codes.length.must_equal 16
    recovery_code = recovery_codes.first

    visit '/logout'
    click_button 'Logout'

    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'

    5.times do
      page.title.must_equal 'Enter Authentication Code'
      fill_in 'Authentication Code', :with=>"asdf"
      click_button 'Authenticate via 2nd Factor'
      page.find('#error_flash').text.must_equal 'Error logging in via two factor authentication'
      page.html.must_include 'Invalid authentication code'
    end

    page.title.must_equal 'Enter Authentication Code'
    fill_in 'Authentication Code', :with=>"asdf"
    click_button 'Authenticate via 2nd Factor'

    page.find('#error_flash').text.must_equal 'Authentication code use locked out due to numerous failures. Must use recovery code to unlock.'
    page.title.must_equal 'Enter Authentication Recovery Code'
    fill_in 'Recovery Code', :with=>"asdf"
    click_button 'Authenticate via Recovery Code'
    page.find('#error_flash').text.must_equal 'Error logging in via recovery code.'
    page.html.must_include 'Invalid recovery code'

    fill_in 'Recovery Code', :with=>recovery_code
    click_button 'Authenticate via Recovery Code'
    page.find('#notice_flash').text.must_equal 'You have been authenticated via 2nd factor'
    page.html.must_include 'With OTP'

    visit '/otp/recovery-codes'
    fill_in 'Password', :with=>'0123456789'
    click_button 'View Authentication Recovery Codes'
    page.title.must_equal 'Authentication Recovery Codes'
    page.html.wont_include(recovery_code)
    find('#otp-recovery-codes').text.split.length.must_equal 15

    click_button 'Add Authentication Recovery Codes'
    page.find('#error_flash').text.must_equal 'Unable to add recovery codes.'
    page.html.must_include 'invalid password'

    fill_in 'Password', :with=>'0123456789'
    click_button 'View Authentication Recovery Codes'
    find('#otp-recovery-codes').text.split.length.must_equal 15
    fill_in 'Password', :with=>'0123456789'
    click_button 'Add Authentication Recovery Codes'
    page.find('#notice_flash').text.must_equal 'Additional authentication recovery codes have been added.'
    find('#otp-recovery-codes').text.split.length.must_equal 16
    page.html.wont_include('Add Additional Authentication Recovery Codes')

    visit '/otp/disable'
    fill_in 'Password', :with=>'012345678'
    click_button 'Disable Two Factor Authentication'
    page.find('#error_flash').text.must_equal 'Error disabling up two factor authentication'
    page.html.must_include 'invalid password'

    fill_in 'Password', :with=>'0123456789'
    click_button 'Disable Two Factor Authentication'
    page.find('#notice_flash').text.must_equal 'Two factor authentication has been disabled'
    page.html.must_include 'Without OTP'
    [:account_otp_keys, :account_otp_recovery_codes, :account_otp_auth_failures].each do |t|
      DB[t].count.must_equal 0
    end
  end

  it "should allow namespaced two factor authentication without password requirements" do
    rodauth do
      enable :login, :logout, :otp
      otp_modifications_require_password? false
      prefix "/auth"
    end
    roda do |r|
      r.on "auth" do
        r.rodauth
      end

      r.redirect '/auth/login' unless rodauth.logged_in?

      if rodauth.has_otp?
        r.redirect '/auth/otp' unless rodauth.otp_authenticated?
        view :content=>"With OTP"
      else    
        view :content=>"Without OTP"
      end
    end

    visit '/'
    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'
    page.html.must_include('Without OTP')

    visit '/auth/otp/disable'
    page.find('#notice_flash').text.must_equal 'This account has not been setup for two factor authentication'
    page.current_path.must_equal '/auth/otp/setup'

    visit '/auth/otp/recovery'
    page.find('#notice_flash').text.must_equal 'This account has not been setup for two factor authentication'
    page.current_path.must_equal '/auth/otp/setup'

    visit '/auth/otp/recovery-codes'
    page.find('#notice_flash').text.must_equal 'This account has not been setup for two factor authentication'
    page.current_path.must_equal '/auth/otp/setup'

    visit '/auth/otp'
    page.find('#notice_flash').text.must_equal 'This account has not been setup for two factor authentication'
    page.current_path.must_equal '/auth/otp/setup'

    page.title.must_equal 'Setup Two Factor Authentication'
    page.html.must_include '<svg' 
    secret = page.html.match(/Secret: ([a-z2-7]{16})/)[1]
    totp = ROTP::TOTP.new(secret)
    fill_in 'Authentication Code', :with=>"asdf"
    click_button 'Setup Two Factor Authentication'
    page.find('#error_flash').text.must_equal 'Error setting up two factor authentication'
    page.html.must_include 'Invalid authentication code'

    fill_in 'Authentication Code', :with=>totp.now
    click_button 'Setup Two Factor Authentication'
    page.find('#notice_flash').text.must_equal 'Two factor authentication is now setup'
    page.current_path.must_equal '/'
    page.html.must_include 'With OTP'

    visit '/auth/logout'
    click_button 'Logout'

    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'

    page.current_path.must_equal '/auth/otp'

    visit '/auth/otp/disable'
    page.find('#notice_flash').text.must_equal 'You need to authenticate via 2nd factor before continuing.'
    page.current_path.must_equal '/auth/otp'

    visit '/auth/otp/recovery-codes'
    page.find('#notice_flash').text.must_equal 'You need to authenticate via 2nd factor before continuing.'
    page.current_path.must_equal '/auth/otp'

    visit '/auth/otp/setup'
    page.find('#notice_flash').text.must_equal 'You have already setup two factor authentication'
    page.current_path.must_equal '/auth/otp'

    page.title.must_equal 'Enter Authentication Code'
    fill_in 'Authentication Code', :with=>"asdf"
    click_button 'Authenticate via 2nd Factor'
    page.find('#error_flash').text.must_equal 'Error logging in via two factor authentication'
    page.html.must_include 'Invalid authentication code'

    fill_in 'Authentication Code', :with=>totp.now
    click_button 'Authenticate via 2nd Factor'
    page.find('#notice_flash').text.must_equal 'You have been authenticated via 2nd factor'
    page.html.must_include 'With OTP'

    visit '/auth/otp'
    page.find('#notice_flash').text.must_equal 'Already authenticated via 2nd factor'

    visit '/auth/otp/setup'
    page.find('#notice_flash').text.must_equal 'You have already setup two factor authentication'

    visit '/auth/otp/recovery'
    page.find('#notice_flash').text.must_equal 'Already authenticated via 2nd factor'

    visit '/auth/otp/recovery-codes'
    page.title.must_equal 'View Authentication Recovery Codes'
    click_button 'View Authentication Recovery Codes'
    page.title.must_equal 'Authentication Recovery Codes'
    recovery_codes = find('#otp-recovery-codes').text.split
    recovery_codes.length.must_equal 16
    recovery_code = recovery_codes.first

    visit '/auth/logout'
    click_button 'Logout'

    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'

    5.times do
      page.title.must_equal 'Enter Authentication Code'
      fill_in 'Authentication Code', :with=>"asdf"
      click_button 'Authenticate via 2nd Factor'
      page.find('#error_flash').text.must_equal 'Error logging in via two factor authentication'
      page.html.must_include 'Invalid authentication code'
    end

    page.title.must_equal 'Enter Authentication Code'
    fill_in 'Authentication Code', :with=>"asdf"
    click_button 'Authenticate via 2nd Factor'

    page.find('#error_flash').text.must_equal 'Authentication code use locked out due to numerous failures. Must use recovery code to unlock.'
    page.title.must_equal 'Enter Authentication Recovery Code'
    fill_in 'Recovery Code', :with=>"asdf"
    click_button 'Authenticate via Recovery Code'
    page.find('#error_flash').text.must_equal 'Error logging in via recovery code.'
    page.html.must_include 'Invalid recovery code'
    fill_in 'Recovery Code', :with=>recovery_code
    click_button 'Authenticate via Recovery Code'
    page.find('#notice_flash').text.must_equal 'You have been authenticated via 2nd factor'
    page.html.must_include 'With OTP'

    visit '/auth/otp/recovery-codes'
    click_button 'View Authentication Recovery Codes'
    page.title.must_equal 'Authentication Recovery Codes'
    page.html.wont_include(recovery_code)
    find('#otp-recovery-codes').text.split.length.must_equal 15
    click_button 'Add Authentication Recovery Codes'
    page.find('#notice_flash').text.must_equal 'Additional authentication recovery codes have been added.'
    find('#otp-recovery-codes').text.split.length.must_equal 16
    page.html.wont_include('Add Additional Authentication Recovery Codes')

    visit '/auth/otp/disable'
    click_button 'Disable Two Factor Authentication'
    page.find('#notice_flash').text.must_equal 'Two factor authentication has been disabled'
    page.html.must_include 'Without OTP'
    [:account_otp_keys, :account_otp_recovery_codes, :account_otp_auth_failures].each do |t|
      DB[t].count.must_equal 0
    end
  end
end
