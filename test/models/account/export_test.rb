require "test_helper"

class Account::ExportTest < ActiveSupport::TestCase
  test "build_later enqueues ExportAccountDataJob" do
    export = Account::SingleUserExport.create!(account: Current.account, user: users(:david))

    assert_enqueued_with(job: ExportAccountDataJob, args: [ export ]) do
      export.build_later
    end
  end

  test "build sets status to failed on error" do
    export = Account::SingleUserExport.create!(account: Current.account, user: users(:david))
    export.stubs(:generate_zip).raises(StandardError.new("Test error"))

    assert_raises(StandardError) do
      export.build
    end

    assert export.failed?
  end

  test "cleanup deletes exports completed more than 24 hours ago" do
    old_export = Account::SingleUserExport.create!(account: Current.account, user: users(:david), status: :completed, completed_at: 25.hours.ago)
    recent_export = Account::SingleUserExport.create!(account: Current.account, user: users(:david), status: :completed, completed_at: 23.hours.ago)
    pending_export = Account::SingleUserExport.create!(account: Current.account, user: users(:david), status: :pending)

    Account::Export.cleanup

    assert_not Account::Export.exists?(old_export.id)
    assert Account::Export.exists?(recent_export.id)
    assert Account::Export.exists?(pending_export.id)
  end
end
