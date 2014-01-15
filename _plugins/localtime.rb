require 'tzinfo'

module LocalTimeFilter

  def local_time(dayone)
    tz = TZInfo::Timezone.get(dayone['time_zone'])
    return tz.utc_to_local(Time.parse(dayone['creation_date'].sub("+00:00", ''))).strftime('%A, %B %d, %Y %H:%M')
  end

  def local_time_short(dayone)
    tz = TZInfo::Timezone.get(dayone['time_zone'])
    return tz.utc_to_local(Time.parse(dayone['creation_date'].sub("+00:00", ''))).strftime('%B %d, %Y')
  end

end

Liquid::Template.register_filter(LocalTimeFilter)