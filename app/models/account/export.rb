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
    zipfile = generate_zip { |zip| populate_zip(zip) }

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
    def populate_zip(zip)
      raise NotImplementedError, "Subclasses must implement populate_zip"
    end

    def generate_zip
      raise ArgumentError, "Block is required" unless block_given?

      Tempfile.new([ "export", ".zip" ]).tap do |tempfile|
        Zip::File.open(tempfile.path, create: true) do |zip|
          yield zip
        end
      end
    end

    def add_file_to_zip(zip, path, content = nil, **options)
      zip.get_output_stream(path, **options) do |f|
        if block_given?
          yield f
        elsif content
          f.write(content)
        else
          raise ArgumentError, "Either content or a block must be provided"
        end
      end
    end
end
