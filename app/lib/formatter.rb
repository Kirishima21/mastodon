# frozen_string_literal: true

require 'singleton'
require_relative './formatter_markdown'
require_relative './sanitize_config'

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

    return '' if raw_content.blank?

    unless status.local?
      html = reformat(raw_content)
      html = encode_custom_emojis(html, status.emojis, options[:autoplay]) if options[:custom_emojify]
      return html.html_safe # rubocop:disable Rails/OutputSafety
    end

    linkable_accounts = status.mentions.map(&:account)
    linkable_accounts << status.account

    html = raw_content
    return html.html_safe if options[:no_deco]

    mdFormatter = Formatter_Markdown.new(html)
    html = mdFormatter.formatted

    html = "RT @#{prepend_reblog} #{html}" if prepend_reblog
    html = encode_and_link_urls(html, linkable_accounts)
    html = encode_custom_emojis(html, status.emojis, options[:autoplay]) if options[:custom_emojify]
    html = simple_format(html, {}, sanitize: false)
    html = html.delete("\n")
    html = format_bbcode(html)

    mdLinkDecoder = MDLinkDecoder.new(html)
    html = mdLinkDecoder.decode

    html.gsub!(/(&amp;)/){"&"}

    html.html_safe # rubocop:disable Rails/OutputSafety
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

  private

  def html_entities
    @html_entities ||= HTMLEntities.new
  end

  def encode(html)
    html_entities.encode(html)
  end

  def encode_and_link_urls(html, accounts = nil, options = {})
    entities = Extractor.extract_entities_with_indices(html, extract_url_without_protocol: false)

    mdExtractor = MDExtractor.new(html)
    entities.concat(mdExtractor.extractEntities)

    if accounts.is_a?(Hash)
      options  = accounts
      accounts = nil
    end

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
  end

  def count_tag_nesting(tag)
    if tag[1] == '/' then -1
    elsif tag[-2] == '/' then 0
    else 1
    end
  end

  def encode_custom_emojis(html, emojis, animate = false)
    return html if emojis.empty?

    emoji_map = if animate
                  emojis.map { |e| [e.shortcode, full_asset_url(e.image.url)] }.to_h
                else
                  emojis.map { |e| [e.shortcode, full_asset_url(e.image.url(:static))] }.to_h
                end

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
          replacement = "<img draggable=\"false\" class=\"emojione\" alt=\":#{encode(shortcode)}:\" title=\":#{encode(shortcode)}:\" src=\"#{encode(emoji)}\" />"
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

  def rewrite(text, entities)
    chars = text.to_s.to_char_a

    # Sort by start index
    entities = entities.sort_by do |entity|
      indices = entity.respond_to?(:indices) ? entity.indices : entity[:indices]
      indices.first
    end

    result = []

    last_index = entities.reduce(0) do |index, entity|
      indices = entity.respond_to?(:indices) ? entity.indices : entity[:indices]
      result << encode(chars[index...indices.first].join)
      result << yield(entity)
      indices.last
    end

    result << encode(chars[last_index..-1].join)

    result.flatten.join
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
    "<a href=\"#{encode(tag_url(tag.downcase))}\" class=\"mention hashtag\" rel=\"tag\">#<span>#{encode(tag)}</span></a>"
  end

  def mention_html(account)
    "<span class=\"h-card\"><a href=\"#{encode(TagManager.instance.url_for(account))}\" class=\"u-url mention\">@<span>#{encode(account.username)}</span></a></span>"
  end

  def mention_twitter_html(username)
    "<span class=\"h-card\"><a href=\"https://twitter.com/#{username}\" class=\"u-url mention\">@<span>#{username}</span></a></span>"
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
        :large => {
          :html_open => '<span class="fa fa-%size%">', :html_close => '</span>',
          :description => 'Large text',
          :example => '[large=2x]Large text[/large]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /(2x|3x|4x|5x)/,
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
          :html_open => '<span class="fa fa-%between%"></span><span class="faicon_FTL">%between%</span>', :html_close => '',
          :description => 'Use Font Awesome Icons',
          :example => '[faicon]users[/faicon]',
          :only_allow => [],
          :require_between => true},
        :youtube => {
          :html_open => '<iframe id="player" type="text/html" width="%width%" height="%height%" src="https://www.youtube.com/embed/%between%?enablejsapi=1" frameborder="0"></iframe>', :html_close => '',
          :description => 'YouTube video',
          :example => '[youtube]E4Fbk52Mk1w[/youtube]',
          :only_allow => [],
          :url_matches => [/youtube\.com.*[v]=([^&]*)/, /youtu\.be\/([^&]*)/, /y2u\.be\/([^&]*)/],
          :require_between => true,
          :param_tokens => [
            { :token => :width, :optional => true, :default => 400 },
            { :token => :height, :optional => true, :default => 320 }
          ]},
      }, :enable, :i, :b, :quote, :code, :size, :u, :s, :spin, :pulse, :flip, :large, :colorhex, :faicon, :youtube)
    rescue Exception => e
    end
    html
  end

end
