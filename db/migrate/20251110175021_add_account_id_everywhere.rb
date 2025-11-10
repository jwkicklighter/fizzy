class AddAccountIdEverywhere < ActiveRecord::Migration[8.2]
  def change
    add_column :account_join_codes, :account_id, :integer
    add_column :users, :account_id, :integer
    add_column :boards, :account_id, :integer
    add_column :columns, :account_id, :integer
    add_column :cards, :account_id, :integer
    add_column :steps, :account_id, :integer
    add_column :comments, :account_id, :integer
    add_column :notifications, :account_id, :integer
    add_column :notification_bundles, :account_id, :integer
    add_column :filters, :account_id, :integer
    add_column :events, :account_id, :integer
    add_column :tags, :account_id, :integer
    add_column :webhooks, :account_id, :integer
    add_column :push_subscriptions, :account_id, :integer
  end
end
