module Deployku
  class << self
    def sanitize_app_name(app_name)
      app_name.gsub(%r{^\.+}, '').gsub(%r{\.+$}, '').gsub(%r{\.\./}, '').gsub(%r{^/+}, '').gsub(%r{/+$}, '').gsub(%r{/+}, '-').gsub(%r{\s+}, '_').gsub(%r{[^a-zA-Z0-9_\-\.]}, '')
    end
  end
end