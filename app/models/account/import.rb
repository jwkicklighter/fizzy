class Account::Import < ApplicationRecord
  belongs_to :account, required: false
  belongs_to :identity

  has_one_attached :file

  enum :status, %w[ pending processing completed failed ].index_by(&:itself), default: :pending

  def build_later
    ImportAccountDataJob.perform_later(self)
  end

  def build
    processing!

    ApplicationRecord.transaction do
      populate_from_zip
    end

    mark_completed
    ImportMailer.completed(self).deliver_later
  rescue => e
    update!(status: :failed)
    raise
  end

  def mark_completed
    update!(status: :completed, completed_at: Time.current)
  end

  private
    def populate_from_zip
      ApplicationRecord.transaction do
        Zip::File.open_buffer(file.download) do |zip|
          import_account(zip)
          import_users(zip)
          import_tags(zip)
          import_entropies(zip)
          import_columns(zip)
          import_board_publications(zip)
          import_webhooks(zip)
          import_webhook_delinquency_trackers(zip)
          import_accesses(zip)
          import_assignments(zip)
          import_taggings(zip)
          import_steps(zip)
          import_closures(zip)
          import_card_goldnesses(zip)
          import_card_not_nows(zip)
          import_card_activity_spikes(zip)
          import_watches(zip)
          import_pins(zip)
          import_reactions(zip)
          import_mentions(zip)
          import_filters(zip)
          import_events(zip)
          import_notifications(zip)
          import_notification_bundles(zip)
          import_webhook_deliveries(zip)

          import_boards(zip)
          import_cards(zip)
          import_comments(zip)

          import_active_storage_blobs(zip)
          import_active_storage_attachments(zip)
          import_action_text_rich_texts(zip)

          import_blob_files(zip)
        end
      end
    end

    def import_account(zip)
      entry = zip.find_entry("data/account.json")
      raise "Missing account.json in export" unless entry

      data = JSON.parse(entry.get_input_stream.read)
      join_code_data = data.delete("join_code")

      Account.insert(data)
      update!(account_id: data["id"])

      Account::JoinCode.insert(join_code_data) if join_code_data
    end

    def import_users(zip)
      records = read_json_files(zip, "data/users")
      User.insert_all(records) if records.any?
    end

    def import_tags(zip)
      records = read_json_files(zip, "data/tags")
      Tag.insert_all(records) if records.any?
    end

    def import_entropies(zip)
      records = read_json_files(zip, "data/entropies")
      Entropy.insert_all(records) if records.any?
    end

    def import_columns(zip)
      records = read_json_files(zip, "data/columns")
      Column.insert_all(records) if records.any?
    end

    def import_board_publications(zip)
      records = read_json_files(zip, "data/board_publications")
      Board::Publication.insert_all(records) if records.any?
    end

    def import_webhooks(zip)
      records = read_json_files(zip, "data/webhooks")
      Webhook.insert_all(records) if records.any?
    end

    def import_webhook_delinquency_trackers(zip)
      records = read_json_files(zip, "data/webhook_delinquency_trackers")
      Webhook::DelinquencyTracker.insert_all(records) if records.any?
    end

    def import_accesses(zip)
      records = read_json_files(zip, "data/accesses")
      Access.insert_all(records) if records.any?
    end

    def import_assignments(zip)
      records = read_json_files(zip, "data/assignments")
      Assignment.insert_all(records) if records.any?
    end

    def import_taggings(zip)
      records = read_json_files(zip, "data/taggings")
      Tagging.insert_all(records) if records.any?
    end

    def import_steps(zip)
      records = read_json_files(zip, "data/steps")
      Step.insert_all(records) if records.any?
    end

    def import_closures(zip)
      records = read_json_files(zip, "data/closures")
      Closure.insert_all(records) if records.any?
    end

    def import_card_goldnesses(zip)
      records = read_json_files(zip, "data/card_goldnesses")
      Card::Goldness.insert_all(records) if records.any?
    end

    def import_card_not_nows(zip)
      records = read_json_files(zip, "data/card_not_nows")
      Card::NotNow.insert_all(records) if records.any?
    end

    def import_card_activity_spikes(zip)
      records = read_json_files(zip, "data/card_activity_spikes")
      Card::ActivitySpike.insert_all(records) if records.any?
    end

    def import_watches(zip)
      records = read_json_files(zip, "data/watches")
      Watch.insert_all(records) if records.any?
    end

    def import_pins(zip)
      records = read_json_files(zip, "data/pins")
      Pin.insert_all(records) if records.any?
    end

    def import_reactions(zip)
      records = read_json_files(zip, "data/reactions")
      Reaction.insert_all(records) if records.any?
    end

    def import_mentions(zip)
      records = read_json_files(zip, "data/mentions")
      Mention.insert_all(records) if records.any?
    end

    def import_filters(zip)
      records = read_json_files(zip, "data/filters")
      Filter.insert_all(records) if records.any?
    end

    def import_events(zip)
      records = read_json_files(zip, "data/events")
      Event.insert_all(records) if records.any?
    end

    def import_notifications(zip)
      records = read_json_files(zip, "data/notifications")
      Notification.insert_all(records) if records.any?
    end

    def import_notification_bundles(zip)
      records = read_json_files(zip, "data/notification_bundles")
      Notification::Bundle.insert_all(records) if records.any?
    end

    def import_webhook_deliveries(zip)
      records = read_json_files(zip, "data/webhook_deliveries")
      Webhook::Delivery.insert_all(records) if records.any?
    end

    def import_boards(zip)
      records = read_json_files(zip, "data/boards")
      Board.insert_all(records) if records.any?
    end

    def import_cards(zip)
      records = read_json_files(zip, "data/cards")
      Card.insert_all(records) if records.any?
    end

    def import_comments(zip)
      records = read_json_files(zip, "data/comments")
      Comment.insert_all(records) if records.any?
    end

    def import_active_storage_blobs(zip)
      records = read_json_files(zip, "data/active_storage_blobs")
      ActiveStorage::Blob.insert_all(records) if records.any?
    end

    def import_active_storage_attachments(zip)
      records = read_json_files(zip, "data/active_storage_attachments")
      ActiveStorage::Attachment.insert_all(records) if records.any?
    end

    def import_action_text_rich_texts(zip)
      records = read_json_files(zip, "data/action_text_rich_texts").map do |record|
        record["body"] = convert_gids_to_sgids(record["body"])
        record
      end
      ActionText::RichText.insert_all(records) if records.any?
    end

    def import_blob_files(zip)
      zip.glob("storage/*").each do |entry|
        key = File.basename(entry.name)
        blob = ActiveStorage::Blob.find_by(key: key)
        next unless blob

        blob.upload(entry.get_input_stream)
      end
    end

    def read_json_files(zip, directory)
      zip.glob("#{directory}/*.json").map do |entry|
        JSON.parse(entry.get_input_stream.read)
      end
    end

    def convert_gids_to_sgids(html)
      return html if html.blank?

      fragment = Nokogiri::HTML.fragment(html)
      fragment.css("action-text-attachment[gid]").each do |node|
        gid = GlobalID.parse(node["gid"])
        record = gid&.find
        next unless record

        node["sgid"] = record.attachable_sgid
        node.remove_attribute("gid")
      end

      fragment.to_html
    end
end
