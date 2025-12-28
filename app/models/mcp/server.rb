module Mcp
  class Server
    PROTOCOL_VERSION = "2024-11-05"
    SERVER_NAME = "fizzy"
    SERVER_VERSION = "1.0.0"

    TOOLS = [
      Mcp::Tools::CreateCard,
      Mcp::Tools::CloseCard
    ].freeze

    class << self
      def initialize_result
        {
          protocolVersion: PROTOCOL_VERSION,
          capabilities: { tools: {} },
          serverInfo: {
            name: SERVER_NAME,
            version: SERVER_VERSION
          }
        }
      end

      def tools
        TOOLS.map(&:definition)
      end

      def find_tool(name)
        TOOLS.find { |t| t.tool_name == name }
      end
    end
  end
end
