class Account::AdjustStorageJob < ApplicationJob
  def perform(account, delta)
    account.adjust_storage(delta)
  end
end
