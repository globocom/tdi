module HashRecursiveBlank
  def rblank
    r = {}

    each_pair do |key, val|
      r[key] = val.rblank if val.is_a?(Hash)
    end

    r.keep_if { |key, val| val.is_a?(Hash) }
  end

  def rblank!
    each_pair do |key, val|
      self[key] = val.rblank! if val.is_a?(Hash)
    end

    keep_if { |key, val| val.is_a?(Hash) }
  end
end

class Hash
  include HashRecursiveBlank
end
