module Account::StorageTracking
  extend ActiveSupport::Concern

  def adjust_storage(delta)
    increment!(:bytes_used, delta)
  end

  def adjust_storage_later(delta)
    Account::AdjustStorageJob.perform_later(self, delta)
  end
end
