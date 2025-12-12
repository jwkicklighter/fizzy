class Account::WholeAccountExport < Account::Export
  private
    def generate_zip
      Tempfile.new([ "export", ".zip" ]).tap do |tempfile|
        Zip::File.open(tempfile.path, create: true) do |zip|
          export_account(zip)
          export_users(zip)
          export_boards(zip)
          export_columns(zip)
          export_cards(zip)
          export_steps(zip)
          export_comments(zip)
          export_action_text_rich_texts(zip)
          export_active_storage_attachments(zip)
          export_active_storage_blobs(zip)
        end
      end
    end
end
