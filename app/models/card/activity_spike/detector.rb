class Card::ActivitySpike::Detector
  attr_reader :card

  def initialize(card)
    @card = card
  end

  def detect
    if has_activity_spike?
      if card.activity_spike
        card.activity_spike.touch
      else
        card.create_activity_spike!
      end

      true
    else
      false
    end
  end

  private
    def has_activity_spike?
      card.entropic? && (multiple_people_commented? || card_was_just_assigned?)
    end

    def multiple_people_commented?
      card.comments
        .where("created_at >= ?", recent_period.seconds.ago)
        .group(:card_id)
        .having("COUNT(*) >= ?", minimum_comments)
        .having("COUNT(DISTINCT creator_id) >= ?", minimum_participants)
        .exists?
    end

    def recent_period
      card.entropy.auto_clean_period * 0.25
    end

    def minimum_participants
      3
    end

    def minimum_comments
      2
    end

    def card_was_just_assigned?
      last_event&.action&.card_assigned? && card.assigned? && last_event.created_at > 1.minute.ago
    end

    def last_event
      card.events.last
    end
end
