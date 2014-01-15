$LOAD_PATH.unshift File.dirname(__FILE__)
require File.join(File.dirname(__FILE__), '..', '_moneys/moneys.rb')

module Moneys
  class FeatherlessProcessor < Moneys::Processor

    def process_entry(entry)
      
    end

  end
end