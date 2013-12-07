require_relative 'dayone.rb'

module Dayone
  class Generator < Jekyll::Generator
    def generate(site)
      processor = FeatherlessProcessor.new
      processor.attach_dayones_to_site(site)
    end
  end
end
