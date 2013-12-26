def Marshal.dump_to_file obj, path
  tmppath = path + ".tmp#{$$}"
  open(tmppath, 'w') {|f| Marshal.dump obj, f}
  File.rename tmppath, path
end

def Marshal.load_from_file path
  obj = nil
  if File.size? path
    open(path) {|f| obj = Marshal.load(f) rescue nil}
  end
  obj
end
