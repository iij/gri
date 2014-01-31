module GRI
  module Bootstrap
    extend Bootstrap
    def layout
      <<EOS
<!DOCTYPE html>
<html>
<head>
<title><%= @title %></title>
<style>
span.large {font-size: x-large;}
table.ds {margin-bottom: 2px;}
table.ds td {padding:0;background:#f9f9f9; border-collapse: separate;}
table.ds th {background:#ffd0d0;
background:linear-gradient(to bottom, #ffd8d8 0%,#ffcccc 45%,#ffc0c0 100%);
text-align:left;}
hr {border:none;border-top:1px #cccccc solid;}
</style>
<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.1.0/css/bootstrap.min.css">
<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.1.0/css/bootstrap-theme.min.css">
</head>

<body>

<div class="navbar navbar-static-top navbar-inverse">
  <div class="container">
    <div class="navbar-header">
      <a class="navbar-brand" href="<%= url_to ''%>">GRI</a>
    </div>
  </div>
</div>

<div class="container">
<%= yield %>
</div>

<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js">
</script>
<script src="//netdna.bootstrapcdn.com/bootstrap/3.1.0/js/bootstrap.min.js"></script>
</body>
</html>
EOS
    end
  end

  class Grapher
    def public_dir
      File.dirname(__FILE__) + '/../../../public'
    end

    def self.layout
      Bootstrap.layout
    end
  end

  class Cast
    def public_dir
      File.dirname(__FILE__) + '/../../../public'
    end

    def self.layout
      Bootstrap.layout
    end
  end
end
