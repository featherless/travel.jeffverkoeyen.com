# This is a Jekyll plugin for the Day One journaling app. It reads
# Day One entries from a folder and exposes them to the Liquid
# templating system.
#
# Author::    Jeff Verkoeyen  (mailto:jverkoey@gmail.com)
# Copyright:: Copyright (c) 2013 Featherless Software Design
# License::   Apache 2.0

# Day One entries are stored in the plist format.
require 'plist'

# The Jekyll Day One module. Being a Generator allows this plugin
# to inject the Day One entries into Liquid before the pages get
# rendered. Day One entries will be made accessible via
# `page.dayones`.
module Dayone
  class Generator < Jekyll::Generator

    # Takes an array of tags and returns an array that may be
    # used to walk a tag tree efficiently. The resulting array
    # is ordered and each tag is standardized (lowercased,
    # etc...).
    # Params:
    # +tags+:: An Array of tag Strings.
    def generatetagkeywalk(tags)
      if tags.nil? or not tags.any? then
        return nil
      end

      # Sort, lowercase.
      return tags.map{|tag| tag.downcase.strip}.sort
    end

    def blazetagkeynode(tagkey_map, tags)
      tagkeywalk = generatetagkeywalk(tags)
      if tagkeywalk.nil? then
        return nil
      end
      
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
      tagkeywalk = generatetagkeywalk(tags)
      if tagkeywalk.nil? then
        return nil
      end

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
      new_hash = Hash.new
      hash.each do |key,value|
        sanitized_key = key.downcase.tr(" ", "_")

        if value.class == Hash then
          new_hash[sanitized_key] = sanitizekeys(value)
        else
          new_hash[sanitized_key] = value
        end
      end
      return new_hash
    end
    
    def orinclude?(haystack, needles)
      needles.each do |needle|
        if haystack.include?(needle)
          return true
        end
      end
      return false
    end
    
    def cleanpost(post)
      data = post.data
      if data.has_key?('dayones') then
        data['dayones'].sort! { |a,b| a['creation_date'] <=> b['creation_date'] }

        dayones = data['dayones']
        dayone_lodging = Array.new
        dayone_eating = Array.new
        dayone_notes = Array.new

        preamble_dayone = nil

        dayones.each do |dayone|
          if orinclude?(dayone['tags'], ["Bed and Breakfasts", "Hostels", "Hotels"])
            dayone_lodging.concat([dayone])
          elsif orinclude?(dayone['tags'], ["Restaurants", "Food"])
            dayone_eating.concat([dayone])
          else
            dayone_notes.concat([dayone])
          end
          
          if dayone['tags'].include?('Preamble')
            preamble_dayone = dayone
          end
        end
        
        if preamble_dayone
          dayones.delete(preamble_dayone)
        end
        
        data['dayone_preamble'] = preamble_dayone
        data['dayone_lodging'] = dayone_lodging
        data['dayone_eating'] = dayone_eating
        data['dayone_notes'] = dayone_notes
      end
    end
    
    def walktree(node)
      node.each do |key,value|
        if value.class == Hash then
          if value.has_key?('post') then
            cleanpost(value['post'])
          else
            walktree(value)
          end
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
          doc['pic_url'] = "/gfx/dayone_large/" + doc['UUID'] + ".jpg"
          doc['thumb_url'] = "/gfx/dayone_thumb/" + doc['UUID'] + ".jpg"
          doc['original_pic_url'] = "/gfx/dayone/" + doc['UUID'] + ".jpg"
        end
        
        # Cleans the doc by replacing spaces with underscores and lower-casing all key names.
        doc = sanitizekeys(doc)
        
        # Clean up the markup
        entry_text = doc['entry_text'].strip
        title_text = nil
        
        if not doc['tags'] or not doc['tags'].include?('Preamble') then
          # Get the title.
          loc_firstperiod = entry_text.index(".")
          loc_firstnewline = entry_text.index("\n")
          if not loc_firstnewline.nil? and not loc_firstperiod.nil? then
            # Newline before the first period or directly after it.
            if loc_firstnewline < loc_firstperiod then
              title_text = entry_text[0, loc_firstnewline]
              entry_text = entry_text[loc_firstnewline + 1..entry_text.length]
            elsif loc_firstperiod == loc_firstnewline - 1 then
              title_text = entry_text[0, loc_firstperiod]
              entry_text = entry_text[loc_firstperiod + 1..entry_text.length]
            end
          elsif not loc_firstnewline.nil? and loc_firstperiod.nil? then  
            title_text = entry_text[0, loc_firstnewline]
            entry_text = entry_text[loc_firstnewline+1..entry_text.length]
          end
          doc['entry_text'] = entry_text
          doc['title_text'] = title_text
          
          if entry_text.length > 500 or entry_text.lines.count > 10
            doc['is_long_post'] = true
          else
            doc['is_long_post'] = false
          end
        end
        
        # In order to parse the data in Liquid we have to convert the DateTime object to a string.
        doc['creation_date'] = doc['creation_date'].to_s
        
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
      end
      
      walktree(tagkey_map)
      
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