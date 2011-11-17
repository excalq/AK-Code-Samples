# Read OregonTrail ini file (Used both by CakePHP App and Capistrano recipe)


# (Internal helping module) 
# = Hash Recursive Merge
# 
# Merges a Ruby Hash recursively, Also known as deep merge.
# Recursive version of Hash#merge and Hash#merge!.
# 
# Category::    Ruby
# Package::     Hash
# Author::      Simone Carletti <weppos@weppos.net>
# Copyright::   2007-2008 The Authors
# License::     MIT License
# Link::        http://www.simonecarletti.com/
# Source::      http://gist.github.com/gists/6391/
#
module HashRecursiveMerge
	def rmerge(other_hash)
	  r = {}
	  merge(other_hash)  do |key, oldval, newval| 
		r[key] = oldval.class == self.class ? oldval.rmerge(newval) : newval
	  end
	end
end

class Hash
	include HashRecursiveMerge
end


# 
# = Read RTW Oregon Trail configuration file
# 
# Reads the configuration ini file used by Oregon Trail
# And builds ruby hashes of the data, which is used by Capistrano.
#
class Oregontrail_ini_reader
	
	def initialize
		require 'pp' # Pretty print
		@content = Hash.new
	end
	
	def read_config(config_file)
		ini_content = read_ini_file(config_file)

		# Return true if content read, false if not
		return ini_content ? true : false
	end
		
	def get_config(type = "")
		case type
		when ""
			return @content
		when nil
			return @content
		when 'environment'
			return @content['environment']
		when 'application'
			return @content['application']
		when 'oregontrail'
			return @content['oregontrail']
		when 'repository'
			return @content['repository']
		else
			puts "*** ERROR: Unrecognized config type requested."
			return false
		end
	end

	private # all methods that follow will be made private: not accessible for outside objects
	
	def build_key_recursive(key_tokens, value)
		if (key_tokens.nil? or key_tokens.empty? or key_tokens == '')
			return value
		else
			return {key_tokens.shift => build_key_recursive(key_tokens, value)}
		end
	end
	
	def read_ini_file(config_file)
		# Read the ini file
		File.open(config_file, 'r') do |inFile|
			inFile.each_line do |line|
				# foo is the entry you want to change, baz is its new value.
				#outFile.puts(line.sub(/foo=(.*)/, 'foo=baz'))
				
				# Ignore PHP die() line
				next if line.match('<\?php.*\?>')
				
				# Ignore Whole-line Comments and empty lines
				next if not line.match('^[a-zA-Z0-9\[]')
				
				# Trim whitespace in lines
				line.strip!
				# remove tab characters
				line.gsub!("\t", ' ')
				
				m = line.split('=')
				key = m[0].strip
				value = m[1]
				value = value.match('[\"\'](.*)[\"\']')[1].strip
				
				if (not key.nil? and not value.nil?)
					#puts(key + " => " + value)
					
					# Build multi-dimensional array of key tokens
					key_set = key.split('.')
					config_line_array = Hash.new
					config_line_array = build_key_recursive(key_set, value)
					
					#pp(config_line_array)
					
					# Merge key-value arrays together, save in class variable
					@content = @content.rmerge(config_line_array)
				end
			end
		end
		
		# Return true if content read, false if not
		return @content ? true : false

	end
end

# Test function for using this class:
#
#
#def test_output
#	
#	config_file = '../../../app/config/config.ini.php'
#	
#	ot_ini_reader = Oregontrail_ini_reader.new
#	ini_parsed = ot_ini_reader.read_config(config_file)
#	
#	if ini_parsed
#		puts "--- ENVIRONMENT ---"
#		pp ot_ini_reader.get_config('environment').sort
#		
#		puts "--- APPLICATIONS ---"
#		pp ot_ini_reader.get_config('application').sort
#		
#		puts "--- OREGONTRAIL ---"
#		pp ot_ini_reader.get_config('oregontrail').sort
#	else
#		puts "*** ERROR: Could not read Oregon Trail Config."
#	end
#
#end

