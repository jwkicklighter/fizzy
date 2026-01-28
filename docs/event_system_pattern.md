# Event System Pattern in Fizzy

This document provides a detailed explanation of the Event system pattern used in Fizzy, a Rails application. This pattern can be implemented in other Ruby on Rails applications to track domain events, trigger notifications, dispatch webhooks, and maintain an audit trail of user actions.

## Table of Contents

1. [Overview](#overview)
2. [Core Components](#core-components)
3. [Database Schema](#database-schema)
4. [The Eventable Concern](#the-eventable-concern)
5. [Event Model](#event-model)
6. [Event Lifecycle](#event-lifecycle)
7. [Tracking Events](#tracking-events)
8. [Event Storage and Particulars](#event-storage-and-particulars)
9. [Notifications](#notifications)
10. [Webhooks](#webhooks)
11. [System Comments](#system-comments)
12. [Event Display](#event-display)
13. [Implementation Guide](#implementation-guide)
14. [Testing](#testing)

## Overview

The Event system in Fizzy is a domain event tracking pattern that records significant actions users take in the application. Every meaningful state change (e.g., creating a card, assigning a user, closing a card) generates an Event record that:

- Provides an audit trail of who did what and when
- Triggers notifications to relevant users
- Dispatches webhooks to external systems
- Generates system comments for activity feeds
- Powers activity timelines and reporting

This is implemented using:
- A polymorphic `Event` model
- An `Eventable` concern that models include
- Callbacks that automatically track events on state changes
- Supporting infrastructure for notifications, webhooks, and display

## Core Components

### 1. Event Model (`app/models/event.rb`)

The central model that stores all events in the system.

```ruby
class Event < ApplicationRecord
  include Notifiable, Particulars, Promptable

  belongs_to :account
  belongs_to :board
  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true

  has_many :webhook_deliveries, dependent: :delete_all

  after_create -> { eventable.event_was_created(self) }
  after_create_commit :dispatch_webhooks

  delegate :card, to: :eventable
end
```

### 2. Eventable Concern (`app/models/concerns/eventable.rb`)

A concern that models include to gain event-tracking capabilities.

```ruby
module Eventable
  extend ActiveSupport::Concern

  included do
    has_many :events, as: :eventable, dependent: :destroy
  end

  def track_event(action, creator: Current.user, board: self.board, **particulars)
    if should_track_event?
      board.events.create!(
        action: "#{eventable_prefix}_#{action}",
        creator: creator,
        board: board,
        eventable: self,
        particulars: particulars
      )
    end
  end

  def event_was_created(event)
    # Override in including class to react to event creation
  end

  private
    def should_track_event?
      true
    end

    def eventable_prefix
      self.class.name.demodulize.underscore
    end
end
```

## Database Schema

The `events` table uses a polymorphic association to link to any trackable model:

```ruby
create_table "events", id: :uuid do |t|
  t.uuid "account_id", null: false        # Multi-tenant isolation
  t.string "action", null: false          # e.g., "card_published", "comment_created"
  t.uuid "board_id", null: false          # Board where event occurred
  t.datetime "created_at", null: false
  t.uuid "creator_id", null: false        # User who performed the action
  t.uuid "eventable_id", null: false      # Polymorphic ID
  t.string "eventable_type", null: false  # Polymorphic type (Card, Comment, etc.)
  t.json "particulars", default: {}       # Action-specific metadata
  t.datetime "updated_at", null: false
  
  # Indexes for efficient querying
  t.index ["account_id", "action"]
  t.index ["board_id", "action", "created_at"]
  t.index ["board_id"]
  t.index ["creator_id"]
  t.index ["eventable_type", "eventable_id"]
end
```

**Key Design Decisions:**

1. **UUID Primary Keys**: Events use UUIDs for distributed ID generation
2. **Polymorphic Association**: `eventable` can reference any model (Card, Comment, etc.)
3. **Account and Board IDs**: Denormalized for efficient querying and multi-tenancy
4. **Action as String**: Uses convention `{model}__{action}` (e.g., "card_published")
5. **JSON Particulars**: Flexible metadata storage for action-specific details
6. **Strategic Indexes**: Optimized for common query patterns (timeline, filtering by action)

## The Eventable Concern

### Including Eventable

Models include the `Eventable` concern to gain event tracking:

```ruby
class Card < ApplicationRecord
  include Eventable
  # ...
end

class Comment < ApplicationRecord
  include Eventable
  # ...
end
```

### Customizing Event Tracking

Models can customize event behavior by:

1. **Overriding `should_track_event?`** - Control when events are tracked:

```ruby
module Card::Eventable
  def should_track_event?
    published?  # Only track events for published cards
  end
end
```

2. **Overriding `event_was_created(event)`** - React to event creation:

```ruby
module Card::Eventable
  def event_was_created(event)
    transaction do
      create_system_comment_for(event)
      touch_last_active_at unless was_just_published?
    end
  end
end
```

3. **Custom event prefix** (if needed):

```ruby
def eventable_prefix
  "custom_prefix"  # Default is model name underscored
end
```

## Event Model

### Included Modules

The Event model includes three modules:

1. **Notifiable** - Enables notification creation
2. **Particulars** - Provides accessors for JSON metadata
3. **Promptable** - Formats events for AI/LLM consumption

### Key Methods

```ruby
# Get action as an inquiry object for easier checking
event.action  # Returns StringInquiry
event.action.card_published?  # => true/false

# Get description formatted for a specific user
event.description_for(user)  # Returns Event::Description instance

# Delegate to eventable
event.card  # Gets the associated card (even if eventable is a comment)
```

### Callbacks

```ruby
after_create -> { eventable.event_was_created(self) }
after_create_commit :dispatch_webhooks
```

These callbacks:
1. Notify the eventable immediately after creation (within transaction)
2. Dispatch webhooks asynchronously after transaction commits

## Event Lifecycle

Here's the complete lifecycle when an event is created:

```
1. Action occurs (e.g., card.close)
   ↓
2. track_event called with action and particulars
   ↓
3. Event record created
   ↓
4. After create callback: eventable.event_was_created(event)
   ├─> Creates system comment (if applicable)
   └─> Updates last_active_at timestamp
   ↓
5. After commit callback: dispatch_webhooks
   ├─> Enqueues Event::WebhookDispatchJob
   └─> (async) Triggers matching webhooks
   ↓
6. After commit callback: notify_recipients_later (from Notifiable)
   ├─> Enqueues NotifyRecipientsJob
   └─> (async) Creates Notification records
```

## Tracking Events

### Basic Pattern

The basic pattern for tracking events:

```ruby
track_event(action, **particulars)
```

Where:
- `action` - The action name (will be prefixed with model name)
- `particulars` - Hash of action-specific metadata

### Example: Card Assignment

```ruby
module Card::Assignable
  def assign(user)
    assignment = assignments.create(assignee: user, assigner: Current.user)
    
    if assignment.persisted?
      watch_by user
      track_event :assigned, assignee_ids: [user.id]
    end
  end
end
```

This creates an event with:
- `action: "card_assigned"`
- `eventable: self` (the card)
- `creator: Current.user`
- `board: self.board`
- `particulars: { assignee_ids: [user.id] }`

### Example: Card State Changes

```ruby
module Card::Closeable
  def close(user: Current.user)
    transaction do
      create_closure!(user: user)
      track_event :closed, creator: user
    end
  end

  def reopen(user: Current.user)
    transaction do
      closure&.destroy
      track_event :reopened, creator: user
    end
  end
end
```

### Example: Attribute Changes

```ruby
module Card::Eventable
  after_save :track_title_change, if: :saved_change_to_title?

  def track_title_change
    if title_before_last_save.present?
      track_event "title_changed", 
        particulars: { 
          old_title: title_before_last_save, 
          new_title: title 
        }
    end
  end
end
```

### Example: Model Creation

```ruby
module Comment::Eventable
  after_create_commit :track_creation

  def track_creation
    track_event("created", board: card.board, creator: creator)
  end
end
```

## Event Storage and Particulars

### The Particulars Module

Events store action-specific metadata in the `particulars` JSON column. The `Event::Particulars` module provides typed accessors:

```ruby
module Event::Particulars
  extend ActiveSupport::Concern

  included do
    store_accessor :particulars, :assignee_ids
  end

  def assignees
    @assignees ||= User.where(id: assignee_ids)
  end
end
```

### Storing Metadata

Common patterns for storing metadata:

```ruby
# User IDs
track_event :assigned, assignee_ids: [user.id]

# Before/after values
track_event :title_changed, 
  particulars: { old_title: old_value, new_title: new_value }

# Location changes
track_event :board_changed,
  particulars: { old_board: old_name, new_board: new_name }

# Status/state
track_event :triaged,
  particulars: { column: column.name }
```

### Accessing Metadata

```ruby
# Via store_accessor
event.assignee_ids  # [uuid, uuid]
event.assignees     # User::ActiveRecord_Relation

# Direct access
event.particulars["old_title"]
event.particulars.dig("particulars", "old_title")  # Nested structure
```

## Notifications

Events integrate with a notification system to alert users:

### Notifiable Module

The Event model includes `Notifiable`:

```ruby
module Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, as: :source, dependent: :destroy
    after_create_commit :notify_recipients_later
  end

  def notify_recipients
    Notifier.for(self)&.notify
  end
end
```

### Notifier Pattern

The `Notifier` class uses a factory pattern to determine which users to notify:

```ruby
class Notifier
  def self.for(source)
    case source
    when Event
      "Notifier::#{source.eventable.class}EventNotifier".safe_constantize&.new(source)
    when Mention
      MentionNotifier.new(source)
    end
  end

  def notify
    if should_notify?
      recipients.sort_by(&:id).map do |recipient|
        Notification.create!(user: recipient, source: source, creator: creator)
      end
    end
  end
end
```

### Card Event Notifier Example

```ruby
class Notifier::CardEventNotifier < Notifier
  delegate :creator, to: :source
  delegate :board, to: :card

  private
    def recipients
      case source.action
      when "card_assigned"
        source.assignees.excluding(creator)
      when "card_published"
        board.watchers.without(creator, *card.mentionees).including(*card.assignees).uniq
      when "comment_created"
        card.watchers.without(creator, *source.eventable.mentionees)
      else
        board.watchers.without(creator)
      end
    end

    def card
      source.eventable
    end
end
```

This determines who gets notified based on the action type.

## Webhooks

Events trigger webhooks to notify external systems:

### Webhook Model

```ruby
class Webhook < ApplicationRecord
  include Triggerable
  
  belongs_to :board
  has_many :deliveries, dependent: :delete_all
  
  serialize :subscribed_actions, type: Array, coder: JSON
  
  scope :active, -> { where(active: true) }
end
```

### Triggerable Concern

```ruby
module Webhook::Triggerable
  extend ActiveSupport::Concern

  included do
    scope :triggered_by, ->(event) { 
      where(board: event.board).triggered_by_action(event.action) 
    }
    scope :triggered_by_action, ->(action) { 
      where("subscribed_actions LIKE ?", "%\"#{action}\"%") 
    }
  end

  def trigger(event)
    deliveries.create!(event: event)
  end
end
```

### Webhook Dispatch Job

After an event is committed, webhooks are dispatched asynchronously:

```ruby
class Event::WebhookDispatchJob < ApplicationJob
  queue_as :webhooks

  def perform(event)
    Webhook.active.triggered_by(event).find_each do |webhook|
      webhook.trigger(event)
    end
  end
end
```

### Permitted Actions

Not all events trigger webhooks - only specific actions:

```ruby
PERMITTED_ACTIONS = %w[
  card_assigned
  card_closed
  card_postponed
  card_auto_postponed
  card_board_changed
  card_published
  card_reopened
  card_sent_back_to_triage
  card_triaged
  card_unassigned
  comment_created
]
```

## System Comments

When events occur, the system can automatically create "system comments" to display in activity feeds:

### System Commenter

```ruby
class Card::Eventable::SystemCommenter
  def initialize(card, event)
    @card, @event = card, event
  end

  def comment
    return unless comment_body.present?
    
    card.comments.create!(
      creator: card.account.system_user,
      body: comment_body,
      created_at: event.created_at
    )
  end

  private
    def comment_body
      case event.action
      when "card_assigned"
        "#{creator_name} <strong>assigned</strong> this to #{assignee_names}."
      when "card_closed"
        "<strong>Moved</strong> to "Done" by #{creator_name}"
      when "card_title_changed"
        "#{creator_name} <strong>changed the title</strong> from "#{old_title}" to "#{new_title}"."
      # ... more actions
      end
    end
end
```

This creates a comment record that shows in the card's activity feed, providing a human-readable description of what happened.

### Invocation

System comments are created in the `event_was_created` callback:

```ruby
module Card::Eventable
  def event_was_created(event)
    transaction do
      create_system_comment_for(event)
      touch_last_active_at unless was_just_published?
    end
  end

  private
    def create_system_comment_for(event)
      SystemCommenter.new(self, event).comment
    end
end
```

## Event Display

### Event Description

The `Event::Description` class formats events for display to users:

```ruby
class Event::Description
  def initialize(event, user)
    @event = event
    @user = user
  end

  def to_html
    # Returns HTML with personalization (shows "You" vs creator name)
    to_sentence(creator_tag, card_title_tag).html_safe
  end

  def to_plain_text
    # Returns plain text version
    to_sentence(creator_name, card.title)
  end

  private
    def to_sentence(creator, card_title)
      case event.action
      when "card_assigned"
        if event.assignees.include?(user)
          "#{creator} will handle #{card_title}"
        else
          "#{creator} assigned #{event.assignees.pluck(:name).to_sentence} to #{card_title}"
        end
      when "card_published"
        "#{creator} added #{card_title}"
      # ... more actions
      end
    end
end
```

### Usage

```ruby
event.description_for(current_user).to_html
# => "You added <span class='txt-underline'>Fix the logo</span>"

event.description_for(other_user).to_html  
# => "David added <span class='txt-underline'>Fix the logo</span>"
```

### View Rendering

Events are rendered using partials:

```erb
<!-- app/views/events/_event.html.erb -->
<% cache event do %>
  <% if lookup_context.exists?("events/event/eventable/_#{event.action}") %>
    <%= render "events/event/eventable/#{event.action}", event: event %>
  <% else %>
    <%= render "events/event/eventable/#{event.eventable_type.demodulize.underscore}", event: event %>
  <% end %>
<% end %>
```

This allows customization per action or per model type.

## Implementation Guide

Here's a step-by-step guide to implementing this pattern in your Rails application:

### Step 1: Create the Events Table

```ruby
# db/migrate/XXXXXX_create_events.rb
class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events, id: :uuid do |t|
      # Adjust to your multi-tenancy strategy
      t.references :account, null: false, foreign_key: true, type: :uuid
      
      t.string :action, null: false
      t.references :board, null: false, foreign_key: true, type: :uuid
      t.references :creator, null: false, foreign_key: { to_table: :users }, type: :uuid
      
      # Polymorphic association
      t.references :eventable, null: false, polymorphic: true, type: :uuid
      
      # Flexible metadata storage
      t.json :particulars, default: {}
      
      t.timestamps
    end

    add_index :events, [:account_id, :action]
    add_index :events, [:board_id, :action, :created_at]
  end
end
```

### Step 2: Create the Event Model

```ruby
# app/models/event.rb
class Event < ApplicationRecord
  belongs_to :account
  belongs_to :board
  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true

  scope :chronologically, -> { order(created_at: :asc, id: :desc) }
  scope :preloaded, -> { includes(:creator, :board, :eventable) }

  after_create -> { eventable.event_was_created(self) }

  def action
    super.inquiry  # Converts to StringInquiry for .card_published? style checks
  end

  delegate :card, to: :eventable
end
```

### Step 3: Create the Eventable Concern

```ruby
# app/models/concerns/eventable.rb
module Eventable
  extend ActiveSupport::Concern

  included do
    has_many :events, as: :eventable, dependent: :destroy
  end

  def track_event(action, creator: Current.user, board: self.board, **particulars)
    if should_track_event?
      board.events.create!(
        action: "#{eventable_prefix}_#{action}",
        creator: creator,
        board: board,
        eventable: self,
        particulars: particulars
      )
    end
  end

  def event_was_created(event)
    # Override in models to react to event creation
  end

  private
    def should_track_event?
      true
    end

    def eventable_prefix
      self.class.name.demodulize.underscore
    end
end
```

### Step 4: Include Eventable in Your Models

```ruby
# app/models/card.rb
class Card < ApplicationRecord
  include Eventable
  
  # Your existing code...
end

# app/models/comment.rb
class Comment < ApplicationRecord
  include Eventable
  
  # Your existing code...
end
```

### Step 5: Track Events in Your Business Logic

```ruby
# Example: Track when a card is closed
class Card < ApplicationRecord
  include Eventable

  def close(user: Current.user)
    transaction do
      update!(status: :closed)
      track_event :closed, creator: user
    end
  end
end

# Example: Track attribute changes
class Card < ApplicationRecord
  after_save :track_title_change, if: :saved_change_to_title?

  private
    def track_title_change
      track_event :title_changed,
        particulars: {
          old_title: title_before_last_save,
          new_title: title
        }
    end
end
```

### Step 6: Create Custom Event Modules (Optional)

For complex models, create a dedicated module:

```ruby
# app/models/card/eventable.rb
module Card::Eventable
  extend ActiveSupport::Concern
  include ::Eventable

  def event_was_created(event)
    # React to events
    touch_last_active_at
  end

  private
    def should_track_event?
      published?  # Only track published cards
    end
end

# Then in your model:
class Card < ApplicationRecord
  include Card::Eventable  # Instead of plain Eventable
end
```

### Step 7: Add Particulars Accessors (Optional)

For typed access to metadata:

```ruby
# app/models/event/particulars.rb
module Event::Particulars
  extend ActiveSupport::Concern

  included do
    store_accessor :particulars, :assignee_ids, :old_title, :new_title
  end

  def assignees
    @assignees ||= User.where(id: assignee_ids)
  end
end

# Include in Event model
class Event < ApplicationRecord
  include Particulars
  # ...
end
```

### Step 8: Query Events

```ruby
# Get all events for a card
card.events.chronologically

# Get events by action
card.events.where(action: "card_assigned")

# Get recent activity
board.events.where("created_at > ?", 1.week.ago).preloaded
```

## Testing

### Fixtures

```yaml
# test/fixtures/events.yml
logo_published:
  id: <%= ActiveRecord::FixtureSet.identify("logo_published", :uuid) %>
  creator: david
  board: main_board
  eventable: logo (Card)
  action: card_published
  created_at: <%= 1.week.ago %>
  account: my_account

logo_assignment:
  id: <%= ActiveRecord::FixtureSet.identify("logo_assignment", :uuid) %>
  creator: david
  board: main_board
  eventable: logo (Card)
  action: card_assigned
  particulars: <%= { assignee_ids: [users(:jane).id] }.to_json %>
  created_at: <%= 1.day.ago %>
  account: my_account
```

### Test Examples

```ruby
# test/models/card/eventable_test.rb
require "test_helper"

class Card::EventableTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
  end

  test "closing a card creates an event" do
    assert_difference -> { @card.events.count } do
      @card.close
    end

    event = @card.events.last
    assert_equal "card_closed", event.action
    assert_equal @card, event.eventable
  end

  test "tracking events update the last activity time" do
    freeze_time
    
    @card.close
    assert_equal Time.current, @card.reload.last_active_at
  end

  test "events are not tracked for unpublished cards" do
    draft_card = cards(:draft)
    
    assert_no_difference -> { draft_card.events.count } do
      draft_card.update(title: "New title")
    end
  end
end
```

## Best Practices

### 1. Transaction Boundaries

Always track events within the same transaction as the state change:

```ruby
def close(user: Current.user)
  transaction do
    create_closure!(user: user)
    track_event :closed, creator: user
  end
end
```

### 2. Conditional Tracking

Use `should_track_event?` to prevent spurious events:

```ruby
def should_track_event?
  published? && !being_destroyed?
end
```

### 3. Consistent Action Naming

Use a consistent naming scheme: `{model}_{action}`
- `card_published`
- `card_closed`
- `comment_created`
- `card_assigned`

### 4. Meaningful Particulars

Store enough context to understand the event later:

```ruby
# Good
track_event :moved,
  particulars: {
    from_column: old_column.name,
    to_column: new_column.name
  }

# Not enough context
track_event :moved
```

### 5. Avoid Over-Tracking

Don't track every attribute change - only meaningful state transitions:

```ruby
# Good: Meaningful state changes
after_save :track_title_change, if: :saved_change_to_title?

# Bad: Too granular
after_save :track_updated_at_change, if: :saved_change_to_updated_at?
```

### 6. Performance Considerations

- Use indexes on commonly queried columns (action, created_at, board_id)
- Consider event archival for old records
- Use `preloaded` scopes to avoid N+1 queries
- Cache event renderings in views

### 7. Testing

- Test event creation in unit tests
- Test event display in view tests
- Use fixtures for consistent test data
- Test conditional tracking logic

## Summary

The Event system pattern provides:

1. **Audit Trail**: Complete history of who did what and when
2. **Notifications**: Automatic user notifications for relevant events
3. **Webhooks**: Integration with external systems
4. **Activity Feeds**: Human-readable activity streams
5. **Flexibility**: Extensible via concerns and polymorphism
6. **Performance**: Optimized with proper indexing and caching

Key implementation steps:
1. Create events table with polymorphic association
2. Create Event model with callbacks
3. Create Eventable concern
4. Include concern in trackable models
5. Call `track_event` in business logic
6. Customize via `should_track_event?` and `event_was_created`
7. Query events for display and reporting

This pattern scales well and provides a solid foundation for event-driven features in Rails applications.
