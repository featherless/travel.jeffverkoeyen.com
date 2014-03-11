require 'fileutils'
require 'plist'
require 'Set'
require 'Time'
require "i18n"
require 'yaml'
require 'json'

I18n.enforce_available_locales = false

CONFIG_PATH = File.join(File.dirname(__FILE__), 'config.yml')

config = YAML.load_file(CONFIG_PATH)

dayonepath = config['dayonepath']
raise "Missing dayonepath key in " + CONFIG_PATH if dayonepath.nil?
raise "dayonepath must point to an existing path" unless File.directory?(dayonepath)

moneyspath = config['moneyspath']
raise "Missing moneyspath key in " + CONFIG_PATH if moneyspath.nil?
raise "moneyspath must point to an existing path" unless File.directory?(moneyspath)

dir = '../_data'
unless File.directory?(dir)
  FileUtils.mkdir_p(dir)
end

$regions = Hash.new
$spots = Hash.new
$tag_to_display_string = Hash.new

def standardize_tag(string)
  return I18n.transliterate(string).downcase.delete("?").delete("'").gsub(" ", "_").gsub("-", "_")
end

def is_region(string)
  return $regions.has_key?(standardize_tag(string))
end

def is_spot(string)
  return $spots.has_key?(standardize_tag(string))
end

lastrun_timestamp = nil
if File.exist?('../_data/lastrun.yml')
  lastrun = YAML.load_file('../_data/lastrun.yml')
  lastrun_timestamp = lastrun['timestamp']

  script_mtime = File.mtime(__FILE__)
  if script_mtime > lastrun_timestamp
    lastrun_timestamp = nil
  elsif Time.now - lastrun_timestamp > 60 * 60 * 24
    # Force a refresh at least once every 24 hours
    lastrun_timestamp = nil
  end
end

if lastrun_timestamp
  any_dayone_modified = false
  any_money_modified = false

  # Day One posts
  Dir.glob(dayonepath + "../_posts/*.html") do |dayone_post|
    if File.mtime(dayone_post) > lastrun_timestamp
      any_dayone_modified = true
      any_money_modified = true # Also regenerate moneys logs
    end
  end

  # Day One entries
  if not any_dayone_modified
    Dir.glob(dayonepath + "/entries/*.doentry") do |dayone_entry|
      if File.mtime(dayone_entry) > lastrun_timestamp
        any_dayone_modified = true
      end
    end
  end

  # Moneys logs
  if not any_money_modified
    Dir.glob(moneyspath + "/logs/*.plist") do |moneys_entry|
      if File.mtime(moneys_entry) > lastrun_timestamp
        any_money_modified = true
      end
    end
  end
else
  any_dayone_modified = true
  any_money_modified = true
end

