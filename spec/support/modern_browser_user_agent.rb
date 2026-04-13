# frozen_string_literal: true

# Provide a modern browser User-Agent in all request specs so that
# ApplicationController's `allow_browser versions: :modern` does not
# reject test requests with 403 Forbidden.
module ModernBrowserUserAgent
  CHROME_128 = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'

  %i[get post put patch delete head].each do |http_method|
    define_method(http_method) do |path, **kwargs|
      kwargs[:headers] = { 'User-Agent' => CHROME_128 }.merge(kwargs[:headers] || {})
      super(path, **kwargs)
    end
  end
end

RSpec.configure do |config|
  config.include ModernBrowserUserAgent, type: :request
end
