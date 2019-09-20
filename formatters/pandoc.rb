class Timetrap::Formatters::Pandoc
  attr_accessor :output
  include Timetrap::Helpers

  def initialize entries
    pay_rate = Timetrap::Config['pay_rate'].match(/\A(\D*)([\d\.]+)(\D*)\Z/).captures[1].to_f
    cpay = lambda {|time| (pay_rate * time)/3600}
    format_pay = lambda {|pay| '$%.2f' % pay}

    self.output = ''

    self.output << "# Invoice for development services\n"
    sheets = entries.inject({}) do |h, e|
      h[e.sheet] ||= []
      h[e.sheet] << e
      h
    end
    gpay = 0;
    sheets.keys.sort.each do |sheet|

      self.output << <<-INFO.gsub(/^ */, '')
        ## #{sheet}

        ### Payable to:
        Winston Durand  \nADDRESS

        ### Billed to:
        FORT Systems  \nADDRESS
      INFO
      show_id = Timetrap::CLI.args['-v']
      last_start = nil
      from_current_day = []
      spay = 0
      tpay = 0;

      headers = ["ID", "Day", "Start", "End", "Duration", "Pay", "Description"]
      headers.delete_at(0) unless show_id

      self.output << "\n| #{headers.join(' | ')} |\n"
      self.output << "|#{' --- |' * headers.length}\n"

      sheets[sheet].each_with_index do |e, i|
        from_current_day << e
        pay = cpay.call(e.duration)
        spay += pay
        tpay += pay
        gpay += pay

        note = e.note.gsub('|', '\|')

        values = [
          (show_id ? e.id : nil),
          format_date_if_new(e.start, last_start),
          format_time(e.start),
          format_time(e.end),
          format_duration(e.duration),
          format_pay.call(pay),
          note
        ].compact

        self.output <<  "| #{values.join(' | ')} |\n"

        nxt = sheets[sheet].to_a[i+1]
        if nxt == nil or !same_day?(e.start, nxt.start)
          self.output <<  "#{'|  ' * (values.length - 3)}| %s | %s |  |\n" % [format_total(from_current_day), format_pay.call(spay)]
          spay = 0
          from_current_day = []
        else
        end
        last_start = e.start
      end
      self.output << "\n---\n"
      self.output <<  "\n|  | Time | Pay |\n| --- | --- | --- |\n"
      self.output <<  "| Total | #{format_total(sheets[sheet])} | #{format_pay.call(tpay)} |\n"
    end
    if sheets.size > 1
      self.output << "\n---\n"
      self.output <<  "\n|  | Time | Pay |\n| --- | --- | --- |\n"
      self.output <<  "| Grand Total | #{format_total(sheets[sheet])} | #{format_pay.call(tpay)} |\n"
    end
  end
end
