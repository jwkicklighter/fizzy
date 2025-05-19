module FiltersHelper
  def filter_title(filter)
    if filter.collections.none?
      Current.user.collections.one? ? Current.user.collections.first.name : "All collections"
    elsif filter.collections.one?
      filter.collections.first.name
    else
      filter.collections.map(&:name).to_sentence
    end
  end

  def filter_chip_tag(text, params)
    link_to cards_path(params), class: "btn txt-x-small btn--remove fill-selected flex-inline" do
      concat tag.span(text)
      concat icon_tag("close")
    end
  end

  def filter_hidden_field_tag(key, value)
    name = params[key].is_a?(Array) ? "#{key}[]" : key
    hidden_field_tag name, value, id: nil
  end

  def filter_selected_collections_label(filter)
    selected_collections = if filter.collections.any?
      filter.collections.collect { "<strong>#{it.name}</strong>" }.uniq.sort.to_sentence
    else
      "all collections"
    end

    "Activity in #{selected_collections}".html_safe
  end

  def any_filters?(filter)
    filter.tags.any? || filter.assignees.any? || filter.creators.any? ||
      filter.stages.any? || filter.terms.any? ||
      filter.assignment_status.unassigned?
  end
end
