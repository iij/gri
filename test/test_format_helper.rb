require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/format_helper'

module GRI

class TestFormatHelper < Test::Unit::TestCase
  include FormatHelper

  def test_format_helper_h
    ae "&lt;&#x2F;br&gt;", h('</br>')
    ae "[nil]", h([nil])
  end

  def test_format_helper_escape_once
    ae '&amp;', escape_once('&')
    ae '&amp;', escape_once('&amp;')
  end

  def test_format_helper_u
    ae "_%3A%3C%3E%5C%25", u('_:<>\%')
  end

  def test_format_helper_url_to
    ae '/aaa', url_to('aaa')
    ae '?a=1', url_to('?a=1')
    assert_match %r{\A/aaa\?[ab]=[^&]+&}, url_to('aaa', :a=>1, 'b'=>'"')
  end

  def test_format_helper_mk_query
    ae '?a=1', mk_query(:a=>1)
    assert_match /\bb=a\+%26\b/, mk_query(:a=>1, :b=>'a &')
    #assert_not_match /\bc=/, mk_query(:c=>nil)
    assert(/\bc=/ !~ mk_query(:c=>nil))
  end

  def test_format_helper_td
    ae '<td>item</td>', td('item')
    ae '<th>item</th>', td('item', :head=>true)
    ae '<td colspan=2>item</td>', td('item', :colspan=>2)
  end

  def test_format_helper_mk_tag
    ae '<a href="&#x2F;">top</a>', mk_tag('a', {:href=>'/'}, 'top')
  end

  def test_format_helper_text_field
    t = text_field('text', 'aaa', 40, nil, nil)
    s = t.scan(/\b(\w+="[^\"]+")/).flatten.sort
    assert_equal ['name="text"', 'size="40"', 'type="text"', 'value="aaa"'], s
    assert_match /<input\s+.*\/>/, t #/
  end

  def test_format_helper_popup_menu
    a = [[1, 'a'], [2, 'b'], [3, 'c', true]]
    ae '<select name="popup"><option value="1">a</option><option value="2">b</option><option value="3" selected>c</option></select>',
      popup_menu('popup', nil, *a)
  end

  def test_format_helper_to_scalestr
    assert_nil to_scalestr(nil)
    ae '0.0', to_scalestr(0)
    ae '1.024K', to_scalestr(1024)
    ae '1K', to_scalestr(1024, 1024)
    ae '1.234M', to_scalestr(1234000)
    ae '1.234G', to_scalestr(1234000000)
    ae '1.234T', to_scalestr(1234000000000)
  end
end

end
