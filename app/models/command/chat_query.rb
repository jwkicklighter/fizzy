class Command::ChatQuery < Command
  store_accessor :data, :query, :params

  def title
    "Chat query '#{query}'"
  end

  def execute
    response = chat.ask query
    generated_commands = replace_names_with_ids(JSON.parse(response.content)).tap do |commands|
      Rails.logger.info "*** #{commands}"
    end
    build_chat_response_with generated_commands
  end

  private
    def chat
      chat = RubyLLM.chat
      chat.with_instructions(prompt)
    end

    # TODO:
    #   - Don't generate initial /search if not requested. "Assign to JZ" should
    def prompt
      <<~PROMPT
        You are Fizzy’s command translator. Read the user’s request, consult the current view, and output 
        a **single JSON array** of command objects. Return nothing except that JSON.

        Fizzy data includes cards and comments contained in those. A card can represent an issue, a feature,
        a bug, a task, etc.
 
        ## Current context:

        The user is currently #{context.viewing_card_contents? ? 'inside a card' : 'viewing a list of cards' }.

        ## Supported commands:

        - Assign users to cards: /assign [user]. E.g: "/assign kevin"
        - Close cards: /close [optional reason]. E.g: "/close" or "/close not now"
        - Tag cards: /tag [tag-name]. E.g: "/tag performance"
        - Clear filters: /clear
        - Get insight about cards: /insight [query]. Use this as the default command to satisfy questions and requests
            about cards. This relies on /search. Example: "/insight summarize performance issues".
        - Search cards based on certain keywords: /search. It supports the following parameters:
          * assignment_status: can be "unassigned". Only include if asking for unassigned cards explicitly
          * indexed_by: can be "newest", "oldest", "latest", "stalled", "closed"
          * engagement_status: can be "considering" or "doing".
          * card_ids: a list of card ids
          * assignee_ids: a list of assignee names
          * creator_id: the name of a person
          * collection_ids: a list of collection names. Cards are contained in collections. Don't use unless mentioning
              specific collections.
          * tag_ids: a list of tag names.
          * terms: a list of terms to search for. Use this option to refine searches based on further keyword*based
             queries.

        ## How to translate requests into commands

        1. Determine if you have the right context based on the "current context":
          - If it is is "inside a card", assume you are in the right context unless the
            query is clearly referring to a different set of cards.
          - If it is "viewing a list of cards", consider emitting a /search command to filter the cards.

        2. Create the sequence of commands to satisfy the user's request.
          - If the request is just about finding some cards, a /search command is enough.
          - If the request is about answering some question about cards, add an /insight command.
          - If the request requires acting on cards, add the sequence of commands that satisfy those. You can combine
            all of them except /search and /insight, which have an special consideration.

       ## JSON format

        Each command will be a JSON object like:

        { command: "/close" }

        Only the /search command can contain additional keys for the params in the JSON:

        { command: "/search", indexed_by: "closed", collection_ids: [ "Writebook", "Design" ] }

        The rest of commands will only have a "command" key, nothing else.

        The output will be a single list of JSON objects. Make sure to place values in double quotes and
        that you generate valid JSON.

        # Other

        * Avoid empty preambles like "Based on the provided cards". Be friendly, favor an active voice.
      PROMPT
    end

    def replace_names_with_ids(commands)
      commands.each do |command|
        if command["command"] == "/search"
          command["assignee_ids"] = command["assignee_ids"]&.filter_map { |name| assignee_from(name)&.id }
          command["creator_id"] = assignee_from(command["creator_id"])&.id if command["creator_id"]
          command["collection_ids"] = command["collection_ids"]&.filter_map { |name| Collection.where("lower(name) = ?", name.downcase).first&.id }
          command["tag_ids"] = command["tag_ids"]&.filter_map { |name| ::Tag.find_by_title(name)&.id }
          command.compact!
        end
      end
    end

    def assignee_from(string)
      string_without_at = string.delete_prefix("@")
      User.all.find { |user| user.mentionable_handles.include?(string_without_at) }
    end

    def build_chat_response_with(generated_commands)
      Command::Result::ChatResponse.new \
        command_lines: response_command_lines_from(generated_commands),
        context_url: response_context_url_from(generated_commands)
    end

    def response_command_lines_from(generated_commands)
      # We translate standalone /search commands as redirections to execute. Otherwise, they
      # will be excluded out from the commands to run, as they represent the context url.
      #
      # TODO: Tidy up this.
      if generated_commands.size == 1 && generated_commands.find { it["command"] == "/search" }
        [ "/visit #{cards_path(**generated_commands.first.without("command"))}" ]
      else
        generated_commands.filter { it["command"] != "/search" }.collect { it["command"] }
      end
    end

    def response_context_url_from(generated_commands)
      if generated_commands.size > 1 && search_command = generated_commands.find { it["command"] == "/search" }
        cards_path(**search_command.without("command"))
      end
    end
end
