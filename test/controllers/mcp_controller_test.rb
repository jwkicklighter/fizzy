require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @access_token = identity_access_tokens(:davids_api_token)
    @board = boards(:writebook)
    @card = cards(:logo)
  end

  # Authentication tests

  test "returns unauthorized without bearer token" do
    post mcp_path, params: jsonrpc_request("initialize").to_json, headers: json_headers
    assert_response :unauthorized
  end

  test "returns unauthorized with invalid bearer token" do
    post mcp_path, params: jsonrpc_request("initialize").to_json, headers: json_headers.merge(auth_header("invalid_token"))
    assert_response :unauthorized
  end

  test "returns unauthorized when user not in account" do
    # Use a different account scope where David doesn't have a user
    integration_session.default_url_options[:script_name] = "/#{ActiveRecord::FixtureSet.identify("initech")}"

    post mcp_path, params: jsonrpc_request("initialize").to_json, headers: json_headers.merge(auth_header(@access_token.token))
    assert_response :unauthorized
  end

  # Initialize tests

  test "initialize returns server info and capabilities" do
    post mcp_path, params: jsonrpc_request("initialize", id: 1).to_json, headers: authenticated_headers

    assert_response :success
    response = JSON.parse(@response.body)

    assert_equal "2.0", response["jsonrpc"]
    assert_equal 1, response["id"]
    assert_equal "2024-11-05", response.dig("result", "protocolVersion")
    assert_equal "fizzy", response.dig("result", "serverInfo", "name")
    assert response.dig("result", "capabilities", "tools").is_a?(Hash)
  end

  # Notifications

  test "initialized notification returns accepted with no body" do
    post mcp_path, params: jsonrpc_request("notifications/initialized").to_json, headers: authenticated_headers

    assert_response :accepted
    assert_empty @response.body
  end

  # Tools list

  test "tools/list returns available tools" do
    post mcp_path, params: jsonrpc_request("tools/list", id: 2).to_json, headers: authenticated_headers

    assert_response :success
    response = JSON.parse(@response.body)

    assert_equal 2, response["id"]
    tools = response.dig("result", "tools")
    assert_equal 2, tools.size

    tool_names = tools.map { |t| t["name"] }
    assert_includes tool_names, "create_card"
    assert_includes tool_names, "close_card"

    create_card_tool = tools.find { |t| t["name"] == "create_card" }
    assert_equal "Create a new card on a board", create_card_tool["description"]
    assert create_card_tool["inputSchema"].present?
  end

  # Create card tool

  test "tools/call create_card creates a card" do
    assert_difference -> { Card.count }, 1 do
      post mcp_path, params: jsonrpc_request("tools/call", id: 3, params: {
        name: "create_card",
        arguments: {
          board_id: @board.id,
          title: "New card from MCP",
          description: "Created via MCP protocol"
        }
      }).to_json, headers: authenticated_headers
    end

    assert_response :success
    response = JSON.parse(@response.body)

    assert_equal 3, response["id"]
    assert_equal false, response.dig("result", "isError")

    content = response.dig("result", "content")
    assert_equal 1, content.size
    assert_equal "text", content.first["type"]
    assert_match(/Created card #\d+: New card from MCP/, content.first["text"])

    card = Card.last
    assert_equal "New card from MCP", card.title
    assert_equal "Created via MCP protocol", card.description.to_plain_text
    assert_equal users(:david), card.creator
    assert card.published?
  end

  test "tools/call create_card returns error for invalid board" do
    post mcp_path, params: jsonrpc_request("tools/call", id: 4, params: {
      name: "create_card",
      arguments: {
        board_id: "nonexistent",
        title: "Should fail"
      }
    }).to_json, headers: authenticated_headers

    assert_response :success
    response = JSON.parse(@response.body)

    assert_equal true, response.dig("result", "isError")
    assert_match(/Board not found/, response.dig("result", "content", 0, "text"))
  end

  # Close card tool

  test "tools/call close_card closes a card" do
    assert @card.open?

    post mcp_path, params: jsonrpc_request("tools/call", id: 5, params: {
      name: "close_card",
      arguments: { card_number: @card.number }
    }).to_json, headers: authenticated_headers

    assert_response :success
    response = JSON.parse(@response.body)

    assert_equal false, response.dig("result", "isError")
    assert_match(/Closed card ##{@card.number}/, response.dig("result", "content", 0, "text"))

    assert @card.reload.closed?
  end

  test "tools/call close_card returns error for nonexistent card" do
    post mcp_path, params: jsonrpc_request("tools/call", id: 6, params: {
      name: "close_card",
      arguments: { card_number: 99999 }
    }).to_json, headers: authenticated_headers

    assert_response :success
    response = JSON.parse(@response.body)

    assert_equal true, response.dig("result", "isError")
    assert_match(/Card not found/, response.dig("result", "content", 0, "text"))
  end

  test "tools/call close_card returns error for already closed card" do
    @card.close(user: users(:david))
    assert @card.closed?

    post mcp_path, params: jsonrpc_request("tools/call", id: 7, params: {
      name: "close_card",
      arguments: { card_number: @card.number }
    }).to_json, headers: authenticated_headers

    assert_response :success
    response = JSON.parse(@response.body)

    assert_equal true, response.dig("result", "isError")
    assert_match(/already closed/, response.dig("result", "content", 0, "text"))
  end

  # Error handling

  test "unknown method returns error" do
    post mcp_path, params: jsonrpc_request("unknown/method", id: 8).to_json, headers: authenticated_headers

    assert_response :success
    response = JSON.parse(@response.body)

    assert_equal 8, response["id"]
    assert_equal(-32601, response.dig("error", "code"))
    assert_equal "Method not found", response.dig("error", "message")
  end

  test "unknown tool returns error" do
    post mcp_path, params: jsonrpc_request("tools/call", id: 9, params: {
      name: "unknown_tool",
      arguments: {}
    }).to_json, headers: authenticated_headers

    assert_response :success
    response = JSON.parse(@response.body)

    assert_equal(-32602, response.dig("error", "code"))
    assert_match(/Unknown tool/, response.dig("error", "message"))
  end

  test "invalid JSON returns parse error" do
    post mcp_path, params: "{ invalid json }", headers: authenticated_headers

    assert_response :bad_request
    response = JSON.parse(@response.body)

    assert_equal(-32700, response.dig("error", "code"))
    assert_equal "Parse error", response.dig("error", "message")
  end

  private
    def jsonrpc_request(method, id: nil, params: nil)
      request = { jsonrpc: "2.0", method: method }
      request[:id] = id if id
      request[:params] = params if params
      request
    end

    def json_headers
      { "Content-Type" => "application/json" }
    end

    def auth_header(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def authenticated_headers
      json_headers.merge(auth_header(@access_token.token))
    end
end
