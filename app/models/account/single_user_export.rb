class Account::SingleUserExport < Account::Export
  private
    def generate_zip
      Tempfile.new([ "export", ".zip" ]).tap do |tempfile|
        Zip::File.open(tempfile.path, create: true) do |zip|
          exportable_cards.find_each do |card|
            add_card_to_zip(zip, card)
          end
        end
      end
    end

    def exportable_cards
      user.accessible_cards.includes(
        :board,
        creator: :identity,
        comments: { creator: :identity },
        rich_text_description: { embeds_attachments: :blob }
      )
    end

    def add_card_to_zip(zip, card)
      zip.get_output_stream("#{card.number}.json") do |f|
        f.write(card.export_json)
      end

      card.export_attachments.each do |attachment|
        zip.get_output_stream(attachment[:path], compression_method: Zip::Entry::STORED) do |f|
          attachment[:blob].download { |chunk| f.write(chunk) }
        end
      rescue ActiveStorage::FileNotFoundError
        # Skip attachments where the file is missing from storage
      end
    end
end
