require 'fastimage'

$LOAD_PATH.unshift File.dirname(__FILE__)
require File.join(File.dirname(__FILE__), '..', '_dayone/dayone.rb')

module Dayone
  class FeatherlessProcessor < Dayone::Processor
    def should_extract_title(doc)
      if not doc['tags'] or not doc['tags'].include?('Preamble')
        return true
      else
        return false
      end
    end
    
    def process_post(post)
      extract_preamble(post)
    end

    def process_entry(entry)
      calculate_long_entry(entry)
      determine_images(entry)
      calculate_panorama(entry)
    end
    
    def extract_preamble(post)
      if post.data.has_key?('dayones') then
        dayones = post.data['dayones']

        preamble_dayone = nil

        dayones.each do |dayone|
          if dayone['tags'].include?('Preamble')
            preamble_dayone = dayone
          end
        end
        
        if preamble_dayone
          dayones.delete(preamble_dayone)
        end
        
        post.data['dayone_preamble'] = preamble_dayone
      end
    end
    
    def calculate_panorama(doc)
      if doc['has_pic']
        size = FastImage.size(@dayonepath + "/photos/" + doc['uuid'] + ".jpg")
        if size[0] > size[1] * 4
          doc['pic_is_panoramic'] = true
        else 
          doc['pic_is_panoramic'] = false
        end
      end
    end
    
    def calculate_long_entry(doc)
      entry_text = doc['entry_text']
      if entry_text.length > 500 or entry_text.split("\n").to_a.count > 10
        doc['is_long_post'] = true
      else
        doc['is_long_post'] = false
      end
    end
    
    def determine_images(doc)
      if doc['has_pic']
        doc['pic_url'] = "/gfx/dayone_large/" + doc['uuid'] + ".jpg"
        doc['thumb_url'] = "/gfx/dayone_thumb/" + doc['uuid'] + ".jpg"
        doc['original_pic_url'] = "/gfx/dayone/" + doc['uuid'] + ".jpg"
        doc['thumb_html'] = "<img src=" + doc['thumb_url'] + " width=\"50\" height=\"50\" />"
      end

      # Determine which icon to use.
      svg_name = nil
      if orinclude?(doc['tags'], ["Restaurants"]) then
        svg_name = "restaurant"
      elsif orinclude?(doc['tags'], ["Food"]) then
        svg_name = "food"
      elsif orinclude?(doc['tags'], ["Bed and Breakfasts", "Hostels", "Hotels"]) then
        svg_name = "hotel"
      elsif orinclude?(doc['tags'], ["Hikes"]) then
        svg_name = "walking"
      elsif orinclude?(doc['tags'], ["Bussing"]) then
        svg_name = "bussing"
      elsif orinclude?(doc['tags'], ["SCUBA"]) then
        svg_name = "scuba"
      elsif doc['activity'] == "Walking" then
        svg_name = "walking"
      elsif doc['activity'] == "Automotive" then
        svg_name = "driving"
      elsif doc['activity'] == "Flying" then
        svg_name = "flying"
      else
        svg_name = "default"
      end
      
      svg_html = nil
      if svg_name then
        svg_path = "gfx/icons/" + svg_name + ".svg"
        if File.exist?(svg_path) then
          file = File.open(svg_path, "r")
          svg_html = file.read
          
        end
      end
      doc['icon_html'] = svg_html

      if doc['thumb_html'].nil?
        doc['thumb_html'] = svg_html
      end
    end

  end
end