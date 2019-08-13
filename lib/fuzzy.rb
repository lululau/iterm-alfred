class Fuzzy
  class << self
    def parse_pattern(str)
      Regexp.new(str.split(/\s+/).each_with_object(String.new) do |group, result|
                   if group[0] == "'"
                     result << group[1..-1].gsub(/\./, '\.')
                   else
                     result << group.scan(/./).join('.*')
                   end
                   result << '.*'
                 end)
    end
  end
end

class String
  def fuzzy_matches?(pattern)
    Fuzzy.parse_pattern(pattern) =~ self
  end
end