if any_dayone_modified
  print "Recalculating Day One data...\n"

  spot_highest_elevation = nil
  spot_highest_elevation_tag = nil
  spot_lowest_elevation = nil
  spot_lowest_elevation_tag = nil
  number_of_locations = 0
  countries_visited = 0

  Dir.glob("../_posts/*.html") do |dayone_post|
    info = YAML.load_file(dayone_post)
    if info['layout'] == 'city'
      standardized_country = standardize_tag(info['country'])
      standardized_city = standardize_tag(info['city'])

      $regions[standardized_country] = info['country']
      $spots[standardized_city] = info['city']

      if (not $tag_to_display_string.has_key?(standardized_country)) || (not $tag_to_display_string.has_key?(standardized_city))
        if not $tag_to_display_string.has_key?(standardized_country)
          $tag_to_display_string[standardized_country] = info['country']
          if info['country'] != 'Galapagos Islands'
            countries_visited += 1
          end
        end
        $tag_to_display_string[standardized_city] = info['city'] + ", " + info['country']
        number_of_locations += 1
      end

      if info.has_key?('elevation')
        if spot_highest_elevation_tag.nil? || info['elevation'] > spot_highest_elevation
          spot_highest_elevation_tag = standardize_tag(info['city'])
          spot_highest_elevation = info['elevation']
        end
        if spot_lowest_elevation_tag.nil? || info['elevation'] < spot_lowest_elevation
          spot_lowest_elevation_tag = standardize_tag(info['city'])
          spot_lowest_elevation = info['elevation']
        end
      end
    end

    if info['tags']
      info['tags'].each do |tag|
        if not $tag_to_display_string.has_key?(standardize_tag(tag))
          $tag_to_display_string[standardize_tag(tag)] = tag
        end
      end
    end
  end

  dayonetag_counts = Hash.new
  dayonetag_photo_counts = Hash.new
  region_most_entries = nil
  region_most_photos = nil
  spot_most_entries = nil
  spot_most_photos = nil
  tag_most_entries = nil
  tag_most_photos = nil
  spot_coldest_temperature = nil
  spot_coldest_temperature_tag = nil
  spot_hottest_temperature = nil
  spot_hottest_temperature_tag = nil
  words_written = 0
  bus_rides = 0
  bus_time_minutes = 0

  Dir.glob(dayonepath + "/entries/*.doentry") do |dayone_entry|
    doc = Plist::parse_xml(dayone_entry)

    has_pic = File.exist?(dayonepath + "/photos/" + doc['UUID'] + ".jpg")

    text = doc['Entry Text']
    text = text.gsub /^>.*/, ''
    words_written += text.split.size

    results = /Total bus time \| ([0-9]+):([0-9]+)/.match(doc['Entry Text'])
    if results
      bus_rides += 1
      results = results[0].scan(/([0-9]+)/)
      hours = results[0][0].to_i
      minutes = results[1][0].to_i
      bus_time_minutes += hours * 60 + minutes
    end

    # Calculate tag totals
    if doc['Tags']
      if has_pic
        # Number of photos per tag
        doc['Tags'].each do |tag|
          dayonetag_photo_counts[standardize_tag(tag)] ||= 0
          dayonetag_photo_counts[standardize_tag(tag)] += 1
        end
      end

      doc['Tags'].each do |tag|
        # Number of non-photo entries per tag
        dayonetag_counts[standardize_tag(tag)] ||= 0
        dayonetag_counts[standardize_tag(tag)] += 1
      end

      doc['Tags'].each do |tag|
        if not $tag_to_display_string.has_key?(standardize_tag(tag))
          $tag_to_display_string[standardize_tag(tag)] = tag
        end

        if doc.has_key?('Weather') && doc['Weather'].has_key?('Celsius')
          # Calculate weather info
          if is_spot(tag)
            if spot_coldest_temperature_tag.nil? || doc['Weather']['Celsius'].to_f < spot_coldest_temperature
              spot_coldest_temperature_tag = standardize_tag(tag)
              spot_coldest_temperature = doc['Weather']['Celsius'].to_f
            end
            if spot_hottest_temperature_tag.nil? || doc['Weather']['Celsius'].to_f > spot_hottest_temperature
              spot_hottest_temperature_tag = standardize_tag(tag)
              spot_hottest_temperature = doc['Weather']['Celsius'].to_f
            end
          end
        end
      end
    end
  end

  dayonetag_counts.each do |key,value|
    if is_region(key)
      # Calculate the region with the most entries.
      if region_most_entries.nil? || value > dayonetag_counts[region_most_entries]
        region_most_entries = key
      end
    elsif is_spot(key)
      # Calculate the spot with the most entries.
      if spot_most_entries.nil? || value > dayonetag_counts[spot_most_entries]
        spot_most_entries = key
      end
    # Calculate the tag with the most entries.
    elsif tag_most_entries.nil? || value > dayonetag_counts[tag_most_entries]
      tag_most_entries = key
    end
  end

  dayonetag_photo_counts.each do |key,value|
    if is_region(key)
      # Calculate the region with the most photos.
      if region_most_photos.nil? || value > dayonetag_photo_counts[region_most_photos]
        region_most_photos = key
      end
    elsif is_spot(key)
      # Calculate the spot with the most photos.
      if spot_most_photos.nil? || value > dayonetag_photo_counts[spot_most_photos]
        spot_most_photos = key
      end
    # Calculate the tag with the most photos.
    elsif tag_most_photos.nil? || value > dayonetag_photo_counts[tag_most_photos]
      tag_most_photos = key
    end
  end

  stats = {
    'region_most_entries' => region_most_entries,
    'region_most_entries_count' => dayonetag_counts[region_most_entries],
    'region_most_photos' => region_most_photos,
    'region_most_photos_count' => dayonetag_photo_counts[region_most_photos],
    'spot_most_entries' => spot_most_entries,
    'spot_most_entries_count' => dayonetag_counts[spot_most_entries],
    'spot_most_photos' => spot_most_photos,
    'spot_most_photos_count' => dayonetag_photo_counts[spot_most_photos],
    'tag_most_entries' => tag_most_entries,
    'tag_most_entries_count' => dayonetag_counts[tag_most_entries],
    'tag_most_photos' => tag_most_photos,
    'tag_most_photos_count' => dayonetag_photo_counts[tag_most_photos],
    'spot_highest_elevation' => spot_highest_elevation,
    'spot_highest_elevation_tag' => spot_highest_elevation_tag,
    'spot_lowest_elevation' => spot_lowest_elevation,
    'spot_lowest_elevation_tag' => spot_lowest_elevation_tag,
    'spot_coldest_temperature' => spot_coldest_temperature,
    'spot_coldest_temperature_tag' => spot_coldest_temperature_tag,
    'spot_hottest_temperature' => spot_hottest_temperature,
    'spot_hottest_temperature_tag' => spot_hottest_temperature_tag,
    'number_of_locations' => number_of_locations,
    'countries_visited' => countries_visited,
    'words_written' => words_written,
    'bus_rides' => bus_rides,
    'bus_time_hours' => bus_time_minutes / 60,
    'bus_time_minutes' => bus_time_minutes % 60,
  }

  File.open("../_data/dayone_stats.yml","w") do |f|
    f.write(stats.to_yaml)
    f.close()
  end
  File.open("../_data/dayonetag_counts.yml","w") do |f|
    f.write(dayonetag_counts.to_yaml)
    f.close()
  end
  File.open("../_data/dayonetag_photo_counts.yml","w") do |f|
    f.write(dayonetag_photo_counts.to_yaml)
    f.close()
  end
  File.open("../_data/regions.yml","w") do |f|
    f.write($regions.keys.sort.to_yaml)
    f.close()
  end
  File.open("../_data/locations.yml","w") do |f|
    f.write($spots.keys.sort.to_yaml)
    f.close()
  end
end

if any_money_modified
  print "Recalculating Moneys data...\n"
  moneytag_counts = Hash.new

  Dir.glob(moneyspath + "/logs/*.plist") do |moneys_entry|
    doc = Plist::parse_xml(moneys_entry)
    if doc['tags']
      doc['tags'].each do |tag|
        moneytag_counts[tag] ||= 0
        moneytag_counts[tag] += 1
      end
    end
  end

  File.open("../_data/moneytag_counts.yml","w") do |f|
    f.write(moneytag_counts.to_yaml)
    f.close()
  end
end

if any_money_modified && any_dayone_modified
  File.open("../_data/tag_to_display_string.yml","w") do |f|
    f.write($tag_to_display_string.to_yaml)
    f.close()
  end
end

# Outputting calculated data

lastrun = {
  'timestamp'=>Time.now
}

File.open("../_data/lastrun.yml","w") do |f|
  f.write(lastrun.to_yaml)
  f.close()
end

