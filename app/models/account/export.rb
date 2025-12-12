class Account::Export < ApplicationRecord
  belongs_to :account
  belongs_to :user

  has_one_attached :file

  enum :status, %w[ pending processing completed failed ].index_by(&:itself), default: :pending

  scope :current, -> { where(created_at: 24.hours.ago..) }
  scope :expired, -> { where(completed_at: ...24.hours.ago) }

  def self.cleanup
    expired.destroy_all
  end

  def build_later
    ExportAccountDataJob.perform_later(self)
  end

  def build
    processing!
    zipfile = generate_zip

    file.attach io: File.open(zipfile.path), filename: "fizzy-export-#{id}.zip", content_type: "application/zip"
    mark_completed

    ExportMailer.completed(self).deliver_later
  rescue => e
    update!(status: :failed)
    raise
  ensure
    zipfile&.close
    zipfile&.unlink
  end

  def mark_completed
    update!(status: :completed, completed_at: Time.current)
  end

  private
    def generate_zip
      raise NotImplementedError, "Subclasses must implement generate_zip"
    end
end
