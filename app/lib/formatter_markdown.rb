require 'uri'
require 'redcarpet'
require 'redcarpet/render_strip'

class Formatter_Markdown
    def initialize(html)
        @html = html.dup
    end

    def formatted
        mdRenderer = CustomMDRenderer.new(
            strikethrough: true,
            hard_wrap: true,
            autolink: false,
            superscript:false,
            fenced_link: true,
            fenced_image: true,
            no_intra_emphasis: true,
            no_links: true,
            no_styles: true,
            no_images: true,
            filter_html: true,
            escape_html: true,
            safe_links_only: true,
            with_toc_data: true,
            xhtml: false,
            prettify: true,
            link_attributes: true
        )

        md = Redcarpet::Markdown.new(
            mdRenderer,
            strikethrough: true,
            hard_wrap: true,
            superscript:false,
            autolink: false,
            space_after_headers: true,
            no_intra_emphasis: true,
            no_links: true,
            no_styles: true,
            no_images: true,
            filter_html: true,
            escape_html: true,
            safe_links_only: true,
            with_toc_data: true,
            xhtml: false,
            prettify: true,
            link_attributes: true
        )
        s = @html
        s.gsub!(/\n[\n]+/) {"\n　\n"}# 改行周りの問題を修正
        s.gsub!(/`[ ]+`/) {"｀ ｀"}# code内が半角スペースのみだとHTMLが壊れるのでそれの回避
