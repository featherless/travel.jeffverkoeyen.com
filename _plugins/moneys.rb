$LOAD_PATH.unshift File.dirname(__FILE__)
require File.join(File.dirname(__FILE__), '..', '_moneysfeatherless/moneys.rb')

module Moneys
  class Generator < Jekyll::Generator
    def generate(site)
      processor = FeatherlessProcessor.new
      processor.attach_moneys_to_site(site)
    end
  end
end
