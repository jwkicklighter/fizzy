require "test_helper"

class Account::StorageTrackingTest < ActiveSupport::TestCase
  setup do
    @account = Current.account
    @account.update!(bytes_used: 0)
  end

  test "adjust_storage increments bytes_used" do
    @account.adjust_storage(1000)
    assert_equal 1000, @account.reload.bytes_used

    @account.adjust_storage(-100)
    assert_equal 900, @account.reload.bytes_used
  end
end
