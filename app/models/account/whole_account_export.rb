class Account::WholeAccountExport < Account::Export
  private
    def populate_zip(zip)
      export_account(zip)
      export_users(zip)
    end

    def export_account(zip)
      data = account.as_json.merge(
        join_code: account.join_code.as_json,
      )

      add_file_to_zip(zip, "account.json", JSON.pretty_generate(data))
    end

    def export_users(zip)
      account.users.find_each do |user|
        add_file_to_zip(zip, "users/#{user.id}.json", user.export_json)
      end
    end
end
