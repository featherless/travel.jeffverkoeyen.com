$LOAD_PATH.unshift File.dirname(__FILE__)
require File.join(File.dirname(__FILE__), '..', '_moneys/moneys.rb')

module Moneys
  class FeatherlessProcessor < Moneys::Processor

    def process_entry(entry)
      currencyTotals = Hash.new

      entry['portions'].each do |portion|
        didPay = portion['didPay'].to_f
        currency = portion['foreignCurrency']
        if didPay > 0 and not currency.nil?
          currencyTotals[currency] ||= 0
          currencyTotals[currency] = currencyTotals[currency] + didPay
        end
      end
      
      prettystr = Array.new
      currencyTotals.each do |key,value|
        formatted = '%.2f' % value
        formatted.slice! ".00"
        prettystr.concat([formatted + " " + key])
      end

      entry['total'] = prettystr * " + "
    end
    
    def process_post(post)
      if post.data.has_key?('moneys') then
        moneys = post.data['moneys']
        
        
      end
    end

  end
end