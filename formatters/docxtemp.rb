require 'json'

class Timetrap::Formatters::Docxtemp
  include Timetrap::Helpers

  def initialize(entries)
    @pay_rate = Timetrap::Config['pay_rate'].match(/\A(\D*)([\d\.]+)(\D*)\Z/).captures[1].to_f

    sheets = entries.inject({}) do |h, e|
      h[e.sheet] ||= []
      h[e.sheet] << e
      h
    end

    @sheets = entries.group_by { |e| e.sheet }
    @current = @sheets[sheets.keys.sort.first]

    return # FJDKSLJFDKSLJFKDLSJKFLSJKLDF

    last_start = nil
    from_current_day = []
    tpay = 0

    @current.each_with_index do |e, i|
      from_current_day << e
      pay = compute_pay(e.duration)
      tpay += pay

      @data[:start_date] ||= format_date(e.start)
      @data[:end_date] = format_date(e.start)

      @data[:entries] << {
        day: format_date_if_new(e.start, last_start),
        start: e.start.strftime('%R'),
        end: e.end.strftime('%R'),
        hours: hour_time(e.duration),
        pay: format_pay(pay),
        note: e.note
      }

      last_start = e.start
    end

    @data[:t_hours] = total_hours(sheets[sheet])
    @data[:t_pay] = nil
  end

  def compute!
    days = @current.group_by{ |e| format_date(e.start) }
    entries = []
    total_pay = 0

    days.each do |day, data|
      daily_hours = 0.0
      daily_pay = 0.0
      ot = false

      data.each_with_index do |clock, i|
        hours = clock.duration / 3600.0
        daily_hours += hours
        pay = 0

        entry = {
          day: i == 0 ? day : '',
          start: clock.start.strftime('%R'),
          end: clock.end.strftime('%R'),
          note: clock.note,
          hours: hour_time(hours)
        }

        if ot
          pay = hours * @pay_rate * 1.5
          entry[:note] = "OT: #{entry[:note]}".sub(/: $/, '')
        elsif daily_hours > 8.001
          ot = true
          ot_hours = daily_hours - 8
          hours -= ot_hours
          change = clock.end - ot_hours * 3600

          entry[:end] = change.strftime('%R')
          entry[:hours] = hour_time(hours)
          pay = hours * @pay_rate
          daily_pay += pay
          entry[:pay] = format_pay(pay)

          entries << entry

          pay = ot_hours * @pay_rate * 1.5
          entry = {
            hours: hour_time(ot_hours),
            start: change.strftime('%R'),
            end: clock.end.strftime('%R'),
            note: 'Continue previous line (OT)',
            day: ''
          }
        else
          pay = @pay_rate * hours
        end

        entry[:pay] = format_pay(pay)
        daily_pay += pay

        entries << entry
      end

      total_pay += daily_pay

      entries << {
        day: '',
        start: '###',
        end: '###',
        note: "Daily Total",
        hours: hour_time(daily_hours),
        pay: format_pay(daily_pay)
      }
    end

    {
      entries: entries,
      start_date: days.keys.first,
      end_date: days.keys.last,
      rate: format_pay(@pay_rate),
      t_hours: total_hours(@current),
      t_pay: format_pay(total_pay)
    }
  end

  def format_pay(pay)
    '$%.2f' % pay
  end

  def hour_time(duration)
    '%3.2f' % duration.round(2)
  end

  def total_hours(entries)
    '%3.2f' % entries.inject(0) { |m, e| m + e.duration / 3600.0 }.round(2)
  end

  def compute_pay(time)
    (@pay_rate * time)/3600
  end

  def output
    compute!.to_json
  end
end
