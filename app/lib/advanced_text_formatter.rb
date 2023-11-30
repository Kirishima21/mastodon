# frozen_string_literal: true

class AdvancedTextFormatter < TextFormatter
  class HTMLRenderer < Redcarpet::Render::HTML
    def initialize(options, &block)
      super(options)
      @format_link = block
    end

    def block_code(code, _language)
      <<~HTML
        <pre><code>#{ERB::Util.h(code).gsub("\n", '<br/>')}</code></pre>
      HTML
    end

    def autolink(link, link_type)
      return link if link_type == :email

      @format_link.call(link)
    end
  end

  attr_reader :content_type

  # @param [String] text
  # @param [Hash] options
  # @option options [Boolean] :multiline
  # @option options [Boolean] :with_domains
  # @option options [Boolean] :with_rel_me
  # @option options [Array<Account>] :preloaded_accounts
  # @option options [String] :content_type
  def initialize(text, options = {})
    @content_type = options.delete(:content_type)
    super(text, options)

    @text = avoid_bbcode(text)
    @text = format_markdown(text) if content_type == 'text/markdown'
    @text = format_bbcode(@text)

  end

  # Differs from TextFormatter by not messing with newline after parsing
  def to_s
    return ''.html_safe if text.blank?

    html = rewrite do |entity|
      if entity[:url]
        link_to_url(entity)
      elsif entity[:hashtag]
        link_to_hashtag(entity)
      elsif entity[:screen_name]
        link_to_mention(entity)
      end
    end

    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  # Differs from TextFormatter by operating on the parsed HTML tree
  def rewrite
    if @tree.nil?
      src = text.gsub(Sanitize::REGEX_UNSUITABLE_CHARS, '')
      @tree = Nokogiri::HTML5.fragment(src)
      document = @tree.document

      @tree.xpath('.//text()[not(ancestor::a | ancestor::code)]').each do |text_node|
        # Iterate over text elements and build up their replacements.
        content = text_node.content
        replacement = Nokogiri::XML::NodeSet.new(document)
        processed_index = 0
        Extractor.extract_entities_with_indices(
          content,
          extract_url_without_protocol: false
        ) do |entity|
          # Iterate over entities in this text node.
          advance = entity[:indices].first - processed_index
          if advance.positive?
            # Text node for content which precedes entity.
            replacement << Nokogiri::XML::Text.new(
              content[processed_index, advance],
              document
            )
          end
          replacement << Nokogiri::HTML5.fragment(yield(entity))
          processed_index = entity[:indices].last
        end
        if processed_index < content.size
          # Text node for remaining content.
          replacement << Nokogiri::XML::Text.new(
            content[processed_index, content.size - processed_index],
            document
          )
        end
        text_node.replace(replacement)
      end
    end

    Sanitize.node!(@tree, Sanitize::Config::MASTODON_OUTGOING).to_html
  end

  private

  def format_markdown(html)
    html = markdown_formatter.render(html)
    html.delete("\r").delete("\n")
  end

  def markdown_formatter
    extensions = {
      autolink: true,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      disable_indented_code_blocks: true,
      strikethrough: true,
      lax_spacing: true,
      space_after_headers: true,
      superscript: true,
      underline: true,
      highlight: true,
      footnotes: false,
    }

    renderer = HTMLRenderer.new({
      filter_html: false,
      escape_html: false,
      no_images: true,
      no_styles: true,
      safe_links_only: true,
      hard_wrap: true,
      link_attributes: { target: '_blank', rel: 'nofollow noopener' },
    }) do |url|
      link_to_url({ url: url })
    end

    Redcarpet::Markdown.new(renderer, extensions)
  end

  def format_bbcode(html)
    begin
      html = html.bbcode_to_html(false, {
        :spin => {
          :html_open => '<span class="fa fa-spin">', :html_close => '</span>',
          :description => 'Make text spin',
          :example => 'This is [spin]spin[/spin].'},
        :pulse => {
          :html_open => '<span class="bbcode-pulse-loading">', :html_close => '</span>',
          :description => 'Make text pulse',
          :example => 'This is [pulse]pulse[/pulse].'},
        :b => {
          :html_open => '<span style="font-family: \'kozuka-gothic-pro\', sans-serif; font-weight: 900;">', :html_close => '</span>',
          :description => 'Make text bold',
          :example => 'This is [b]bold[/b].'},
        :i => {
          :html_open => '<span style="font-family: \'kozuka-gothic-pro\', sans-serif; font-style: italic; -moz-font-feature-settings: \'ital\'; -webkit-font-feature-settings: \'ital\'; font-feature-settings: \'ital\';">', :html_close => '</span>',
          :description => 'Make text italic',
          :example => 'This is [i]italic[/i].'},
        :flip => {
          :html_open => '<span class="fa fa-flip-%direction%">', :html_close => '</span>',
          :description => 'Flip text',
          :example => '[flip=horizontal]This is flip[/flip]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /(horizontal|vertical)/,
          :quick_param_format_description => 'The size parameter \'%param%\' is incorrect, a number is expected',
          :param_tokens => [{:token => :direction}]},
        :marq => {
          :html_open => '<span class="marquee"><span class="bbcode-marq-%vector%">', :html_close => '</span></span>',
          :description => 'Make text marquee',
          :example => '[marq=lateral]marquee[/marq].',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /(lateral|vertical)/,
          :quick_param_format_description => 'The size parameter \'%param%\' is incorrect, a number is expected',
          :param_tokens => [{:token => :vector}]},
        :large => {
          :html_open => '<span class="fa fa-%size%">', :html_close => '</span>',
          :description => 'Large text',
          :example => '[large=2x]Large text[/large]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /(2x|3x|4x|5x|ex)/,
          :quick_param_format_description => 'The size parameter \'%param%\' is incorrect, a number is expected',
          :param_tokens => [{:token => :size}]},
        :color => {
          :html_open => '<span style="color: %color% !important;">', :html_close => '</span>',
          :description => 'Change the color of the text',
          :example => '[color=red]This is red[/color]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /([a-zA-Z]+)/i,
          :param_tokens => [{:token => :color}]},
        :rotate => {
          :html_open => '<span class="fa fa-rotate%rotate%">', :html_close => '</span>',
          :description => 'transform rotate of the text',
          :example => '[rotate=1-1-1-180]rotate 1, 1, 1, 180[/rotate]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /((-1|0|1)-(-1|0|1)-(-1|0|1)-([0-9]{1,3}))/,
          :param_tokens => [{:token => :rotate}]},
        :rotatez => {
          :html_open => '<span class="fa fa-rotatez%rotatez%">', :html_close => '</span>',
          :description => 'transform rotate of the text',
          :example => '[rotatez=90]rotate 90 deg[/rotatez]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /([0-9]{1,3})/,
          :param_tokens => [{:token => :rotatez}]},
        :colorhex => {
          :html_open => '<span style="color: #%colorcode% !important">', :html_close => '</span>',
          :description => 'Use color code',
          :example => '[colorhex=ffffff]White text[/colorhex]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /([0-9a-fA-F]{6})/,
          :quick_param_format_description => 'The size parameter \'%param%\' is incorrect',
          :param_tokens => [{:token => :colorcode}]},
        :faicon => {
          :html_open => '<span class="fa fa-%between%"></span><span class="bbcode_FTL">%between%</span>', :html_close => '',
          :description => 'Use Font Awesome Icons',
          :example => '[faicon]users[/faicon]',
          :only_allow => [],
          :require_between => true},
        :youtube => {
          :html_open => '<span class="bbcode_FTL">https://www.youtube.com/watch?v=%between%</span><iframe id="player" type="text/html" width="%width%" height="%height%" src="https://www.youtube.com/embed/%between%?enablejsapi=1" frameborder="0"></iframe>', :html_close => '',
          :description => 'YouTube video',
          :example => '[youtube]E4Fbk52Mk1w[/youtube]',
          :only_allow => [],
          :url_matches => [/youtube\.com.*[v]=([^&]*)/, /youtu\.be\/([^&]*)/, /y2u\.be\/([^&]*)/],
          :require_between => true,
          :param_tokens => [
            { :token => :width, :optional => true, :default => 400 },
            { :token => :height, :optional => true, :default => 320 }
          ]},
        :flower => {
          :html_open => '<span class="fa-flower-gift">', :html_close => '</span>',
          :description => 'Make text flower gift',
          :example => 'This is [flower]spin[/flower].'},
      }, :enable, :i, :b, :quote, :code, :u, :s, :spin, :pulse, :flip, :large, :colorhex, :faicon, :youtube, :marq, :rotate, :rotatez, :flower)
    rescue Exception => e
    end
    html
  end

  def avoid_bbcode(html)

    if html.match(/\[(spin|pulse|large=(2x|3x|4x|5x|ex)|flip=vertical|flip=horizontal|b|i|u|s)\]/)
      s = html
      start = s.gsub!(/(\[\/?[a-z0-9\=]*\])/) { "​#{$1}​" }
    end

    if html.match(/:@?[a-z0-9_]*:/)
      s = html
      emojis = s.gsub!(/(:@?[a-z0-9_]*:)/) { "​#{$1}​" }
    end

    html

  end
end
