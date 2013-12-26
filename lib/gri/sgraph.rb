# -*- coding: utf-8 -*-
module GRI
  class Sgraph
    @height = 20

    def initialize options
      @options = options
    end

    BARS = [" ",  "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" ]
    def bar(val, unit, non_fullwidth_font = false)
      n = (val.to_f/unit)
      @height.times.map{|i|
        x = n - (i * 8)
        if x <= 0
          BARS.first
        else
          bar_symbol = if x < 8
                         BARS[x]
                       else
                         BARS.last
                       end
          bar_symbol += " " if non_fullwidth_font
          bar_symbol
        end
      }
    end

    def render(json, summary, url = nil)
      #@options = {:t=>'d', :non_fullwidth_font=>false}
      @height = 16
      rowss = json['data']
      meta = json['meta']
      step    = meta['step']
      start_timestamp = meta["start"]
      end_timestamp   = meta["end"].to_i
      s = Time.at(start_timestamp).localtime.strftime("%Y-%m-%d %H:%M:%S")
      e = Time.at(end_timestamp  ).localtime.strftime("%Y-%m-%d %H:%M:%S")

      rowss.transpose.each_with_index {|rows, i|
        #puts "i: #{i}"
        max     = rows.flatten.compact.max

        u0 = (max / @height)
        ex0 = (Math.log(u0) / Math.log(10)).floor
        unit = (u0 / 8 / (10**(ex0-1))).ceil * (10**(ex0-1))

        max_val = unit*@height
        #max_val = max
        #unit    = max_val / (@height * 8).to_f

        puts "    #{(url)}"
        puts "    #{s} -"
        puts "  #{meta['legend'][i].center(78)}"
        render_graph rows, unit
        render_x_axis_labels(rows, start_timestamp, step)
        puts ""

        #sums = summary.first.last
        #puts "    #{sprintf("cur: %.1f  ave: %.1f  max: %.1f  min %.1f", *sums)}"
      }
    end

    def render_graph rows, unit
      result = []

      rows.map{|row|
        bar(row, unit, @options[:non_fullwidth_font])
      }.transpose.reverse.each_with_index do |row, i|
        i = (@height- i)
        if i.even?
          n = unit * i * 8
          if n > 10
            label = sprintf("%6s", to_scalestr(unit * i * 8))
          else
            label = sprintf("%6g", unit * i * 8)
          end
        else
          label = ''
        end
        line = row.join
        if color = @options[:color]
          line = Term::ANSIColor.send(color, line)
        end
        result << "#{sprintf('%6s', label)}|#{line}|"
      end
      puts result.join("\n")
    end

    def to_scalestr v, base=1000
      if v == nil or base == nil or base == 0
        return(v.to_i == v ? v.to_i : v)
      end
      v = v.to_f
      if v >= base ** 4
        "%gT" % (v / (base ** 4))
      elsif v >= base ** 3
        "%gG" % (v / (base ** 3))
      elsif v >= base ** 2
        "%gM" % (v / (base ** 2))
      elsif v >= base
        "%gK" % (v / base)
      else
        v.to_s
      end
    end

    def render_x_axis_labels(rows, start_timestamp, step)
      tm = rows.size * step

      x_axis_labels = rows.length.times.select{|n| n % 8 == 0}. map{|n|
        t = Time.at(start_timestamp + (n * step)).localtime
        sprintf("%-8s", to_axis_label(t, tm))
      }.join
      x_axis_arrows= rows.length.times.select{|n| n % 8 == 0}. map{|n|
        " /      "
      }.join

      case 'show'#@options[:x_axis_label]
      when "show"
        puts sprintf("%6s%s", "", x_axis_arrows)
        puts sprintf("%6s%s", "", x_axis_labels)
      when "simple"
        puts sprintf("%6s%s", "", x_axis_labels)
      end
    end

    def to_axis_label t, tm
      f = if tm <= 3600
            '%M'
          elsif tm <= 48*3600
            '%H:%M'
          elsif tm <= 8*24*3600
            '%a'
          elsif tm <= 35*24*3600
            '%d'
          else
            '%m'
          end
      t.strftime f
    end

    TERMS = {'sh'=>['Hour', 3600], 's8h'=>['8Hours', 8*3600],
      'd'=>['Day', 24*3600], 'w'=>['Week', 7*24*3600],
      'm'=>['Month', 31*24*3600], 'y'=>['Year', 366*24*3600]}
  end
end
