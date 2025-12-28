module Mcp
  class Tool
    class << self
      def tool_name
        raise NotImplementedError
      end

      def description
        raise NotImplementedError
      end

      def input_schema
        raise NotImplementedError
      end

      def definition
        {
          name: tool_name,
          description: description,
          inputSchema: input_schema
        }
      end

      def call(arguments)
        raise NotImplementedError
      end

      private
        def text_result(text)
          { content: [ { type: "text", text: text } ], isError: false }
        end

        def error_result(text)
          { content: [ { type: "text", text: text } ], isError: true }
        end
    end
  end
end
