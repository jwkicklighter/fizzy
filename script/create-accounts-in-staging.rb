#!/usr/bin/env ruby

require_relative "../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  account = Account.first
  signal_account = account.signal_account

  signal_users = SignalId::User.where(account_id: signal_account.id)

  signal_users.each do |signal_user|
    unless User.find_by(signal_user_id: signal_user.id)
      User.create!(
        name: signal_user.identity.name,
        email_address: signal_user.identity.email_address,
        signal_user_id: signal_user.id,
        password:       SecureRandom.hex(36) # TODO: remove password column?
      )
    end
  end
end
