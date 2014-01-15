$LOAD_PATH.unshift File.dirname(__FILE__)
require File.join(File.dirname(__FILE__), '..', '_moneys/moneys.rb')

module Moneys
  class FeatherlessProcessor < Moneys::Processor
    
    def pretty_currency_totals(currencyTotals)
      prettystr = Array.new
      currencyTotals.each do |key,value|
        formatted = '%.2f' % value
        formatted.slice! ".00"
        prettystr.concat([formatted + " " + key])
      end

      return prettystr * " + "
    end

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

      entry['currencytotals'] = currencyTotals
      entry['total'] = pretty_currency_totals(currencyTotals)
    end
    
    def process_post(post)
      if post.data.has_key?('moneys') then
        moneys = post.data['moneys']
        
        currencyTotals = Hash.new
        tagsToTotals = Hash.new

        moneys.each do |log|
          if log['currencytotals'].nil?
            next
          end

          log['currencytotals'].each do |key,value|
            currencyTotals[key] ||= 0
            currencyTotals[key] = currencyTotals[key] + value
          end
          
          log['tags'].each do |tag|
            tagsToTotals[tag] ||= Hash.new
            log['currencytotals'].each do |key,value|
              tagsToTotals[tag][key] ||= 0
              tagsToTotals[tag][key] = tagsToTotals[tag][key] + value
            end
          end
        end

        post.data['total'] = pretty_currency_totals(currencyTotals)
        post.data['tagtotals'] = tagsToTotals
      end
    end

  end
end