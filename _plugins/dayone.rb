require 'plist'

module Dayone
  class Generator < Jekyll::Generator
    def generatetagkeywalk(array)
      if array.nil? or not array.any? then
        return nil
      end

      # Sort, lowercase.
      return array.map{|tag| tag.downcase.strip}.sort
    end

    def blazetagkeynode(tagkey_map, tags)
      if tags.nil? or not tags.any? then
        return nil
      end

      tagkeywalk = generatetagkeywalk(tags)
      
      # Walk the tagkeys.
      node = tagkey_map
      tagkeywalk.each do |tag|
        if not node.has_key?(tag) then
          node[tag] = Hash.new
        end
        node = node[tag]
      end

      return node
    end

    def findtagkeynode(tagkey_map, tags)
      if tags.nil? or not tags.any? then
        return nil
      end

      tagkeywalk = generatetagkeywalk(tags)
      
      # Walk the tagkeys.
      node = tagkey_map
      tagkeywalk.each do |tag|
        if not node.has_key?(tag) then
          next
        end
        node = node[tag]
      end

      return node
    end
    
    def sanitizekeys(hash)
      hash.each do |key,value|
        sanitized_key = key.downcase.tr(" ", "_")
        if sanitized_key == key then
          next
        end
        
        hash[sanitized_key] = value
        hash.delete(key)
        if value.class == Hash then
          sanitizekeys(value)
        end
      end
    end

    def generate(site)
      # Load the server settings so that we can find the day one path.
      print "\n          Building Day One Posts:"
      serverconfig = YAML::load(File.open('_serverconfig.yml'))

      # We have the server config YAML loaded, find the Day One path.
      dayonepath = serverconfig['dayonepath']
      raise "Missing dayonepath key in _serverconfig.yml" if dayonepath.nil?
      raise "dayonepath must point to an existing path" if not File.directory?(dayonepath)
      
      print "\n          - Building tag map... "
      # Run through all of the posts to find the tag groups for Day One posts we care about.
      tagkey_map = Hash.new
      site.posts.each do |post|
        if not post.tags.any? then
          next
        end
        
        node = blazetagkeynode(tagkey_map, post.tags)
        node['post'] = post
      end
      
      print "\n          - Correlating Day One entries with posts... "
      # Run through every Day One entry and generate its tag key using the method above.
      # Use the generated tag key to add it to each post.
      # Remove the corresponding tags from each post.
      Dir.glob(dayonepath + "/entries/*.doentry") do |dayone_entry|
        doc = Plist::parse_xml(dayone_entry)
        doc['has_pic'] = File.exist?(dayonepath + "/photos/" + doc['UUID'] + ".jpg")
        if doc['has_pic'] then
          doc['pic_url'] = "/gfx/dayone/" + doc['UUID'] + ".jpg"
        end
        
        # Cleans the doc by replacing spaces with underscores and lower-casing all key names.
        sanitizekeys(doc)
        
        # Clean up the markup
        entry_text = doc['entry_text']
        
        # Headerize the first sentence.
        loc_firstperiod = entry_text.index(".")
        loc_firstnewline = entry_text.index("\n")
        if not loc_firstnewline.nil? and not loc_firstperiod.nil? then
          # Newline before the first period or directly after it.
          if loc_firstnewline < loc_firstperiod or loc_firstperiod == loc_firstnewline - 1 then
            entry_text = '# ' + entry_text
          end
        elsif not loc_firstnewline.nil? and loc_firstperiod.nil? then
          entry_text = '# ' + entry_text
        end
        doc['entry_text'] = entry_text
        
        node = findtagkeynode(tagkey_map, doc['tags'])
        if node.nil? or not node.has_key?('post') then
          next
        end
        
        data = node['post'].data

        # The tagkey walk found a post, let's add this Day One entry to it.
        if not data.has_key?('dayones') then
          data['dayones'] = Array.new
        end
        data['dayones'].concat([doc])

        # Sort the posts as we add them.
        # TODO(perf): Walk the tagkey_map and sort all of the terminal nodes once.
        data['dayones'].sort! { |a,b| a['creation_date'] <=> b['creation_date'] }
      end
      
      print "\n          - Done\n                    "
    end
  end
end

# Sample Day One entry
# location: 
#   place_name: Bahia Del Sol Hotel
#   locality: Bocas del Toro
#   administrative_area: Panama
#   longitude: -82.2414207458496
#   latitude: 9.33639517750777
#   foursquare_id: 4c8ffc2f5fdf6dcb9fef2c91
#   country: Panama
# starred: false
# entry_text: |-
#   Bahia del Sol
#   
#   $130
# weather: 
#   pressure_mb: 1007.46
#   description: Partly Cloudy
#   fahrenheit: "80"
#   wind_bearing: 279
#   iconname: cloudyn.png
#   visibility_km: 14.56
#   celsius: "26"
#   relative_humidity: 76.0
#   wind_speed_kph: 9.61
#   service: Forecast.io
# creation_date: 2013-11-16T02:00:00+00:00
# activity: Stationary
# uuid: F094F6DF8F314A99B613C0D552076496
# time_zone: America/Costa_Rica
# tags: 
# - Panama
# - Bocas del Toro
# - Bed and Breakfast
# has_pic: false
# creator: 
#   generation_date: 2013-11-26T17:00:13+00:00
#   host_name: swift
#   software_agent: Day One iOS/1.12
#   os_agent: iOS/7.0.4
#   device_agent: iPhone/iPhone4,1