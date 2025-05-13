module EventsHelper
  def event_columns(event_type, day_timeline)
    case event_type
    when "added"
      events = day_timeline.events.where(action: "card_published")
      {
        title: events.count > 0 ? "Added (#{events.count})" : "Added",
        index: 1,
        events: events
      }
    when "closed"
      events = day_timeline.events.where(action: "card_closed")
      {
        title: events.count > 0 ? "Closed (#{events.count})" : "Closed",
        index: 3,
        events: events
      }
    else
      {
        title: "Updated",
        index: 2,
        events: day_timeline.events.where.not(action: [ "card_published", "card_closed" ])
      }
    end
  end

  def event_column(event)
    case event.action
    when "card_closed"
      3
    when "card_published"
      1
    else
      2
    end
  end

  def event_cluster_tag(hour, col, &)
    row = 25 - hour
    tag.ul class: "events__time-block", style: "grid-area: #{row}/#{col}", &
  end

  def event_next_page_link(next_day)
    if next_day
      tag.div id: "next_page",
        data: { controller: "fetch-on-visible", fetch_on_visible_url_value: events_days_path(day: next_day.strftime("%Y-%m-%d")) }
    end
  end

  def event_action_sentence(event)
    if event.action.comment_created?
      comment_event_action_sentence(event)
    else
      card_event_action_sentence(event)
    end
  end

  def comment_event_action_sentence(event)
    "#{ event_creator_name(event) } commented on <span style='color: var(--card-color)'>#{ event.eventable.card.title }</span>".html_safe
  end

  def event_creator_name(event)
    event.creator == Current.user ? "You" : event.creator.name
  end

  def card_event_action_sentence(event)
    card = event.eventable
    title = card.title

    case event.action
    when "card_assigned"
      if event.assignees.include?(Current.user)
        "#{ event_creator_name(event) } will handle <span style='color: var(--card-color)'>#{ title }</span>".html_safe
      else
        "#{ event_creator_name(event) } assigned #{ event.assignees.pluck(:name).to_sentence } to <span style='color: var(--card-color)'>#{ title }</span>".html_safe
      end
    when "card_unassigned"
      "#{ event_creator_name(event) } unassigned #{ event.assignees.include?(Current.user) ? "yourself" : event.assignees.pluck(:name).to_sentence } from <span style='color: var(--card-color)'>#{ title }</span>".html_safe
    when "card_published"
      "#{ event_creator_name(event) } added <span style='color: var(--card-color)'>#{ title }</span>".html_safe
    when "card_closed"
      "#{ event_creator_name(event) } closed <span style='color: var(--card-color)'>#{ title }</span>".html_safe
    when "card_staged"
      "#{event_creator_name(event)} moved <span style='color: var(--card-color)'>#{ title }</span> to the #{event.stage_name} stage".html_safe
    when "card_unstaged"
      "#{event_creator_name(event)} moved <span style='color: var(--card-color)'>#{ title }</span> out ofthe #{event.stage_name} stage".html_safe
    when "card_due_date_added"
      "#{event_creator_name(event)} set the date to #{event.particulars.dig('particulars', 'due_date').to_date.strftime('%B %-d')} on <span style='color: var(--card-color)'>#{ title }</span>".html_safe
    when "card_due_date_changed"
      "#{event_creator_name(event)} changed the date to #{event.particulars.dig('particulars', 'due_date').to_date.strftime('%B %-d')} on <span style='color: var(--card-color)'>#{ title }</span>".html_safe
    when "card_due_date_removed"
      "#{event_creator_name(event)} removed the date on <span style='color: var(--card-color)'>#{ title }</span>"
    when "card_title_changed"
      "#{event_creator_name(event)} renamed <span style='color: var(--card-color)'>#{ title }</span> (was: '#{event.particulars.dig('particulars', 'old_title')})'".html_safe
    end
  end

  def event_action_icon(event)
    case event.action
    when "card_assigned"
      "assigned"
    when "card_staged"
      "bolt"
    when "card_unstaged"
      "bolt"
    when "comment_created"
      "comment"
    when "card_title_changed"
      "rename"
    else
      "person"
    end
  end
end
