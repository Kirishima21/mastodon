# frozen_string_literal: true

require 'singleton'
require_relative './formatter_markdown'
require_relative './sanitize_config'

class HTMLRenderer < Redcarpet::Render::HTML
  def block_code(code, language)
    "<pre><code>#{encode(code).gsub("\n", "<br/>")}</code></pre>"
  end

  def autolink(link, link_type)
    return link if link_type == :email
    Formatter.instance.link_url(link)
  end

  private

  def html_entities
    @html_entities ||= HTMLEntities.new
  end

  def encode(html)
    html_entities.encode(html)
  end
end

class Formatter
  include Singleton
  include RoutingHelper

  include ActionView::Helpers::TextHelper

  def format(status, **options)
    if status.reblog?
      prepend_reblog = status.reblog.account.acct
      status         = status.proper
    else
      prepend_reblog = false
    end

    raw_content = status.text

    if options[:inline_poll_options] && status.preloadable_poll
      raw_content = raw_content + "\n\n" + status.preloadable_poll.options.map { |title| "[ ] #{title}" }.join("\n")
    end

    return '' if raw_content.blank?

    unless status.local?
      html = reformat(raw_content)
      html = encode_custom_emojis(html, status.emojis + status.avatar_emojis, options[:autoplay]) if options[:custom_emojify]
      return html.html_safe # rubocop:disable Rails/OutputSafety
    end

    linkable_accounts = status.active_mentions.map(&:account)
    linkable_accounts << status.account

    html = raw_content

    html = konami_code(html)
    html = avoid_bbcode(html)
    html.gsub!(/(\A|[^\(])(https?:\/\/([^\n<>"\[\] 　]+))/){"#{$1}[#{$3[0, 20]}](#{$2})"} if status.content_type == 'text/markdown'

    mdFormatter = Formatter_Markdown.new(html)

    html = "RT @#{prepend_reblog} #{html}" if prepend_reblog    
    html = mdFormatter.formatted if status.content_type == 'text/markdown'
    html = encode_and_link_urls(html, linkable_accounts, keep_html: %w(text/markdown text/html).include?(status.content_type))
    html = encode_custom_emojis(html, status.emojis + status.avatar_emojis, options[:autoplay]) if options[:custom_emojify]

    if status.content_type == 'text/markdown'      
      mdLinkDecoder = MDLinkDecoder.new(html)
      html = mdLinkDecoder.decode
      html.gsub!(/(&amp;)/){"&"}
      html = format_bbcode(html)
    elsif status.content_type == 'text/html'
      html = reformat(html)
    else
      html = simple_format(html, {}, sanitize: false)
      html = html.delete("\n")
    end
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_markdown(html)
    html = markdown_formatter.render(html)
    html.delete("\r").delete("\n")
  end

  def reformat(html)
    sanitize(html, Sanitize::Config::MASTODON_STRICT)
  end

  def plaintext(status)
    return status.text if status.local?

    text = status.text.gsub(/(<br \/>|<br>|<\/p>)+/) { |match| "#{match}\n" }
    strip_tags(text)
  end

  def simplified_format(account, **options)
    html = format_bbcode(html)
    html = account.local? ? linkify(account.note) : reformat(account.note)
    html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def sanitize(html, config)
    Sanitize.fragment(html, config)
  end

  def format_spoiler(status, **options)
    html = encode(status.spoiler_text)
    html = encode_custom_emojis(html, status.emojis, options[:autoplay])
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_poll_option(status, option, **options)
    html = encode(option.title)
    html = encode_custom_emojis(html, status.emojis, options[:autoplay])
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_display_name(account, **options)
    html = encode(account.display_name.presence || account.username)
    html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_field(account, str, **options)
    return reformat(str).html_safe unless account.local? # rubocop:disable Rails/OutputSafety
    html = encode_and_link_urls(str, me: true)
    html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def linkify(text)
    html = encode_and_link_urls(text)
    html = simple_format(html, {}, sanitize: false)
    html = html.delete("\n")

    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def link_url(url)
    "<a href=\"#{encode(url)}\" target=\"blank\" rel=\"nofollow noopener\">#{link_html(url)}</a>"
  end

  private

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
    })

    Redcarpet::Markdown.new(renderer, extensions)
  end

  def html_entities
    @html_entities ||= HTMLEntities.new
  end

  def encode(html)
    html_entities.encode(html)
  end

  def encode_and_link_urls(html, accounts = nil, options = {})
#    entities = utf8_friendly_extractor(html, extract_url_without_protocol: false)

    entities = options[:keep_html] ? html_friendly_extractor(html) : utf8_friendly_extractor(html, extract_url_without_protocol: false)


    if accounts.is_a?(Hash)
      options  = accounts
      accounts = nil
    end
    
#    entities = options[:keep_html] ? html_friendly_extractor(html) : utf8_friendly_extractor(html, extract_url_without_protocol: false)

    if %w(text/markdown).include?(html)

      mdExtractor = MDExtractor.new(html)
      entities.concat(mdExtractor.extractEntities)

      rewrite(html.dup, entities) do |entity|
        if entity[:markdown]
          html[entity[:indices][0]...entity[:indices][1]]
        elsif entity[:url]
          link_to_url(entity, options)
        elsif entity[:hashtag]
          link_to_hashtag(entity)
        elsif entity[:screen_name]
          link_to_mention(entity, accounts)
        end
      end
    else
      rewrite(html.dup, entities, options[:keep_html]) do |entity|
        if entity[:url]
          link_to_url(entity, options)
        elsif entity[:hashtag]
          link_to_hashtag(entity)
        elsif entity[:screen_name]
          link_to_mention(entity, accounts)
        end
      end
    end
  end

  def count_tag_nesting(tag)
    if tag[1] == '/' then -1
    elsif tag[-2] == '/' then 0
    else 1
    end
  end

  def encode_custom_emojis(html, emojis, animate = false)
    return html if emojis.empty?

    emoji_map = emojis.each_with_object({}) { |e, h| h[e.shortcode] = [full_asset_url(e.image.url), full_asset_url(e.image.url(:static))] }

    i                     = -1
    tag_open_index        = nil
    inside_shortname      = false
    shortname_start_index = -1
    invisible_depth       = 0

    while i + 1 < html.size
      i += 1

      if invisible_depth.zero? && inside_shortname && html[i] == ':'
        shortcode = html[shortname_start_index + 1..i - 1]
        emoji     = emoji_map[shortcode]

        if emoji
          original_url, static_url = emoji
          replacement = begin
            if animate
              "<img draggable=\"false\" class=\"emojione\" alt=\":#{encode(shortcode)}:\" title=\":#{encode(shortcode)}:\" src=\"#{encode(original_url)}\" />"
            else
              "<img draggable=\"false\" class=\"emojione custom-emoji\" alt=\":#{encode(shortcode)}:\" title=\":#{encode(shortcode)}:\" src=\"#{encode(static_url)}\" data-original=\"#{original_url}\" data-static=\"#{static_url}\" />"
            end
          end
          before_html = shortname_start_index.positive? ? html[0..shortname_start_index - 1] : ''
          html        = before_html + replacement + html[i + 1..-1]
          i          += replacement.size - (shortcode.size + 2) - 1
        else
          i -= 1
        end

        inside_shortname = false
      elsif tag_open_index && html[i] == '>'
        tag = html[tag_open_index..i]
        tag_open_index = nil
        if invisible_depth.positive?
          invisible_depth += count_tag_nesting(tag)
        elsif tag == '<span class="invisible">'
          invisible_depth = 1
        end
      elsif html[i] == '<'
        tag_open_index   = i
        inside_shortname = false
      elsif !tag_open_index && html[i] == ':'
        inside_shortname      = true
        shortname_start_index = i
      end
    end

    html
  end

  def rewrite(text, entities, keep_html = false)
    text = text.to_s

    # Sort by start index
    entities = entities.sort_by do |entity|
      indices = entity.respond_to?(:indices) ? entity.indices : entity[:indices]
      indices.first
    end

    result = []

    last_index = entities.reduce(0) do |index, entity|
      indices = entity.respond_to?(:indices) ? entity.indices : entity[:indices]
      result << (keep_html ? text[index...indices.first] : encode(text[index...indices.first]))
      result << yield(entity)
      indices.last
    end

    result << (keep_html ? text[last_index..-1] : encode(text[last_index..-1]))

    result.flatten.join
  end

  UNICODE_ESCAPE_BLACKLIST_RE = /\p{Z}|\p{P}/

  def utf8_friendly_extractor(text, options = {})
    old_to_new_index = [0]

    escaped = text.chars.map do |c|
      output = begin
        if c.ord.to_s(16).length > 2 && UNICODE_ESCAPE_BLACKLIST_RE.match(c).nil?
          CGI.escape(c)
        else
          c
        end
      end

      old_to_new_index << old_to_new_index.last + output.length

      output
    end.join

    # Note: I couldn't obtain list_slug with @user/list-name format
    # for mention so this requires additional check
    special = Extractor.extract_urls_with_indices(escaped, options).map do |extract|
      new_indices = [
        old_to_new_index.find_index(extract[:indices].first),
        old_to_new_index.find_index(extract[:indices].last),
      ]

      next extract.merge(
        indices: new_indices,
        url: text[new_indices.first..new_indices.last - 1]
      )
    end

    standard = Extractor.extract_entities_with_indices(text, options)

    Extractor.remove_overlapping_entities(special + standard)
  end

  def html_friendly_extractor(html, options = {})
    gaps = []
    total_offset = 0

    escaped = html.gsub(/<[^>]*>|&#[0-9]+;/) do |match|
      total_offset += match.length - 1
      end_offset = Regexp.last_match.end(0)
      gaps << [end_offset - total_offset, total_offset]
      "\u200b"
    end

    entities = Extractor.extract_hashtags_with_indices(escaped, :check_url_overlap => false) +
               Extractor.extract_mentions_or_lists_with_indices(escaped)
    Extractor.remove_overlapping_entities(entities).map do |extract|
      pos = extract[:indices].first
      offset_idx = gaps.rindex { |gap| gap.first <= pos }
      offset = offset_idx.nil? ? 0 : gaps[offset_idx].last
      next extract.merge(
        :indices => [extract[:indices].first + offset, extract[:indices].last + offset]
      )
    end
  end

  def link_to_url(entity, options = {})
    url        = Addressable::URI.parse(entity[:url])
    html_attrs = { target: '_blank', rel: 'nofollow noopener' }

    html_attrs[:rel] = "me #{html_attrs[:rel]}" if options[:me]

    Twitter::Autolink.send(:link_to_text, entity, link_html(entity[:url]), url, html_attrs)
  rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
    encode(entity[:url])
  end

  def link_to_mention(entity, linkable_accounts)
    acct = entity[:screen_name]
    username, domain = acct.split('@')

    return link_to_account(acct) unless linkable_accounts and domain != "twitter.com"

    account = linkable_accounts.find { |item| TagManager.instance.same_acct?(item.acct, acct) }
    account ? mention_html(account) : "@#{encode(acct)}"
  end

  def link_to_account(acct)
    username, domain = acct.split('@')

    if domain == "twitter.com"
      return mention_twitter_html(username)
    end

    domain  = nil if TagManager.instance.local_domain?(domain)
    account = EntityCache.instance.mention(username, domain)

    account ? mention_html(account) : "@#{encode(acct)}"
  end

  def link_to_hashtag(entity)
    hashtag_html(entity[:hashtag])
  end

  def link_html(url)
    url    = Addressable::URI.parse(url).to_s
    prefix = url.match(/\Ahttps?:\/\/(www\.)?/).to_s
    text   = url[prefix.length, 30]
    suffix = url[prefix.length + 30..-1]
    cutoff = url[prefix.length..-1].length > 30

    "<span class=\"invisible\">#{encode(prefix)}</span><span class=\"#{cutoff ? 'ellipsis' : ''}\">#{encode(text)}</span><span class=\"invisible\">#{encode(suffix)}</span>"
  end

  def hashtag_html(tag)
    "<a href=\"#{encode(tag_url(tag))}\" class=\"mention hashtag\" rel=\"tag\">#<span>#{encode(tag)}</span></a>"
  end

  def mention_html(account)
    "<span class=\"h-card\"><a href=\"#{encode(ActivityPub::TagManager.instance.url_for(account))}\" class=\"u-url mention\">@<span>#{encode(account.username)}</span></a></span>"
  end

  def mention_twitter_html(username)
    "<span class=\"h-card\"><a href=\"https://twitter.com/#{username}\" class=\"u-url mention\">@<span>#{username}</span></a></span>"
  end

  def konami_code(html)

    if hexadecimal = html.match(/上上下下左右左右BA"([^"]*)"/)
      s = hexadecimal[1].unpack('H*')
      html.gsub!(/(\n|\A)上上下下左右左右BA"[^"]*"(\n|\z)/) { "#{$1}(´へεへ`*) ＜ #{s} #{$2}" }
      html.gsub!(/\["([0-9a-f]*)"\]/) { "#{$1}" }
    elsif html.match(/\$上上下下左右左右BA/)
      html.gsub!(/(な)/){ "にゃ" }
      html.gsub!(/(\$上上下下左右左右BA)/){ "" }
    elsif html.match(/(¥|\\)上上下下左右左右BA/)
      html.gsub!(/(¥|\\)上上下下左右左右BA/) { "上上下下左右左右BA" }
    else
      html.gsub!(/(上上下下左右左右BA)/) {"#{$1} ☝( ◠‿◠ )☝ 「使い方が違うぞ！」"}
    end

    html

  end

  def avoid_bbcode(html)

    if html.match(/\[(spin|pulse|large=(2x|3x|4x|5x|ex)|flip=vertical|flip=horizontal|b|i|u|s)\]/)
      s = html
      start = s.gsub!(/(\[\/?[a-z0-9\=]*\])/) { "​​#{$1}​​" }
    end

    if html.match(/:@?[a-z0-9_]*:/)
      s = html
      emojis = s.gsub!(/(:@?[a-z0-9_]*:)/) { "​​#{$1}​​" }
    end

    html

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
          :html_open => '<span style="color: %color%;">', :html_close => '</span>',
          :description => 'Change the color of the text',
          :example => '[color=red]This is red[/color]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /([a-zA-Z]+)/i,
          :param_tokens => [{:token => :color}]},
        :colorhex => {
          :html_open => '<span style="color: #%colorcode%">', :html_close => '</span>',
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
      }, :enable, :i, :b, :quote, :code, :u, :s, :spin, :pulse, :flip, :large, :colorhex, :faicon, :youtube, :marq)
    rescue Exception => e
    end
    html
  end

end