#        s.gsub!(/(https?:\/\/[^<>"\[\] 　]+)/){"[#{$1[0, 20]}](#{$1})"}

        renderedMD = md.render(s)

        result = renderedMD
        result.gsub!(/(<\w+)([^>]*>)/) { "#{$1} data-md='true' #{$2}" }# ToDo data-md="true" を認識して他鯖の人にmarkdownの使用を伝える機能の実装
        result.gsub!(/(https?:\/\/[^<>"\[\] 　]+)/){"#{$1} "}#URLの後ろにスペースをねじ込む奴 mastodonのURL認識がゆるいのをmarkdownで対処

        result

    end

    class CustomMDRenderer < Redcarpet::Render::HTML

        #基本的な実装の流れ
        #URLの削除(mastodonの機能上URLとして認識されると十中八九HTMLが壊れるので)
        #markdownコンテンツ内でのmarkdownコンテンツの禁止(意図しないHTMLタグの生成によってHTMLの不正出力を防ぐ目的)
        #最後にHTMLに出力される際にHTML的にヤバイ子たちのエスケープ

        def paragraph(text)
            %(#{text.strip})
        end

        def linebreak()
            %(<br>)
        end

        def block_quote(quote)
            urlRemoved = "#{remove_url(quote)}"
            escapedContents = "#{blockquote_markdown_escape(urlRemoved)}"
            %(<blockquote>#{escapedContents.strip}</blockquote>)
        end

        def header(text, header_level)
            urlRemoved = "#{remove_url(text)}"
            mdContentsRemoved = "#{markdown_escape(urlRemoved)}"
            %(\n<h#{header_level}>#{encode(mdContentsRemoved)}</h#{header_level}>\n)
        end

        def block_code(code, language)
            %(<br>#{code.strip})
        end

        def codespan(code)
            urlRemoved = "#{remove_url(code)}"
            escapedCode = "#{escape_bbcode(urlRemoved)}"
            %(<code>#{encode(escapedCode)}</code>)

#            encoded = "#{encode(escapedCode)}"
#            %(<code>#{code_contents(encoded)}</code>)

        end

        def list(contents, list_type)
            if list_type == :unordered
                %(<ul class='md-contents'>#{contents.strip}</ul>)
            elsif list_type == :ordered
                %(<ol class='md-contents'>#{contents.strip}</ol>)
            else
                %(<#{list_type} class='md-contents'>#{contents.strip}</#{list_type}>)
            end
        end

        def list_item(text, list_type)
            urlRemoved = "#{remove_url(text)}"
            mdContentsRemoved = "#{markdown_escape(urlRemoved)}"
            %(<li class='md-contents'>#{encode(mdContentsRemoved)}</li>)
        end

        def emphasis(text)
            urlRemoved = "#{remove_url(text)}"
            mdContentsRemoved = "#{markdown_escape(urlRemoved)}"
            %(<sup>#{encode(mdContentsRemoved)}</sup>)
        end

        def double_emphasis(text)
            urlRemoved = "#{remove_url(text)}"
            mdContentsRemoved = "#{markdown_escape(urlRemoved)}"
            %(<sub>#{encode(mdContentsRemoved)}</sub>)
        end

        def triple_emphasis(text)
            urlRemoved = "#{remove_url(text)}"
            mdContentsRemoved = "#{markdown_escape(urlRemoved)}"
            %(<small>#{encode(mdContentsRemoved)}</small>)
        end

        def strikethrough(text)
            urlRemoved = "#{remove_url(text)}"
            mdContentsRemoved = "#{markdown_escape(urlRemoved)}"
            %(<s>#{encode(mdContentsRemoved)}</s>)
        end

        def superscript(text)
            urlRemoved = "#{remove_url(text)}"
            mdContentsRemoved = "#{markdown_escape(urlRemoved)}"
            %(<sup>#{encode(mdContentsRemoved)}</sup>)
        end

        def underline(text)
            urlRemoved = "#{remove_url(text)}"
            mdContentsRemoved = "#{markdown_escape(urlRemoved)}"
            %(<u>#{encode(mdContentsRemoved)}</u>)
        end

        def highlight(text)
            urlRemoved = "#{remove_url(text)}"
            mdContentsRemoved = "#{markdown_escape(urlRemoved)}"
            %(<mark>#{encode(mdContentsRemoved)}</mark>)
        end

        #オートリンクはmastodonとの相性が悪いので基本的には使わない

        def autolink(link, link_type)
            %(<a herf="#{link}">リンク</a>)
        end

        #https以外の物がURLとして記入された時にTextをHTML的に考えて安全に表示するように変更

        def image(link, title, alt_text)

            if alt_text =~ /[<>"\[\] 　]+/
                alt_text = "設定なし"
            end

            imgcheck = "#{link}"
            if imgcheck !~ /\Ahttps:\/\/[^<>"\[\] 　]+\z/
                %(#{encode(alt_text)})
            else
                %(<span class="img_FTL">画像が添付されています。</span><img src="#{URI.encode_www_form_component(link)}">)
            end
        end

        def link(link, title, content)

            if content =~ /([<>"\[\] 　]+|https?:\/\/|#|@)/
                content = "リンク"
            elsif content !~ /.+/
                content = "リンク"
            end

            linkcheck = "#{link}"
            if linkcheck !~ /\Ahttps?:\/\/[^<>"\[\] 　]+\z/
                %(#{encode(content)})
            else
                %(<a href="#{URI.encode_www_form_component(link)}">#{encode(content)}</a>)
            end
        end

        #ここから下はいろいろエスケープするための奴

        #HTML的に考えてよろしくない子たちをエスケープする奴
        def encode(html)
            HTMLEntities.new.encode(html)
        end

        #markdownコンテンツないでURLが生成されるのを防ぐためのエスケープする奴
        def remove_url(string)
            url = string.gsub(/https?:\/\//){ "URL:" }
            reply = url.gsub(/@/){ "＠" }
            hashTag = reply.gsub(/#/){ "＃" }
        end

        #前々から要望があったcode内でBBCodeを無効化するための奴
        def escape_bbcode(string)
            string.gsub(/\[/){ "&#091;" }
        end

        #markdownの中でmarkdownを展開させないためのエスケープする奴

        #blockquote以外は下のが使える
        def markdown_escape(string)
            string.gsub(/<[^>]+>/) { "" }
        end

        #blockquoteコンテンツ内でblockquoteタグだけを許可するためのエスケープ
        def blockquote_markdown_escape(string)
            string.gsub(/<([\/]?a[^>]*|[\/]?img[^>]*|[\/]?code[^>]*|[\/]?h[1-6][^>]*|[\/]?sup[^>]*|[\/]?sub[^>]*|[\/]?small[^>]*|[\/]?ul[^>]*|[\/]?ol[^>]*|[\/]?li[^>]*|[\/]?hr[^>]*|[\/]?s[^>]*|[\/]?u[^>]*|[\/]?mark[^>]*)>/) { "" }
        end

        #code内の一部を色分けするための変更
        def code_contents(string)
            simple = string.gsub(/(true|error|false|failed|def|puts|end|fn|let|mut|use|String|println!)/ ,
                "true" => "<span class='positive'>#{:true}</span>",
                "error" => "<span class='negative'>#{:error}</span>",
                "false" => "<span class='negative'>#{:false}</span>",
                "failed" => "<span class='negative'>#{:failed}</span>",
                "def" => "<span class='ruby-func'>#{:def}</span>",
                "puts" => "<span class='ruby-func'>#{:puts}</span>",
                "end" => "<span class='ruby-func'>#{:end}</span>",
                "fn" => "<span class='rust-fanc'>#{:fn}</span>",
                "let" => "<span class='rust-fanc'>#{:let}</span>",
                "mut" => "<span class='rust-fanc'>#{:mut}</span>",
                "use" => "<span class='rust-fanc'>#{:use}</span>",
                "String" => "<span class='rust-macro'>#{:String}</span>",
                "println!" => "<span class='rust-macro'>#{:println!}</span>",
            )
#            simple.gsub(/(&quot;[a-zA-Z0-9_ ,:;]+&quot;)/){ "<span class='contents'>#{$1}</span>" }

        end

        #テストで書きなぐった奴
        def html_escape(string)
            string.gsub(/['&\"<>\/]/, {
              '&' => '&amp;',
              '<' => '&lt;',
              '>' => '&gt;',
              '"' => '&quot;',
              "'" => '&#x27;',
              "/" => '&#x2F;',
            })
        end

    end

end

#URLとかいう人類には早すぎたやばい子たちを大人しくするために必要な機構

class MDLinkDecoder
    def initialize(html)
        @html = html.dup
    end

    def decode
        imageDecoded = @html.gsub(/<img data-md='true'\s+src="([^"]+)"([^>]*)>/) { "<a href=\"" + URI.decode_www_form_component($1) + "\"" + $2 + "><img data-md='true' src=\"" + URI.decode_www_form_component($1) + "\"" + $2 + "></a>" }

        imageDecoded.gsub(/<a data-md='true'\s+href="([^"]+)"([^>]*)>/) { "<a data-md='true' href=\"" + URI.decode_www_form_component($1) + "\"" + $2 + ">" }
    end
end

#エスケープを回避するHTMLタグの設定とかその他

class MDExtractor
    def initialize(html)
        @html = html.dup
    end

    def extractEntities
        [
            extractByHTMLTagName("h1"),
            extractByHTMLTagName("h2"),
            extractByHTMLTagName("h3"),
            extractByHTMLTagName("h4"),
            extractByHTMLTagName("h5"),
            extractByHTMLTagName("h6"),
            extractByHTMLTagName("em"),
            extractByHTMLTagName("sup"),
            extractByHTMLTagName("sub"),
            extractByHTMLTagName("small"),
            extractByHTMLTagName("u"),
            extractByHTMLTagName("strong"),
            extractByHTMLTagName("ul", false, false, "li"),
            extractByHTMLTagName("ol", false, false, "li"),
            extractByHTMLTagName("code"),
            extractByHTMLTagName("blockquote", false),
            extractByHTMLTagName("hr", false, true),
            extractByHTMLTagName("br", false, true),
            extractByHTMLTagName("a"),
            extractByHTMLTagName("img", false, true),
            extractByHTMLTagName("s"),
            extractByHTMLTagName("span")
        ].flatten.compact
    end

    def extractByHTMLTagName(tagName, isNoNest = true, isSingle = false, itemTagName = nil)
        entities = []

        @html.to_s.scan(htmlTagPatternByCond(tagName, isNoNest, isSingle, itemTagName)) do
            match = $~

            beginPos = match.char_begin(0)
            endPos = match.char_end(0)
            #puts "MDExtractor extracted with:\n" + @html + "\nbeginPos: " + beginPos.to_s + ", endPos: " + endPos.to_s + ", length: " + @html.length.to_s

            entity = {
                :markdown => true,
                :indices => [beginPos, endPos]
            }

            entities.push(entity)
        end

        entities
    end

    def htmlTagPatternByCond(tagName, isNoNest, isSingle, itemTagName)
        if isSingle
            htmlTagPatternSingle(tagName)
        elsif isNoNest
            htmlTagPatternNoNest(tagName)
        elsif itemTagName && itemTagName.length > 0
            htmlTagPatternOuterMostWithItem(tagName, itemTagName)
        else
            htmlTagPatternOuterMost(tagName)
        end
    end

    def htmlTagPattern(tagName)
        Regexp.compile("<#{tagName} data-md=[^>]*>(?:[^<]|<#{tagName} data-md=[^>]*>|<\\/#{tagName}>)*(?:<\\/#{tagName}>)*")
    end

    def htmlTagPatternNoNest(tagName)
        Regexp.compile("<#{tagName} data-md=[^>]*>(?:.|\n)*?<\\/#{tagName}>")
    end

    def htmlTagPatternSingle(tagName)
        Regexp.compile("<#{tagName} data-md=[^>]*>")
    end

    # https://stackoverflow.com/questions/546433/regular-expression-to-match-outer-brackets
    def htmlTagPatternOuterMost(tagName)
        Regexp.compile("<#{tagName} data-md=[^>]*>(?:[^<>]|(\\g<0>))*<\/#{tagName}>")
    end

    def htmlTagPatternOuterMostWithItem(tagName, itemTagName)
        Regexp.compile("<#{tagName} data-md=[^>]*>(?:[^<>]|<#{itemTagName} data-md=[^>]*>|<\\/#{itemTagName}>|(\\g<0>))*<\/#{tagName}>")
    end
end