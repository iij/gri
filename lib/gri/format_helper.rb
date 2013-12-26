require 'erb'
require 'rack/utils'

module GRI
  module FormatHelper
    HTML_ESCAPE = {'&' => '&amp;', '>' => '&gt;', '<' => '&lt;',
      '"' => '&quot;', "'" => '&#39;'}
    HTML_ESCAPE_ONCE_REGEXP = /["><']|&(?!([a-zA-Z]+|(#\d+));)/

    def h obj
      case obj
      when String
        Rack::Utils.escape_html obj
      else
        Rack::Utils.escape_html obj.inspect
      end
    end

    def escape_once s
      s.to_s.gsub(HTML_ESCAPE_ONCE_REGEXP) {HTML_ESCAPE[$&]}
    end

    def u str
      Rack::Utils.escape str
    end

    def url_to arg, q={}
      script_name = ENV['SCRIPT_NAME'] || ''
      if String === arg
        (arg[0] == ??) ? script_name + arg :
          (script_name + '/' + arg + mk_query(q))
      else
        ''
      end
    end

    def mk_query h
      return '' unless Hash === h and !h.empty?
      '?' + h.map {|k, v| v && "#{k}=#{u v}"}.compact.join('&')
    end

    def td arg, options={}
      tag = options[:head] ? 'th' : 'td'
      args = (Array === arg) ? arg : [arg]
      res = []
      for arg in args
        s = [:class, :colspan].map {|s|
          options[s] ? "#{s}=#{options[s]}" : nil}.compact.join ' '
        res.push "<#{tag}#{s.empty? ? '' : ' '+s}>#{arg}</#{tag}>"
      end
      res.join ''
    end

    def mk_tag tag, attrs, body=nil
      "<#{tag}" + attrs.map {|k, v|
        v ? ((v == true) ? ' ' + k : " #{k}=\"#{h v}\"") : nil
      }.join('') + (body ? ">#{body}</#{tag}>" : "/>")
    end

    def text_field name='', value=nil, size=40, maxlength=nil, cl='form-control'
      attrs = {'type'=>'text', 'name'=>name, 'value'=>value, 'size'=>size.to_s,
        'class'=>cl}
      attrs['maxlength'] = maxlength.to_s if maxlength
      mk_tag 'input', attrs
    end

    def hidden name, value
      mk_tag 'input', [['name', name], ['value', value], ['type', 'hidden']]
    end

    def radio_button name='', value=nil, checked=nil
      mk_tag 'input', 'type'=>'radio',
        'name'=>name, 'value'=>value, 'checked'=>checked
    end

    def check_box name='', value=nil, checked=nil
      mk_tag 'input', 'type'=>'checkbox',
        'name'=>name, 'value'=>value, 'checked'=>checked
    end

    def popup_menu name, cl, *ary
      body = ary.map {|value, s, selected_p|
        attrs = [['value', value]]
        attrs.push ['selected', true] if selected_p
        mk_tag 'option', attrs, s
      }.join ''
      mk_tag 'select', [['name', name], ['class', cl]], body
    end

    def render template, b=nil
      ERB.new(template, nil, '-').result(b || binding)
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
  end
end
