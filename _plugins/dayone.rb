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
        
        doc['text'] = doc['Entry Text']
        doc.delete('Entry Text')
        doc['creation_date'] = doc['Creation Date']
        doc.delete('Creation Date')
        doc['tz'] = doc['Time Zone']
        doc.delete('Time Zone')
        
        node = findtagkeynode(tagkey_map, doc['Tags'])
        if node.nil? or not node.has_key?('post') then
          next
        end
        
        data = node['post'].data

        # The tagkey walk found a post, let's add this Day One entry to it.
        if not data.has_key?('dayones') then
          data['dayones'] = Array.new
        end
        data['dayones'].concat([doc])
      end
      
      print "\n          - Done\n                    "
    end
  end
end

# Sample Day One entry
# Weather: 
#   Celsius: "30"
#   Sunrise Date: 2013-11-25T11:31:14+00:00
#   Wind Bearing: 40
#   Service: HAMweather
#   Relative Humidity: 70
#   Sunset Date: 2013-11-25T23:07:43+00:00
#   IconName: fair.png
#   Wind Speed KPH: 11
#   Fahrenheit: "86"
#   Pressure MB: 1009
#   Description: Partly Cloudy
#   Wind Chill Celsius: 30
# Location: 
#   Place Name: Flip Flop
#   Foursquare ID: 4e230211d22d0a3f5a07bb80
#   Administrative Area: Limon
#   Latitude: 9.65710685442079
#   Longitude: -82.7546278630418
#   Country: Costa Rica
# Creator: 
#   Device Agent: iPhone/iPhone4,1
#   Software Agent: Day One iOS/1.12
#   Host Name: swift
#   OS Agent: iOS/7.0.3
#   Generation Date: 2013-11-25T20:32:22+00:00
# Time Zone: America/Costa_Rica
# UUID: 422C23B4BDD84A0B80904F88F8316459
# Tags: 
# - Restaurants
# - Costa rica
# - Puerto Viejo
# Entry Text: |-
#   Flip Flop Burgers
#   
#   Weren't full from Veronica's so we wandered around in search of other foods. Stumbled upon Flip Flop for some cheap hamburguesas!
# Starred: false
# Creation Date: 2013-11-25T20:32:22+00:00
# Activity: Eating
