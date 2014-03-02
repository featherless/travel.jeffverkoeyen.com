require 'fileutils'
require 'plist'
require 'Set'
require 'Time'
require 'YAML'
require 'json'

CONFIG_PATH = File.join(File.dirname(__FILE__), 'config.yml')

config = YAML::load(File.open(CONFIG_PATH))

dayonepath = config['dayonepath']
raise "Missing dayonepath key in " + CONFIG_PATH if dayonepath.nil?
raise "dayonepath must point to an existing path" unless File.directory?(dayonepath)

moneyspath = config['moneyspath']
raise "Missing moneyspath key in " + CONFIG_PATH if moneyspath.nil?
raise "moneyspath must point to an existing path" unless File.directory?(moneyspath)

dir = 'data'
unless File.directory?(dir)
  FileUtils.mkdir_p(dir)
end

countries = [
  "Afghanistan",
  "Albania",
  "Algeria",
  "American Samoa",
  "Andorra",
  "Angola",
  "Anguilla",
  "Antigua and Barbuda",
  "Argentina",
  "Armenia",
  "Aruba",
  "Australia",
  "Austria",
  "Azerbaijan",
  "Azores",
  "Bahamas",
  "Bahrain",
  "Banaba Island",
  "Bangladesh",
  "Barbados",
  "Belarus",
  "Belgium",
  "Belize",
  "Benin",
  "Bermuda",
  "Bhutan",
  "Bolivia",
  "Bosnia and Herzegovina",
  "Botswana",
  "Brazil",
  "British Virgin Islands",
  "Brunei",
  "Bulgaria",
  "Burkina Faso",
  "Burma",
  "Burundi",
  "Cambodia",
  "Cameroon",
  "Canada",
  "Cape Verde",
  "Cayman Islands",
  "Central African Republic",
  "Chad",
  "Channel Islands",
  "Chile",
  "China",
  "Christmas Island",
  "Cocos Islands",
  "Colombia",
  "Comoros",
  "Republic of Congo",
  "Cook Islands",
  "Costa Rica",
  "Cote d'Ivoire",
  "Croatia",
  "Cuba",
  "Cyprus",
  "Czech Republic",
  "Denmark",
  "Djibouti",
  "Dominica",
  "Dominican Republic",
  "East Timor",
  "Easter Island",
  "Ecuador",
  "Egypt",
  "El Salvador",
  "England",
  "Equatorial Guinea",
  "Eritrea",
  "Estonia",
  "Ethiopia",
  "Falkland Islands",
  "Faroe Islands",
  "Fiji",
  "Finland",
  "France",
  "French Antilles",
  "French Guiana",
  "French Polynesia",
  "Gabon",
  "Gambia, The",
  "Georgia",
  "Germany",
  "Ghana",
  "Gibraltar",
  "Greece",
  "Greenland",
  "Grenada",
  "Guadeloupe",
  "Guam",
  "Guatemala",
  "Guernsey",
  "Guinea",
  "Guinea-Bissau",
  "Guyana",
  "Haiti",
  "Vatican City",
  "Honduras",
  "Hong Kong",
  "Hungary",
  "Iceland",
  "India",
  "Indonesia",
  "Iran",
  "Iraq",
  "Ireland",
  "Israel",
  "Italy",
  "Jamaica",
  "Japan",
  "Jersey",
  "Jordan",
  "Kazakhstan",
  "Kenya",
  "Kiribati",
  "North Korea",
  "South Korea",
  "Kuwait",
  "Kyrgyzstan",
  "Laos",
  "Latvia",
  "Lebanon",
  "Leichenstein",
  "Lesotho",
  "Liberia",
  "Libya",
  "Liechtenstein",
  "Lithuania",
  "Lord Howe Island",
  "Luxembourg",
  "Macau",
  "Macedonia",
  "Madagascar",
  "Madria",
  "Malawi",
  "Malaysia",
  "Maldives",
  "Mali",
  "Malta",
  "Isle of Man",
  "Marshall Islands",
  "Martinique",
  "Mauritania",
  "Mauritius",
  "Mayotte",
  "Mexico",
  "Micronesia",
  "Midway Islands",
  "Moldova",
  "Monaco",
  "Mongolia",
  "Mongolian People's Republic",
  "Montenegro",
  "Montserrat",
  "Morocco",
  "Morovia",
  "Mozambique",
  "Myanmar",
  "Namibia",
  "Nauru",
  "Nepal",
  "Netherlands",
  "Netherlands Antilles",
  "New Caledonia",
  "New Zealand",
  "Nicaragua",
  "Niger",
  "Nigeria",
  "Niue",
  "Norfolk Island",
  "Northern Ireland",
  "Northern Mariana Islands",
  "Norway",
  "Oman",
  "Pakistan",
  "Palau",
  "Panama",
  "Papua New Guinea",
  "Paraguay",
  "Peru",
  "Philippines",
  "Pitcairn Islands",
  "Poland",
  "Portugal",
  "Puerto Rico",
  "Qatar",
  "Reunion",
  "Romania",
  "Russia",
  "Rwanda",
  "Saint Helena",
  "Saint Kitts and Nevis",
  "Saint Lucia",
  "Saint Pierre and Miquelon",
  "Saint Vincent and the Grenadines",
  "Samoa",
  "San Andrés y Providencia",
  "San Marino",
  "Sao Tome and Principe",
  "Saudi Arabia",
  "Scotland",
  "Senegal",
  "Serbia",
  "Seychelles",
  "Sierra Leone",
  "Singapore",
  "Slovakia",
  "Slovenia",
  "Solomon Islands",
  "Somalia",
  "South Africa",
  "Spain",
  "Sri Lanka",
  "Sudan",
  "Suriname",
  "Swaziland",
  "Sweden",
  "Switzerland",
  "Syria",
  "Tahiti",
  "Taiwan",
  "Tajikistan",
  "Tanzania",
  "Thailand",
  "Tibet",
  "Togo",
  "Tokelau",
  "Tonga",
  "Trinidad and Tobago",
  "Tunisia",
  "Turkey",
  "Turkmenistan",
  "Turks and Caicos",
  "Tuvalu",
  "Uganda",
  "Ukraine",
  "United Arab Emirates",
  "United States",
  "Uruguay",
  "Uzbekistan",
  "Vanuatu",
  "Vatican City",
  "Venezuela",
  "Vietnam",
  "Virgin Islands",
  "Wales",
  "Wallis & Futuna",
  "Western Sahara",
  "Yemen",
  "Yugoslavia",
  "Zambia",
  "Zimbabwe",
]

