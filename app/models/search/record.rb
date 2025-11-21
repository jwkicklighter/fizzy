class Search::Record < ApplicationRecord
  include const_get(connection.adapter_name)

  belongs_to :searchable, polymorphic: true
  belongs_to :card

  # Virtual attributes from search query
  attribute :query, :string

  validates :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :created_at, presence: true

  class << self
    def card_join
      "INNER JOIN #{table_name} ON #{table_name}.card_id = cards.id"
    end
  end

  scope :for_query, ->(query:, user:) do
    if query.valid? && user.board_ids.any?
      matching(query.to_s, user.account_id).for_user(user)
    else
      none
    end
  end

  scope :matching, ->(query) do
    matching_scope(query)
  end

  scope :for_user, ->(user) do
    where(account_id: user.account_id, board_id: user.board_ids)
  end

  scope :search, ->(query:, user:) do
    relation = for_query(query: query, user: user)
      .includes(:searchable, card: [ :board, :creator ])
      .order(created_at: :desc)

    search_scope(relation, query)
  end

  def source
    searchable_type == "Comment" ? searchable : card
  end

  def comment
    searchable if searchable_type == "Comment"
  end
end
