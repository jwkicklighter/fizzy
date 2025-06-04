require "test_helper"

class Card::StallableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "a card without activity spike is not stalled" do
    assert_not cards(:logo).stalled?
  end

  test "a card with a recent activity spike is not stalled" do
    cards(:logo).create_activity_spike!
    assert_not cards(:logo).stalled?
  end

  test "a card with an old activity spike is stalled" do
    cards(:logo).create_activity_spike!(updated_at: 3.months.ago)
    assert cards(:logo).stalled?
  end

  # More fine-grained testing in Card::ActivitySpike::Detector
  test "detect activity spikes" do
    assert_not cards(:logo).stalled?

    perform_enqueued_jobs only: Card::ActivitySpike::DetectionJob do
      4.times do |index|
        cards(:logo).comments.create(body: "Comment number #{index}")
      end
    end

    travel_to 1.month.from_now

    assert cards(:logo).reload.stalled?
  end
end
