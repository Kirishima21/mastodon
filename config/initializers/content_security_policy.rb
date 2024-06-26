# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

if Rails.env.production?
  assets_host = Rails.configuration.action_controller.asset_host || "https://#{ENV['WEB_DOMAIN'] || ENV['LOCAL_DOMAIN']}"
  data_hosts = [assets_host]
  cloudflarecdn = 'https://cdnjs.cloudflare.com'
  mathjax = 'https://cdn.mathjax.org'
  cdn_hosts = 'https://media-astarte.global.ssl.fastly.net'

  if ENV['S3_ENABLED'] == 'true'
    attachments_host = "https://#{ENV['S3_ALIAS_HOST'] || ENV['S3_CLOUDFRONT_HOST'] || ENV['S3_HOSTNAME'] || "s3-#{ENV['S3_REGION'] || 'us-east-1'}.amazonaws.com"}"
    attachments_host = "https://#{Addressable::URI.parse(attachments_host).host}"
  elsif ENV['SWIFT_ENABLED'] == 'true'
    attachments_host = ENV['SWIFT_OBJECT_URL']
    attachments_host = "https://#{Addressable::URI.parse(attachments_host).host}"
  else
    attachments_host = nil
  end

  data_hosts << attachments_host unless attachments_host.nil?

  if ENV['PAPERCLIP_ROOT_URL']
    url = Addressable::URI.parse(assets_host) + ENV['PAPERCLIP_ROOT_URL']
    data_hosts << "https://#{url.host}"
  end

  data_hosts.concat(ENV['EXTRA_DATA_HOSTS'].split('|')) if ENV['EXTRA_DATA_HOSTS']

  data_hosts.uniq!

  Rails.application.config.content_security_policy do |p|
    p.base_uri        :none
    p.default_src     :none
    p.frame_ancestors :none
    p.script_src      :self, :unsafe_inline, assets_host, cloudflarecdn, mathjax
    p.font_src        :self, :unsafe_inline, assets_host, cloudflarecdn
    p.img_src         :self, :unsafe_inline, :data, :https, :blob, *data_hosts, cloudflarecdn, mathjax
    p.style_src       :self, :unsafe_inline, assets_host, cloudflarecdn, mathjax
    p.media_src       :self, :unsafe_inline, :https, :http, :data, *data_hosts, cloudflarecdn, mathjax, cdn_hosts
    p.frame_src       :self, :https
    p.child_src       :self, :unsafe_inline, :blob, assets_host
    p.worker_src      :self, :blob, assets_host
    p.connect_src     :self, :unsafe_inline, :blob, :data, Rails.configuration.x.streaming_api_base_url, *data_hosts, cloudflarecdn, mathjax
    p.manifest_src    :self, assets_host
  end
end

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true

Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }

Rails.application.config.content_security_policy_nonce_directives = %w(style-src)

Rails.application.reloader.to_prepare do
  PgHero::HomeController.content_security_policy do |p|
    p.script_src :self, :unsafe_inline, assets_host
    p.style_src  :self, :unsafe_inline, assets_host
  end

  PgHero::HomeController.after_action do
    request.content_security_policy_nonce_generator = nil
  end
end
