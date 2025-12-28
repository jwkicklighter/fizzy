class McpController < ActionController::Base
  skip_forgery_protection

  before_action :authenticate_by_bearer_token

  def show
    head :method_not_allowed
  end

  def create
    response = handle_message(parsed_request_body)

    if response
      render json: response, content_type: "application/json"
    else
      head :accepted
    end
  rescue JSON::ParserError
    render json: jsonrpc_error(nil, -32700, "Parse error"), status: :bad_request
  end

  private
    def authenticate_by_bearer_token
      if token = extract_bearer_token
        if identity = Identity.find_by_permissable_access_token(token, method: "POST")
          Current.identity = identity
        end
      else
        head :unauthorized
      end
    end

    def extract_bearer_token
      request.authorization.to_s[/\ABearer (.+)\z/, 1]
    end

    def parsed_request_body
      JSON.parse(request.body.read)
    end

    def handle_message(message)
      case message["method"]
      when "initialize"                then handle_initialize(message)
      when "notifications/initialized" then nil
      when "tools/list"                then handle_tools_list(message)
      when "tools/call"                then handle_tools_call(message)
      else
        jsonrpc_error(message["id"], -32601, "Method not found")
      end
    end

    def handle_initialize(message)
      jsonrpc_response(message["id"], Mcp::Server.initialize_result)
    end

    def handle_tools_list(message)
      jsonrpc_response(message["id"], { tools: Mcp::Server.tools })
    end

    def handle_tools_call(message)
      params = message["params"] || {}
      tool_name = params["name"]
      arguments = params["arguments"] || {}

      tool_class = Mcp::Server.find_tool(tool_name)

      if tool_class.nil?
        return jsonrpc_error(message["id"], -32602, "Unknown tool: #{tool_name}")
      end

      result = tool_class.call(arguments)
      jsonrpc_response(message["id"], result)
    end

    def jsonrpc_response(id, result)
      { jsonrpc: "2.0", id: id, result: result }
    end

    def jsonrpc_error(id, code, message)
      { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
    end
end