# TODO: Calculate city names by iterating over all posts in the blog.

$countries_set = Set.new countries.map(&:downcase)

def is_country(string)
  return $countries_set.include?(string.downcase)
end

lastrun_timestamp = nil
if File.exist?('data/lastrun.json')
  lastrun = JSON.parse( IO.read('data/lastrun.json') )
  lastrun_timestamp = Time.parse(lastrun['timestamp'])

  script_mtime = File.mtime(__FILE__)
  if script_mtime > lastrun_timestamp
    lastrun_timestamp = nil
  elsif Time.now - lastrun_timestamp > 60 * 60 * 24
    # Force a refresh at least once every 24 hours
    lastrun_timestamp = nil
  end
end

if lastrun_timestamp
  # Check day one entries first.
  any_dayone_modified = false
  Dir.glob(dayonepath + "/entries/*.doentry") do |dayone_entry|
    if File.mtime(dayone_entry) > lastrun_timestamp
      any_dayone_modified = true
    end
  end

  any_money_modified = false
  Dir.glob(moneyspath + "/logs/*.plist") do |moneys_entry|
    if File.mtime(moneys_entry) > lastrun_timestamp
      any_money_modified = true
    end
  end
else
  any_dayone_modified = true
  any_money_modified = true
end

if any_dayone_modified
  print "Recalculating Day One data...\n"

  dayonetag_counts = Hash.new
  dayonetag_photo_counts = Hash.new
  country_most_entries = nil
  country_most_photos = nil
  tag_most_entries = nil
  tag_most_photos = nil

  Dir.glob(dayonepath + "/entries/*.doentry") do |dayone_entry|
    doc = Plist::parse_xml(dayone_entry)

    has_pic = File.exist?(dayonepath + "/photos/" + doc['UUID'] + ".jpg")

    if doc['Tags']
      doc['Tags'].each do |tag|
        dayonetag_counts[tag] ||= 0
        dayonetag_counts[tag] += 1
      end

      if has_pic
        doc['Tags'].each do |tag|
          dayonetag_photo_counts[tag] ||= 0
          dayonetag_photo_counts[tag] += 1
        end
      end
    end
  end

  dayonetag_counts.each do |key,value|
    if is_country(key)
      # Calculate the country with the most entries.
      if country_most_entries.nil? || value > dayonetag_counts[country_most_entries]
        country_most_entries = key
      end
    elsif tag_most_entries.nil? || value > dayonetag_counts[tag_most_entries]
      tag_most_entries = key
    end
  end

  dayonetag_photo_counts.each do |key,value|
    if is_country(key)
      # Calculate the country with the most photos.
      if country_most_photos.nil? || value > dayonetag_photo_counts[country_most_photos]
        country_most_photos = key
      end
    elsif tag_most_photos.nil? || value > dayonetag_counts[tag_most_photos]
      tag_most_photos = key
    end
  end

  stats = {
    'country_most_entries' => country_most_entries,
    'country_most_entries_count' => dayonetag_counts[country_most_entries],
    'country_most_photos' => country_most_photos,
    'country_most_photos_count' => dayonetag_photo_counts[country_most_photos],
    'tag_most_entries' => tag_most_entries,
    'tag_most_entries_count' => dayonetag_counts[tag_most_entries],
    'tag_most_photos' => tag_most_photos,
    'tag_most_photos_count' => dayonetag_photo_counts[tag_most_photos],
  }

  File.open("data/dayone_stats.json","w") do |f|
    f.write(stats.to_json)
    f.close()
  end
  File.open("data/dayonetag_counts.json","w") do |f|
    f.write(dayonetag_counts.to_json)
    f.close()
  end
  File.open("data/dayonetag_photo_counts.json","w") do |f|
    f.write(dayonetag_photo_counts.to_json)
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

  File.open("data/moneytag_counts.json","w") do |f|
    f.write(moneytag_counts.to_json)
    f.close()
  end
end

# Outputting calculated data

lastrun = {
  'timestamp'=>Time.now
}

File.open("data/lastrun.json","w") do |f|
  f.write(lastrun.to_json)
  f.close()
end

