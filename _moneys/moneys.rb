# A processor for Moneys entries to be used in a Jekyll Generator
# plugin.
#
# Author::    Jeff Verkoeyen  (mailto:jverkoey@gmail.com)
# Copyright:: Copyright (c) 2014 Featherless Software Design
# License::   Apache 2.0

# Moneys entries are stored in the plist format.
require 'plist'

MONEYS_CONFIG_PATH = File.join(File.dirname(__FILE__), 'config.yml')
TAG_TREE_POST_KEY = '#_post_#'

# The Moneys Jekyll module. This module includes a Processor class
# which may be subclassed in order to provide additional
# functionality. When the processor is executed on a given Generator
# page, Moneys entries will be made accessible via `page.moneys`.
module Moneys
  class Processor

    # Takes an array of tag strings and returns an array that
    # can be used to walk a tag tree. The resulting array is
    # ordered and each tag is standardized (lowercased,
    # etc...).
    # Params:
    # +tags+:: An Array of Strings.
    # Returns:
    # An Array of Strings, sorted alphabetically and
    # standardized.
    def generate_tag_walk(tags)
      # Note(featherless): Am I missing a cleaner way to
      # bail out for nil args?
      if tags.nil? || tags.empty?
        return nil
      end

      # Lowercased sort to standardize tag names between
      # Moneys and Jekyll. Not doing this would lead to
      # capitalization differences causing Moneys posts
      # not to match up to their Jekyll counterparts.
      return tags.map{|tag| tag.downcase.strip}.sort
    end

    # Builds a tag tree from an array of tag strings.
    def build_tag_tree(tag_tree, tags)
      tag_walk = generate_tag_walk(tags)
      if tag_walk.nil?
        return nil
      end

      node = tag_tree
      tag_walk.each do |tag|
        node[tag] ||= Hash.new
        node = node[tag]
      end

      return node
    end

    # Walks the tag tree with the given tags and
    # returns an array of posts that were attached
    # to any touched nodes.
    def get_tag_tree_posts(tag_tree, tags)
      tag_walk = generate_tag_walk(tags)
      if tag_walk.nil?
        return nil
      end

      posts = Array.new

      # Typical breadth-first search using the
      # existence of a branch in the tag_walk to
      # determine whether a node is traversed.

      queue = [tag_tree]

      # Consulted with @thatwasawesome for this efficient algorithm.
      while queue.length > 0
        node = queue.shift

        # We return every touched node's post, if
        # it has one.
        if node.has_key?(TAG_TREE_POST_KEY)
          posts.push(node[TAG_TREE_POST_KEY])
        end

        tag_walk.each do |tag|
          if node.has_key?(tag)
            queue.push(node[tag])
          end
        end

      end

      return posts
    end

    # Recursively walks a hash tree and sanitizes each key
    # so that they can be used in Liquid templates. Spaces
    # will be replaced with "_" characters and all
    # characters will be lowercased.
    #
    # Moneys Note:
    # Moneys keys tend to have spaces, making it difficult
    # to access certain properties of each dayone entry in
    # Liquid templates.
    #
    # Returns:
    # The sanitized hash.
    def sanitize_keys(hash)
      new_hash = Hash.new
      hash.each do |key,value|
        sanitized_key = key.downcase.tr(" ", "_")

        if value.is_a? Hash
          new_hash[sanitized_key] = sanitize_keys(value)
        else
          new_hash[sanitized_key] = value
        end
      end
      return new_hash
    end

    # Tests if haystack includes any of the needles.
    def orinclude?(haystack, needles)
      if haystack.nil? or needles.nil?
        return false
      end

      return (haystack & needles).any?
    end

    # Returns an enumerator that touches all of the posts
    # in the tag_tree.
    #
    # Modified from http://stackoverflow.com/questions/3748744/traversing-a-hash-recursively-in-ruby
    def post_enumerator_from_tag_tree(tag_tree, &block)
      return enum_for(:post_enumerator_from_tag_tree, tag_tree) unless block

      if not tag_tree[TAG_TREE_POST_KEY].nil?
        yield tag_tree[TAG_TREE_POST_KEY]
      end
      tag_tree.each do |k,v|
        if v.is_a? Hash
          post_enumerator_from_tag_tree(v, &block)
        end
      end
    end

    # Extracts the title from a given Moneys entry.
    #
    # The title is the first sentence of a Moneys entry unless
    # that sentence is part of a paragraph.
    def extract_title(doc)
      entry_text = doc['entry_text'].strip
      title_text = nil
      if entry_text.index("#") == 0
        return
      end

      # Get the title.
      loc_firstperiod = entry_text.index(".")
      loc_firstnewline = entry_text.index("\n")
      if not loc_firstnewline.nil? and not loc_firstperiod.nil?
        # Newline before the first period or directly after it.
        if loc_firstnewline < loc_firstperiod
          title_text = entry_text[0, loc_firstnewline]
          entry_text = entry_text[loc_firstnewline + 1..entry_text.length]
        elsif loc_firstperiod == loc_firstnewline - 1
          title_text = entry_text[0, loc_firstperiod]
          entry_text = entry_text[loc_firstperiod + 1..entry_text.length]
        end
      elsif not loc_firstnewline.nil? and loc_firstperiod.nil?
        title_text = entry_text[0, loc_firstnewline]
        entry_text = entry_text[loc_firstnewline+1..entry_text.length]
      end
      doc['entry_text'] = entry_text
      doc['title_text'] = title_text
    end

    # Returns a Boolean indicating whether or not the title should
    # be extracted from the first line of the given Moneys entry.
    def should_extract_title(doc)
      return true
    end
    
    # To be called from your Generator's generate method.
    def attach_moneys_to_site(site)
      # Load the server settings so that we can find the Moneys path.
      print "\n       Extracting Moneys Logs:"
      serverconfig = YAML::load(File.open(MONEYS_CONFIG_PATH))

      # We have the server config YAML loaded, find the Moneys path.
      moneyspath = serverconfig['moneyspath']
      raise "Missing moneyspath key in " + MONEYS_CONFIG_PATH if moneyspath.nil?
      raise "moneyspath must point to an existing path" unless File.directory?(moneyspath)
      @moneyspath = moneyspath

      print "\n          - Building tag tree... "

      # Build the tag tree from Jekyll's posts. We'll use the Moneys entry
      # tags to find which post to attach each to later.
      tag_tree = Hash.new
      site.posts.each do |post|
        if post.tags.empty?
          next
        end

        node = build_tag_tree(tag_tree, post.tags)
        node[TAG_TREE_POST_KEY] = post
      end

      print "\n          - Correlating Moneys entries with Jekyll posts... "

      Dir.glob(moneyspath + "/logs/*.plist") do |moneys_entry|
        doc = Plist::parse_xml(moneys_entry)

        # Cleans the doc by replacing spaces with underscores and lower-casing all key names.
        doc = sanitize_keys(doc)
        
        if doc['tags'].nil? || doc['tags'].empty?
          next
        end
        
        # In order to parse the data in Liquid we have to convert the DateTime object to a string.
        doc['creation_date'] = doc['creation_date'].to_s

        process_entry(doc)

        # Find all of the posts that this Moneys's tags match to.
        posts = get_tag_tree_posts(tag_tree, doc['tags'])
        if posts.nil? || posts.empty?
          next
        end

        posts.each do |post|
          data = post.data

          # Attach this Moneys entry to the post.
          data['moneys'] ||= Array.new
          data['moneys'].concat([doc])
        end
      end

      print "\n          - Sorting Moneys entries... "
      # Once we've added all Moneys entries, we run a final pass to
      # sort them.
      post_enumerator_from_tag_tree(tag_tree).each do |post|
        if post.data.has_key?('moneys')
          post.data['moneys'].sort! { |a,b| a['creation_date'] <=> b['creation_date'] }
        end

        process_post(post)
      end

      print "\n          - Done\n                    "
    end

    # For processing a Jekyll post after all Moneys entries
    # have been added and before the post is passed to
    # Liquid.
    def process_post(post)
      # No-op.
    end

    # For processing a Moneys entry.
    def process_entry(entry)
      # No-op.
    end

  end
end
