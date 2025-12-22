class Account::WholeAccountExport < Account::Export
  private
    def populate_zip(zip)
      export_account(zip)
      export_users(zip)
      export_tags(zip)
      export_entropies(zip)
      export_columns(zip)
      export_board_publications(zip)
      export_webhooks(zip)
      export_webhook_delinquency_trackers(zip)
      export_accesses(zip)
      export_assignments(zip)
      export_taggings(zip)
      export_steps(zip)
      export_closures(zip)
      export_card_goldnesses(zip)
      export_card_not_nows(zip)
      export_card_activity_spikes(zip)
      export_watches(zip)
      export_pins(zip)
      export_reactions(zip)
      export_mentions(zip)
      export_filters(zip)
      export_events(zip)
      export_notifications(zip)
      export_notification_bundles(zip)
      export_webhook_deliveries(zip)

      # Models with Action Text - exported last
      export_boards(zip)
      export_cards(zip)
      export_comments(zip)
    end

    def export_account(zip)
      data = account.as_json.merge(join_code: account.join_code.as_json)
      add_file_to_zip(zip, "account.json", JSON.pretty_generate(data))
    end

    def export_users(zip)
      account.users.find_each do |user|
        add_file_to_zip(zip, "users/#{user.id}.json", JSON.pretty_generate(user.as_json))
      end
    end

    def export_tags(zip)
      account.tags.find_each do |tag|
        add_file_to_zip(zip, "tags/#{tag.id}.json", JSON.pretty_generate(tag.as_json))
      end
    end

    def export_entropies(zip)
      Entropy.where(account: account).find_each do |entropy|
        add_file_to_zip(zip, "entropies/#{entropy.id}.json", JSON.pretty_generate(entropy.as_json))
      end
    end

    def export_columns(zip)
      account.columns.find_each do |column|
        add_file_to_zip(zip, "columns/#{column.id}.json", JSON.pretty_generate(column.as_json))
      end
    end

    def export_board_publications(zip)
      Board::Publication.where(account: account).find_each do |publication|
        add_file_to_zip(zip, "board_publications/#{publication.id}.json", JSON.pretty_generate(publication.as_json))
      end
    end

    def export_webhooks(zip)
      Webhook.where(account: account).find_each do |webhook|
        add_file_to_zip(zip, "webhooks/#{webhook.id}.json", JSON.pretty_generate(webhook.as_json))
      end
    end

    def export_webhook_delinquency_trackers(zip)
      Webhook::DelinquencyTracker.joins(:webhook).where(webhook: { account: account }).find_each do |tracker|
        add_file_to_zip(zip, "webhook_delinquency_trackers/#{tracker.id}.json", JSON.pretty_generate(tracker.as_json))
      end
    end

    def export_accesses(zip)
      Access.where(account: account).find_each do |access|
        add_file_to_zip(zip, "accesses/#{access.id}.json", JSON.pretty_generate(access.as_json))
      end
    end

    def export_assignments(zip)
      Assignment.where(account: account).find_each do |assignment|
        add_file_to_zip(zip, "assignments/#{assignment.id}.json", JSON.pretty_generate(assignment.as_json))
      end
    end

    def export_taggings(zip)
      Tagging.where(account: account).find_each do |tagging|
        add_file_to_zip(zip, "taggings/#{tagging.id}.json", JSON.pretty_generate(tagging.as_json))
      end
    end

    def export_steps(zip)
      Step.where(account: account).find_each do |step|
        add_file_to_zip(zip, "steps/#{step.id}.json", JSON.pretty_generate(step.as_json))
      end
    end

    def export_closures(zip)
      Closure.where(account: account).find_each do |closure|
        add_file_to_zip(zip, "closures/#{closure.id}.json", JSON.pretty_generate(closure.as_json))
      end
    end

    def export_card_goldnesses(zip)
      Card::Goldness.where(account: account).find_each do |goldness|
        add_file_to_zip(zip, "card_goldnesses/#{goldness.id}.json", JSON.pretty_generate(goldness.as_json))
      end
    end

    def export_card_not_nows(zip)
      Card::NotNow.where(account: account).find_each do |not_now|
        add_file_to_zip(zip, "card_not_nows/#{not_now.id}.json", JSON.pretty_generate(not_now.as_json))
      end
    end

    def export_card_activity_spikes(zip)
      Card::ActivitySpike.where(account: account).find_each do |activity_spike|
        add_file_to_zip(zip, "card_activity_spikes/#{activity_spike.id}.json", JSON.pretty_generate(activity_spike.as_json))
      end
    end

    def export_watches(zip)
      Watch.where(account: account).find_each do |watch|
        add_file_to_zip(zip, "watches/#{watch.id}.json", JSON.pretty_generate(watch.as_json))
      end
    end

    def export_pins(zip)
      Pin.where(account: account).find_each do |pin|
        add_file_to_zip(zip, "pins/#{pin.id}.json", JSON.pretty_generate(pin.as_json))
      end
    end

    def export_reactions(zip)
      Reaction.where(account: account).find_each do |reaction|
        add_file_to_zip(zip, "reactions/#{reaction.id}.json", JSON.pretty_generate(reaction.as_json))
      end
    end

    def export_mentions(zip)
      Mention.where(account: account).find_each do |mention|
        add_file_to_zip(zip, "mentions/#{mention.id}.json", JSON.pretty_generate(mention.as_json))
      end
    end

    def export_filters(zip)
      Filter.where(account: account).find_each do |filter|
        add_file_to_zip(zip, "filters/#{filter.id}.json", JSON.pretty_generate(filter.as_json))
      end
    end

    def export_events(zip)
      Event.where(account: account).find_each do |event|
        add_file_to_zip(zip, "events/#{event.id}.json", JSON.pretty_generate(event.as_json))
      end
    end

    def export_notifications(zip)
      Notification.where(account: account).find_each do |notification|
        add_file_to_zip(zip, "notifications/#{notification.id}.json", JSON.pretty_generate(notification.as_json))
      end
    end

    def export_notification_bundles(zip)
      Notification::Bundle.where(account: account).find_each do |bundle|
        add_file_to_zip(zip, "notification_bundles/#{bundle.id}.json", JSON.pretty_generate(bundle.as_json))
      end
    end

    def export_webhook_deliveries(zip)
      Webhook::Delivery.where(account: account).find_each do |delivery|
        add_file_to_zip(zip, "webhook_deliveries/#{delivery.id}.json", JSON.pretty_generate(delivery.as_json))
      end
    end

    # TODO: These models use Action Text, so they need to be processed, because the SGIDs
    # depend on our secret_key_base, so we can't just import these into an OSS instance since
    # it wouldn't work. We need to stoe the attachments in the rich text such that we can
    # associate the attachment to an Attachmnent record on import.

    def export_boards(zip)
      account.boards.find_each do |board|
        add_file_to_zip(zip, "boards/#{board.id}.json", JSON.pretty_generate(board.as_json))
      end
    end

    def export_cards(zip)
      account.cards.find_each do |card|
        add_file_to_zip(zip, "cards/#{card.id}.json", JSON.pretty_generate(card.as_json))
      end
    end

    def export_comments(zip)
      Comment.where(account: account).find_each do |comment|
        add_file_to_zip(zip, "comments/#{comment.id}.json", JSON.pretty_generate(comment.as_json))
      end
    end
end
