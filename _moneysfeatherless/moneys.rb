$LOAD_PATH.unshift File.dirname(__FILE__)
require File.join(File.dirname(__FILE__), '..', '_moneys/moneys.rb')

module Moneys
  class FeatherlessProcessor < Moneys::Processor
  end
end