module Mcp
  module Tools
    class CreateCard < Mcp::Tool
      class << self
        def tool_name
          "create_card"
        end

        def description
          "Create a new card on a board"
        end

        def input_schema
          {
            type: "object",
            properties: {
              board_id: {
                type: "string",
                description: "The ID of the board to create the card on"
              },
              title: {
                type: "string",
                description: "The title of the card"
              },
              description: {
                type: "string",
                description: "The description of the card (optional)"
              }
            },
            required: [ "board_id", "title" ]
          }
        end

        def call(arguments)
          board = Current.user.boards.find_by(id: arguments["board_id"])

          if board.nil?
            return error_result("Board not found: #{arguments["board_id"]}")
          end

          card = board.cards.create!(
            title: arguments["title"],
            description: arguments["description"],
            creator: Current.user,
            status: "published"
          )

          text_result("Created card ##{card.number}: #{card.title}")
        rescue ActiveRecord::RecordInvalid => e
          error_result("Failed to create card: #{e.message}")
        end
      end
    end
  end
end
