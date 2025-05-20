require "test_helper"

# The parser is tested through the tests of specific commands. See +Command::AssignTests+, etc.
class Command::ParserTest < ActionDispatch::IntegrationTest
  include CommandTestHelper, VcrTestHelper

  test "the parsed command contains the raw line" do
    result = parse_command "assign @kevin"
    assert_equal "assign @kevin", result.line
  end
end
