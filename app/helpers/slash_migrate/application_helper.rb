module SlashMigrate
  module ApplicationHelper
    # Inline 16px SVG icons, ported from the design's stroke set. Returned with
    # width/height of 1em so they scale with surrounding text; per-context CSS
    # (.btn svg, .nav-link svg, …) overrides the size where needed.
    ICON_PATHS = {
      database: %(<ellipse cx="8" cy="3.5" rx="5.5" ry="2"/><path d="M2.5 3.5v9c0 1.1 2.46 2 5.5 2s5.5-.9 5.5-2v-9"/><path d="M2.5 8c0 1.1 2.46 2 5.5 2s5.5-.9 5.5-2"/>),
      plus: %(<path d="M8 3v10M3 8h10"/>),
      arrow_right: %(<path d="M3 8h10M9 4l4 4-4 4"/>),
      arrow_left: %(<path d="M13 8H3M7 4L3 8l4 4"/>),
      chevron: %(<path d="M6 4l4 4-4 4"/>),
      history: %(<path d="M2.5 8a5.5 5.5 0 1 0 1.6-3.9"/><path d="M2 2v3h3"/><path d="M8 5v3.5l2 1.2"/>),
      info: %(<circle cx="8" cy="8" r="6"/><path d="M8 7.2v3.6M8 5.2v.01"/>),
      warn: %(<path d="M8 2.5l6 11H2l6-11Z"/><path d="M8 6.5v3M8 11.4v.01"/>),
      check: %(<path d="M3 8.5l3.5 3.5L13 5"/>),
      x: %(<path d="M4 4l8 8M12 4l-8 8"/>),
      trash: %(<path d="M3 4.5h10M6.5 4.5V3a1 1 0 0 1 1-1h1a1 1 0 0 1 1 1v1.5M5 4.5l.5 8a1 1 0 0 0 1 .9h3a1 1 0 0 0 1-.9l.5-8"/>),
      play: %(<path d="M5 3.5v9l8-4.5z"/>),
      rotate: %(<path d="M13.5 8a5.5 5.5 0 1 1-1.6-3.9"/><path d="M14 2v3h-3"/>),
      file: %(<path d="M9 1.5H4.5A1.5 1.5 0 0 0 3 3v10a1.5 1.5 0 0 0 1.5 1.5h7A1.5 1.5 0 0 0 13 13V5.5z"/><path d="M9 1.5V5.5H13"/>),
      terminal: %(<rect x="2" y="3" width="12" height="10" rx="1.5"/><path d="M5 7l2 1.5L5 10M8.5 10h2.5"/>),
      key: %(<circle cx="6" cy="10" r="3"/><path d="M8.1 7.9 13 3M11 5l2 2M9.5 6.5L11.5 8.5"/>),
      lock: %(<rect x="3.5" y="7" width="9" height="6.5" rx="1.5"/><path d="M5.5 7V5.2a2.5 2.5 0 0 1 5 0V7"/>)
    }.freeze
    FILLED_ICONS = %i[play].freeze

    def sm_icon(name)
      name = name.to_sym
      inner = ICON_PATHS.fetch(name)
      head =
        if FILLED_ICONS.include?(name)
          %(<svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">)
        else
          %(<svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">)
        end
      (head + inner + "</svg>").html_safe
    end

    # A top-nav link with its icon and active state.
    def nav_link(label, url, icon, active: false)
      link_to url, class: "nav-link#{" is-active" if active}" do
        safe_join([sm_icon(icon), label], " ")
      end
    end

    # The column types worth showing first, in teaching order. Anything else the
    # database supports follows, alphabetically.
    COMMON_COLUMN_TYPES = %w[string text integer boolean references datetime date decimal float].freeze

    # The column types this app's database actually supports, read from the
    # adapter (so Postgres surfaces uuid/jsonb/etc., SQLite its smaller set), with
    # the everyday types pinned to the top. `references` is a Rails association
    # helper rather than a native type, so it's added unless asked otherwise
    # (change_column can't target it). Note: virtual types a gem adds via the
    # table-definition API — e.g. money-rails' monetize — aren't reported here.
    def available_column_types(include_references: true)
      native = ActiveRecord::Base.connection.native_database_types.keys.map(&:to_s) - ["primary_key"]
      native << "references" if include_references
      native.uniq!
      common = COMMON_COLUMN_TYPES.select { |type| native.include?(type) }
      common + (native - common).sort
    end

    # The 14-digit UTC version a migration generated right now would carry. Shown
    # in preview filenames and ticked forward each second client-side, so students
    # see where that number comes from.
    def migration_version
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    end

    # Which nav item to highlight, derived from the controller handling the request.
    def nav_section
      case controller_name
      when "models" then :new
      when "migrations" then :migrations
      else :tables # tables, columns, indexes all live under "Tables"
      end
    end

    # Renders Ruby source as the syntax-highlighted lines of a `.code-body`. A
    # small, purpose-built tokenizer — enough to colour migrations and models,
    # not a general Ruby parser.
    def ruby_code_body(source)
      lines = source.to_s.split("\n", -1)
      lines.pop if lines.last == "" # trailing newline shouldn't draw a blank line
      rendered = lines.map { |line| "<span>#{highlight_ruby_line(line)}</span>" }.join
      %(<div class="code-lines">#{rendered}</div>).html_safe
    end

    # Renders raw command output as plain monochrome lines (no gutter, no tinting)
    # — the way a real terminal shows it.
    def terminal_body(output)
      lines = output.to_s.split("\n", -1)
      lines.pop if lines.last == ""
      rendered = lines.map { |line| "<span>#{line.empty? ? "&nbsp;" : ERB::Util.html_escape(line)}</span>" }.join
      %(<div class="code-lines">#{rendered}</div>).html_safe
    end

    private

    RUBY_KEYWORDS = %w[
      class def end if elsif else unless do return nil true false module
      up down change
    ].freeze
    RUBY_METHODS = %w[
      create_table add_column remove_column change_column rename_column rename_table
      add_reference remove_reference add_index remove_index drop_table change_table
      add_foreign_key remove_foreign_key change_column_null change_column_default execute
      belongs_to has_many has_one validates references string text integer bigint
      float decimal boolean date datetime time timestamps binary json
      null default limit precision scale index unique foreign_key to_table from to comment
    ].freeze
    RUBY_TOKEN = %r{
      "(?:[^"\\]|\\.)*"      # double-quoted string
      |'(?:[^'\\]|\\.)*'     # single-quoted string
      |:[a-z_]\w*            # symbol
      |[A-Z][\w:]*           # constant or class name
      |[a-z_]\w*[?!]?        # identifier or method
      |\d+\.\d+              # float
      |\d+                   # integer
      |\#.*                  # comment to end of line
      |[^\s\w]               # punctuation
    }x

    def highlight_ruby_line(line)
      return "&nbsp;" if line.empty?

      leading = line[/\A\s*/]
      rest = line[leading.length..]
      out = +""
      out << ERB::Util.html_escape(leading) unless leading.empty?
      return out + span("cm", rest) if rest.start_with?("#")

      last = 0
      rest.scan(RUBY_TOKEN) do
        token = Regexp.last_match[0]
        start = Regexp.last_match.begin(0)
        out << ERB::Util.html_escape(rest[last...start]) if start > last
        out << span(ruby_token_class(token), token)
        last = Regexp.last_match.end(0)
      end
      out << ERB::Util.html_escape(rest[last..]) if last < rest.length
      out
    end

    def ruby_token_class(token)
      case token
      when /\A["']/ then "s"
      when /\A:/ then "sy"
      when /\A#/ then "cm"
      when /\A\d/ then "n"
      when /\A[A-Z]/ then "c"
      else
        if RUBY_KEYWORDS.include?(token)
          "k"
        elsif RUBY_METHODS.include?(token)
          "m"
        else
          "p"
        end
      end
    end

    def span(klass, text)
      %(<em class="tk-#{klass}">#{ERB::Util.html_escape(text)}</em>)
    end
  end
end
