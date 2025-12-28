module Mcp
  module Tools
    class CloseCard < Mcp::Tool
      class << self
        def tool_name
          "close_card"
        end

        def description
          "Close a card"
        end

        def input_schema
          {
            type: "object",
            properties: {
              card_number: {
                type: "integer",
                description: "The number of the card to close"
              }
            },
            required: [ "card_number" ]
          }
        end

        def call(arguments)
          card = Current.user.accessible_cards.find_by(number: arguments["card_number"])

          if card.nil?
            return error_result("Card not found: ##{arguments["card_number"]}")
          end

          if card.closed?
            return error_result("Card ##{card.number} is already closed")
          end

          card.close(user: Current.user)
          text_result("Closed card ##{card.number}: #{card.title}")
        end
      end
    end
  end
end
