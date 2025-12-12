class AddTypeToAccountExports < ActiveRecord::Migration[8.2]
  def change
    add_column :account_exports, :type, :string
  end
end
