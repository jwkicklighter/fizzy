module Filter::Resources
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :tags
    has_and_belongs_to_many :buckets
    has_and_belongs_to_many :assignees, class_name: "User", join_table: "assignees_filters", association_foreign_key: "assignee_id"
  end

  def resource_removed(resource)
    kind = resource.class.model_name.plural
    send("#{kind}=", send(kind).without(resource))
    sanitize_params
    params.blank? ? destroy! : save!
  end

  private
    # `denormalize_resource_ids` stores resource ids in the params column to
    #    1) enforce uniqueness via db constraints
    #    2) easily turn all filter params into a query string
    def denormalize_resource_ids
      params["bucket_ids"] = buckets.ids
      params["tag_ids"] = tags.ids
      params["assignee_ids"] = assignees.ids
    end
end
