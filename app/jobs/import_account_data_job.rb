class ImportAccountDataJob < ApplicationJob
  queue_as :backend

  def perform(import)
    import.build
  end
end
