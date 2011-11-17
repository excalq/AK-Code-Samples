# RTW - Deployment Script for Capistrano Deployment Softwaere
#
# Author: Arthur Ketcham <dev@arthurk.com>
# 2009-11
#
#  PROCEDURE:
#	1) Set up each new target host's directory structure (do this once per host):
#     	 cap -vvv -f app/config/capfiles/oregontrail.capfile.rb -S environment=[environment] -S application=[application] deploy:setup
#   2) Adjust Apache config to point to [web-app]/current/ as the app's web root
#	3) Run deployment:
#		 cap -vvv -f app/config/capfiles/oregontrail.capfile.rb -S environment=[environment] -S application=[application] deploy:run_deployment
#
# Parameters:
# -S application=(application)
# -S environment=(environment)
# -S hosts=[host1,host2,host3] (Sq. Brackets required.) (These are the hosts which tasks are ran against, they don't allow any not in the predefined sets though)
# -S current_ot_host=(full host name of oregon trail server, if not set defaults to capistrano.bdr.realtimeworlds.com)
# 
#

require 'capistrano/version'
require 'pp' # Pretty print, for hashes
load 'deploy'

require '../app/vendors/capistrano/config-ini-parser.rb'

# =============================================================================
# RETURN STATUS CONSTANTS (Keep in sync with PHP capistrano vendor class)
# =============================================================================
OK                  = 1;
FAILURE             = 2;
APP_NOT_FOUND       = 3;
ENV_NOT_FOUND       = 4;
DEPS_NOT_MET        = 5;
GIT_ERROR           = 6;
REMOTE_ACCESS_ERROR = 7;
DEPLOYMENT_ERROR    = 8;
TESTING_ERROR       = 9;
TESTING_FAILURE     = 10;
CONFIG_ERROR        = 11;



# =============================================================================
# CONFIGURATION AND INITIALIZATION
# =============================================================================

# Include Oregon Trail configuration
ot_config_file = '../app/config/config.ini.php'
ot_ini_reader = Oregontrail_ini_reader.new
ini_parsed = ot_ini_reader.read_config(ot_config_file)

if ini_parsed
	$config = Hash.new
	$config['environment'] = ot_ini_reader.get_config('environment').sort
	$config['application'] = ot_ini_reader.get_config('application').sort
	$config['oregontrail'] = ot_ini_reader.get_config('oregontrail').sort
	$config['repository']  = ot_ini_reader.get_config('repository').sort
	
	# Chunks of the above configs relevant to this OT install
	$config['oregontrail_this'] = Hash.new # To Be populated in parse_config()
	$config['repository_this']  = Hash.new # To Be populated in parse_config()
	
else
	puts "*** ERROR: Unable to read Oregon Trail Configuration File"
	exit
end


# Get Oregon Trail local install configuration, Get Repository configuration
def parse_config(current_ot_host)

	puts "*** INFO: Parsing OT Config"
	puts
	puts current_ot_host

	# Get oregon trail configuration for this OT install
	if $config['oregontrail'].is_a? Array
		$config['oregontrail'].each do |key, ot_install|
			if (ot_install['name'] == current_ot_host)
				$config['oregontrail_this'] = ot_install
				break
			end
		end
	else
		puts "ERROR: Oregon Trail config is malformed in section \"oregontrail\"."
		exit(CONFIG_ERROR)
	end
	
	# Get repository information for this OT install
	if $config['oregontrail_this']['repository'].nil?
		puts "ERROR: Oregon Trail config is does not have repository set for this OT install."
		exit(CONFIG_ERROR)
	end
	if $config['repository'].is_a? Array
		$config['repository'].each do |key, repo_this|
			if (repo_this['name'] == $config['oregontrail_this']['repository'])
				$config['repository_this'] = repo_this
				break
			end
		end
	else
		puts "ERROR: Oregon Trail config is malformed in section \"repository\"."
		exit(CONFIG_ERROR)
	end
	
	# Get repository information for this OT install
	if $config['oregontrail_this']['repository'].nil?
		puts "ERROR: Oregon Trail config is does not have repository set for this OT install."
		exit(CONFIG_ERROR)
	end
	if $config['repository'].is_a? Array
		$config['repository'].each do |key, repo_this|
			if (repo_this['name'] == $config['oregontrail_this']['repository'])
				$config['repository_this'] = repo_this
				break
			end
		end
	else
		puts "ERROR: Oregon Trail config is malformed in section \"repository\"."
		exit(CONFIG_ERROR)
	end
	
	# pp $config['oregontrail_this']
	#pp $config['repository_this']
	
	puts "INFO: Respository server is #{$config['repository_this']['host']}"

end

# Get Application configuration data
# Usage1: this_app_array = get_application(application)
# Usage2: this_app_label = get_application(application, 'label')
def get_application(application, parameter = nil)
	
	# Get matching config block
	config_block = Hash.new
	$config['application'].each do |key, block|
		if block['name'] == application
			config_block = block
			break
		end
	end
	
	if config_block.empty?
		return false
	end
	
	# Find the array block of $config['application'] for this app.
	# Return the bit requested by parameter if specified, or
	# whole block if not requested
	if parameter
		if config_block.has_key?(parameter)
			return config_block[parameter]
		else
			# app.parameter did not exist
			return false
		end
	else
		# return whole block
		return config_block
	end
end

# Get Environment configuration data
# Usage1: this_env_array = get_environment(environment)
# Usage2: this_env_label = get_environment(environment, 'label')
def get_environment(environment, parameter = nil)
	
	# Get matching config block
	config_block = Hash.new
	$config['environment'].each do |key, block|
		if block['name'] == environment
			config_block = block
			break
		end
	end
	
	if config_block.empty?
		return false
	end
	
	# Find the array block of $config['environment'] for this app.
	# Return the bit requested by parameter if specified, or
	# whole block if not requested
	if parameter
		if config_block.has_key?(parameter)
			return config_block[parameter]
		else
			# env.parameter did not exist
			return false
		end
	else
		# return whole block
		return config_block
	end
end

# Return array of hosts in this environment
def get_environment_hosts(environment)
	return get_environment(environment, 'hosts').values
end


# =============================================================================
# DEFAULT VARIABLE SETTING AND VALIDATION
# =============================================================================

unless variables.include?(:current_ot_host)
	set :current_ot_host, "[none]"
	puts "INFO: Current OT Host set to \"#{current_ot_host}\""
end

unless variables.include?(:environment)
	set :environment, "[none]"
end

unless variables.include?(:application)
	set :application, "[none]"
end

unless variables.include?(:app_version)
	set :app_version, ""
end

unless variables.include?(:app_branch)
	set :app_branch, "HEAD"
end


# Read configuration data into Capistrano
parse_config(current_ot_host)

# =============================================================================
# SSH OPTIONS
# =============================================================================

set :git_user, "stork"    # SSH account to log in to local machine (where master git repo is)
set :user,     "stork"    # SSH user to remote hosts

#set :group,    "gitusers"
#ssh_options[:keys] = %w(config/deploy/id_rsa)
ssh_options[:paranoid] = false
#ssh_options[:verbose] = :debug

ssh_options[:user] = 'stork'
# ssh_options[:verbose] = :debug

default_run_options[:pty] = true
set :use_sudo, false


# =============================================================================
# SCM Repository Config (Git, etc.)
# =============================================================================

set :scm, :git
set :scm_verbose, true

set :repository_server, $config['repository_this']['host']
set :repository_path, $config['repository_this']['path']
set :branch, app_branch

set :repository,  "#{git_user}@#{repository_server}:#{repository_path}/#{application}"

# There was a previous bug which is noted in an RTW ticket (which?)
set :copy_exclude, [".git", ".DS_Store", "capfile", "Capfile"]



# =============================================================================
# TASKS
# =============================================================================
# Define tasks that run on all (or only some) of the machines. You can specify
# a role (or set of roles) that each task should be executed on. You can also
# narrow the set of hosts to a subset of a role by specifying options, which
# must match the options given for the hosts to select (like :primary => true)

# todo: before :deploy,              :start_timer

#before :deploy,                 'deploy:push_local_changes'
before "deploy:setup", :set_hosts
before "deploy:setup", :set_deploy_variables
after  "deploy:update", "deploy:cleanup"

namespace :deploy do
	
	if dry_run == true
		puts "**** DRY RUN ONLY ****"
	end
	
	task :default do
		puts "ERROR: You must run either deploy:setup or deploy:run_deployment tasks, and specify the application and environment"
	end
	
	task :run_deployment do
		puts "* executing deployment of #{application} to host #{environment}"
		transaction do
			set_hosts
			set_deploy_variables
			deploy_app
			update_code
			
			link_persistent_data
			post_deployment.disable_debug_reporting
			create_version_file
			
			# Do this last - it is where the new release dir is symlinked to current/
			symlink
		end
	end
	
	
	# Default Hooks
	task :after_deploy do
		cleanup
	end
	
end
#####################################


# =============================================================================
# INIT HOSTS DATA
# Per Environment there is a default predefined list of hosts.
#
# However, it is possible to pass the parameter "hosts" on the command line
# which will change the default list of 
# =============================================================================
task :set_hosts do
	
	# Use predefined hosts as default. It will be overridden if there are valid hosts in "hosts" argument
	hosts_to_use = get_environment_hosts(environment)
  
	# Detect if the hosts cmd line argument was passed, and is a valid array
	if (variables.include?(:hosts))
		
		# hosts parameter string to array
		# The parameter should be passed like so: -S hosts=[host1,host2,host3] (Square brackets required, and spaces and quotes are optional)
		host_array = hosts.gsub(/[\[\]]/,'').split(/\s*,\s*/)

		# Validate array
		if (host_array.is_a? Array)
			
			# Clear the hosts_to_use array
			hosts_to_use = Array.new
			
			# Validate each host in list against predefined possible hosts (No other hosts may be used)
			host_array.each do |arg_host|
				if (get_environment_hosts(environment).include?(arg_host))
					# Add the argument host to the list of hosts to use
					hosts_to_use << arg_host
					#puts "Using host: #{arg_host}" # === DEBUG ===
				
				else
					puts "NOTICE: Skipping invalid host: #{arg_host}"
				end
			end
			
		else
			puts "***ERROR: Hosts list argument was not a valid array"
		end
	end
	
	puts "-------------"
	puts "Using hosts:"
	puts hosts_to_use
	puts "-------------"
	
	role(:app) { hosts_to_use }

end

# =============================================================================
# INIT VARIABLE DATA
# =============================================================================
# This is only needed to make it possible to switch deploy variables after they've initially been set,
# because some versions of gem/capistrano only sets them once, based on *initial* values of deploy_to

task :set_deploy_variables do
	puts "\n  DEBUG: deploy environment: #{environment}"
	
	# QA Region craziness
	# NOTE: As of 2010-06-02, apb_www, apb_cms, rtw_login, and rtw_www have EU or NA path prefixes. Insert those into the path
	## TODO: Replace with new config option in config.ini for environment.N.deploy_path
	case application
	when "apb_www", "apb_cms", "rtw_login", "rtw_www" then
		eu_region_path = "eu_"
		na_region_path = "na_"
	else
		eu_region_path = ""
		na_region_path = ""
	end
	
	case environment
		######### OREGON TRAIL SERVERS #####
		when "capistrano"  then set :deploy_to, "/var/www/html/#{application}" 
		when "production_eu_linux_mgr"   then set :deploy_to, "/var/www/html/production.fra/#{application}"
		when "production_na_linux_mgr"   then set :deploy_to, "/var/www/html/production.dal/#{application}"
		######### APP TARGET SERVERS #####
		when "development1" then set :deploy_to, "/var/www/html/development/#{application}"
		when "development2" then set :deploy_to, "/var/www/html/development_2/#{application}"
		when "qa1_eu"       then set :deploy_to, "/var/www/html/quality_assurance_1/#{eu_region_path}#{application}"
		when "qa1_na"       then set :deploy_to, "/var/www/html/quality_assurance_1/#{na_region_path}#{application}"
		when "qa2_eu"       then set :deploy_to, "/var/www/html/quality_assurance_2/#{eu_region_path}#{application}"
		when "qa2_na"       then set :deploy_to, "/var/www/html/quality_assurance_2/#{na_region_path}#{application}"
		when "qa3_eu"       then set :deploy_to, "/var/www/html/quality_assurance_3/#{eu_region_path}#{application}"
		when "qa3_na"       then set :deploy_to, "/var/www/html/quality_assurance_3/#{na_region_path}#{application}"
		when "staging_eu"   then set :deploy_to, "/var/www/html/staging.fra/#{application}"
		when "staging_na"   then set :deploy_to, "/var/www/html/staging.dal/#{application}"
		when "production_eu"  then set :deploy_to, "/var/www/html/production.fra/#{application}"
		when "production_na"  then set :deploy_to, "/var/www/html/production.dal/#{application}"
		else 
			puts "  ERROR: Environment: #{environment} is unknown"
			exit(ENV_NOT_FOUND)
	end
	
	set(:releases_path)     { File.join(deploy_to, version_dir) }
	set(:shared_path)       { File.join(deploy_to, shared_dir) }
	set(:current_path)      { File.join(deploy_to, current_dir) }
	set(:release_path)      { File.join(releases_path, release_name) }
end


# =============================================================================
# SET MISC PARAMETERS (SCM, etc.)
# =============================================================================

task :deploy_app do
	
	# DEPRECATED:
	# 		case _deploy_env.downcase
	# 			when "development" then deploy.deploy:development  # call "deploy_development" task
	# 			when "qa"          then deploy.deploy_qa           # call "deploy_qa" task
	# 			when "production"  then deploy.deploy_production   # call "deploy_production" task
	# 			else puts "ERROR: deploy environment was not recognized"
	# 		end
	
	# Remote SCM repo cache is updated and used
	set :deploy_via, :remote_cache
	
	# In old git versions, this breaks deploying via tags
	#set :git_shallow_clone, 1
end


# =============================================================================
# DEPLOY AND ROLLBACK
# =============================================================================
task :update_code, :except => { :no_release => true } do
	
	# Rollback actions
	on_rollback { 
		puts "ROLLBACK: Deleting new release path"
		run "rm -rf #{release_path}; true" # Nukes the new release's directory
	} 
	strategy.deploy!
end


# =============================================================================
# Enables the shell 'dotglob' option to rsync hidden files
# =============================================================================
# AK: This is a workaround for a capistrano bug. See https://capistrano.lighthouseapp.com/projects/8716-capistrano/tickets/140
# Note: this still doesn't fix the issue. Instead, I patched capistrano's source to remove the wildcard glob
task :set_shopt_dotglob do
	run "shopt -s dotglob"
end

# =============================================================================
# Linking persistent files and data to the application deployment
# =============================================================================
# Occurs immediately after new release directory is synlinked to current
task :link_persistent_data do
	
	# NOTE: To be able to test deployments of old versions of applications, I've added
	# " || true" to some lines, to force a successful status return.
	# This is done because old versions of apps often don't have all destination directories for symlinks.
	
	# Symlink config files into the current directory
	case application
	when 'apb_beta'
		
		# For now, just keep static config file in shared/ and simlink it
		run "rm -f #{release_path}/config/config.nexus.inc.sample.php" # Remove sample file pulled from git
		run "rm -f #{release_path}/app/config/config.nexus.inc.php" # Remove nexus file pulled from git
		run "ln -nsf #{shared_path}/config/config.nexus.inc.php #{release_path}/config/ || true"
		
		# static files from shared
		# Persistent (shared) directories and files: Delete the file pulled from git, and replace with a 
		# Symlink to the persistent copy in shared/
		
		puts "\n  INFO: Symlinking APB_Beta persistent files."
		
		# Delete sample files pulled from git, to be out of the way when symlinking
		run "rm -f #{release_path}/config/config.nexus.*"                            
		run "rm -rf #{release_path}/htdocs/forums/customavatars"
		run "rm -rf #{release_path}/htdocs/forums/customgroupicons"
		run "rm -rf #{release_path}/htdocs/forums/customprofilepics"
		run "rm -rf #{release_path}/htdocs/forums/signaturepics"
		run "rm -rf #{release_path}/htdocs/forums/images"
		
		run "ln -nsf #{shared_path}/config/config.nexus.inc.php #{release_path}/config/config.nexus.inc.php || true"
		run "ln -nsf #{shared_path}/media/forums/customavatars #{release_path}/htdocs/forums/ || true"
		run "ln -nsf #{shared_path}/media/forums/customgroupicons #{release_path}/htdocs/forums/ || true"
		run "ln -nsf #{shared_path}/media/forums/customprofilepics #{release_path}/htdocs/forums/ || true"
		run "ln -nsf #{shared_path}/media/forums/signaturepics #{release_path}/htdocs/forums/ || true"
		run "ln -nsf #{shared_path}/media/forums/images #{release_path}/htdocs/forums/ || true"
		
		# TODO: IP-address specific blocking/allowance .htaccess.
		# This file is missing and needs to be recreated
		#run "ln -nsf #{shared_path}/config/forums/admincp/.htaccess  #{release_path}/htdocs/forums/admincp/.htaccess || true"
		
		create_cake_temp_dirs(application)
	when 'apb_cms'
		puts "\n  INFO: Symlinking APB_CMS config files."
		
		run "mkdir -p #{release_path}/config"
		run "rm -f #{release_path}/config/config.nexus.inc.php"
		run "ln -nsf #{shared_path}/config/config.nexus.inc.php #{release_path}/config/"
		
		create_cake_temp_dirs(application)
	when 'apb_www'
		
		# For now, just keep static config file in shared/ and simlink it
		run "rm -f #{release_path}/config/config.nexus.inc.sample.php" # Remove sample file pulled from git
		run "rm -f #{release_path}/app/config/config.nexus.inc.php" # Remove nexus file pulled from git
		run "ln -nsf #{shared_path}/config/config.nexus.inc.php #{release_path}/config/ || true"
		
		# static files from shared
		# Persistent (shared) directories and files: Delete the file pulled from git, and replace with a 
		# Symlink to the persistent copy in shared/
		
		puts "\n  INFO: Symlinking APB_www persistent files."
		
		# Delete sample files pulled from git, to be out of the way when symlinking
		run "rm -f #{release_path}/config/config.nexus.*"                            
		run "rm -rf #{release_path}/htdocs/forums/customavatars"
		run "rm -rf #{release_path}/htdocs/forums/customgroupicons"
		run "rm -rf #{release_path}/htdocs/forums/customprofilepics"
		run "rm -rf #{release_path}/htdocs/forums/signaturepics"
		run "rm -rf #{release_path}/htdocs/forums/images"
		
		run "ln -nsf #{shared_path}/config/config.nexus.inc.php #{release_path}/config/config.nexus.inc.php || true"
		run "ln -nsf #{shared_path}/media/forums/customavatars #{release_path}/htdocs/forums/ || true"
		run "ln -nsf #{shared_path}/media/forums/customgroupicons #{release_path}/htdocs/forums/ || true"
		run "ln -nsf #{shared_path}/media/forums/customprofilepics #{release_path}/htdocs/forums/ || true"
		run "ln -nsf #{shared_path}/media/forums/signaturepics #{release_path}/htdocs/forums/ || true"
		run "ln -nsf #{shared_path}/media/forums/images #{release_path}/htdocs/forums/ || true"
		
		# TODO: IP-address specific blocking/allowance .htaccess.
		# This file is missing and needs to be recreated
		#run "ln -nsf #{shared_path}/config/forums/admincp/.htaccess  #{release_path}/htdocs/forums/admincp/.htaccess || true"
		
		create_cake_temp_dirs(application)
	when 'keymaster'
		puts "\n  INFO: Symlinking Keymaster config files."
	when 'oregontrail'
		run "rm -f #{release_path}/config/config.nexus.inc.sample.php" # Remove sample file
		run "ln -nsf #{shared_path}/config/config.nexus.inc.php #{release_path}/config/"
		
		puts "\n  INFO: Creating OregonTrail temp/cache files."
		
		create_cake_temp_dirs(application)
	when 'rtw_login'
		puts "\n  INFO: Symlinking RTW_Login config files."
	when 'rtw_www'
		puts "\n  INFO: Symlinking RTW_WWW config files."
		
		run "rm -f #{release_path}/htdocs/.htaccess"
		run "rm -f #{release_path}/htdocs/config.nexus.inc.php"
		run "rm -f #{release_path}/wp-content/uploads"
		
		run "ln -nsf #{shared_path}/config/config.nexus.inc.php #{release_path}/"
		run "ln -nsf #{shared_path}/config/.htaccess #{release_path}/"
		run "ln -nsf #{shared_path}/wp-content/uploads #{release_path}/wp-content/"
	when 'ak_cap_test'
		puts "\n  INFO: Symlinking AK_Cap_Test config files."
		run "ln -nsf #{shared_path}/.htaccess #{release_path}/"
		run "ln -nsf #{shared_path}/configfile.sample.php #{release_path}/"
		
		create_cake_temp_dirs(application)
	else              
		puts "\n  ERROR: Application #{application} is unknown."
	end
	
	puts "\n" # Line break before automatic status output
end

# =============================================================================
# Post Deployment Tasks
# TODO: Put more tasks in here when stable
# =============================================================================
namespace :post_deployment do
	
	# =============================================================================
	# Disables App's debug mode for non-dev environments. At the moment, this applies only to CakePHP apps
	# =============================================================================
	task :disable_debug_reporting do
	
		DEV_ENVS = ['development', 'development1', 'development2']
		if not DEV_ENVS.include?(environment)
		
			set_hosts
			set_deploy_variables
			
			# Set Configure::write('debug', n) to "0". For cake apps
			cake_app_dir = get_cake_app_dir(application) # Also tests if app is a cake app
			if cake_app_dir
				config_core_path = "#{release_path}/#{cake_app_dir}/config/core.php"
				if remote_file_exists?(config_core_path)
					puts "\n  INFO: Disabling Debug Mode in Deployed Application"
					run "sed -i \"s/Configure::write('debug',[ ]*[1-9]);/Configure::write('debug', 0);/\" #{config_core_path}"
				end
			end
		end
		
	end
	
end



# Create empty, writable cache and temp directories
# =============================================================================
# Write a version.txt file to the app's htdocs root, with the current version 
# from the manifest data. Only happens for dev,qa deploys
# =============================================================================
task :create_version_file do
	
	TESTING_ENVS = ['development', 'development1', 'development2', 'qa1_eu', 'qa1_na', 'qa2_eu', 'qa2_na', 'qa3_eu', 'qa3_na', 'capistrano']
	
	if TESTING_ENVS.include?(environment)
		if not app_version.nil?
			case application
			when 'apb_beta'		then webroot = 'htdocs/'
			when 'apb_cms' 		then webroot = 'htdocs/'
			when 'apb_www'		then webroot = 'htdocs/'
			when 'keymaster'	then webroot = 'htdocs/'
			when 'oregontrail'	then webroot = 'htdocs/'
			when 'rtw_login'	then webroot = 'htdocs/'
			when 'rtw_www'		then webroot = '/'
			else puts "\n  ERROR: Application #{application} is unknown."
			end
			
			version = app_version.gsub(/[^a-z0-9\.\-\/\+\(\)]/i, '') # Escape anything unusual since this gets passed via shell
			
			puts "\n  INFO: Creating Version File"
			puts "\n  Running: echo #{version} >> #{release_path}/#{webroot}version.txt"
			
			run "echo '#{app_version}' >> #{release_path}/#{webroot}version.txt"
		end
	end
end

def create_cake_temp_dirs(application)
	
	appdir = get_cake_app_dir(application)
	
	run "mkdir -p #{release_path}/#{appdir}/tmp"
	run "mkdir -p #{release_path}/#{appdir}/tmp/cache"
	run "mkdir -p #{release_path}/#{appdir}/tmp/cache/persistent"
	run "mkdir -p #{release_path}/#{appdir}/tmp/cache/models"
	run "mkdir -p #{release_path}/#{appdir}/tmp/logs"
	run "mkdir -p #{release_path}/#{appdir}/tmp/session"
	run "mkdir -p #{release_path}/#{appdir}/tmp/test"
	
	run "chgrp apache #{release_path}/#{appdir}/tmp/cache"
	run "chgrp apache #{release_path}/#{appdir}/tmp/cache/persistent"
	run "chgrp apache #{release_path}/#{appdir}/tmp/cache/models"
	run "chgrp apache #{release_path}/#{appdir}/tmp/logs"
	run "chgrp apache #{release_path}/#{appdir}/tmp/session"
	run "chgrp apache #{release_path}/#{appdir}/tmp/test"
	
	run "chmod g+rw #{release_path}/#{appdir}/tmp/cache"
	run "chmod g+rw #{release_path}/#{appdir}/tmp/cache/persistent"
	run "chmod g+rw #{release_path}/#{appdir}/tmp/cache/models"
	run "chmod g+rw #{release_path}/#{appdir}/tmp/logs"
	run "chmod g+rw #{release_path}/#{appdir}/tmp/session"
	run "chmod g+rw #{release_path}/#{appdir}/tmp/test"
end

# Get the name of the application directory for cakePHP apps
def get_cake_app_dir(application)
	case application
		when 'apb_beta'		then appdir = 'app_site'
		when 'apb_www'		then appdir = 'app_site'
		when 'apb_cms' 		then appdir = 'app_admin'
		when 'oregontrail'	then appdir = 'app'
		else
			appdir = "" # not cake site
	end
	
	return appdir
end


# =============================================================================
# Verify the date-timestamps of the current and next previous deployment.
#
# Returns whether a the set of last two deployment timestamps are in sync across all hosts
#
# Fetches the name of the directoies containing the current and next previous deployment, and compares the sets.
# This dir name is a datetime stamp.
# This task is run ahead of approval of a requested "undo last deploy" operation.
#
# If the set of current and next previous timestamps differ between hosts, an error is thrown to be handled in OregonTrail
#
#
# =============================================================================
desc "Return the name of the directory containing the previous deployment"
task :verify_rollback_timestamps do
	

########################################
#
# Refactoring wishlist:
#
# - It should:
#	a) Revert the symlink to next oldest version
#	b) Move lastest release out of the way
#	c) Notify with simple list of new version (or error) on each host
#
#
#
#
########################################

	set_hosts
	set_deploy_variables # this sets :deploy_to
	
	# Show dates of current and previous deployments
	find_command = "echo -n `ls -1 #{deploy_to}/releases/ | grep -v undep |sort -r |head -n 2`" # echo keep output on the same line
	
	find_deploys = Hash.new
	run find_command do |channel, stream, data|
		if (data.match(/[0-9]+\s[0-9]+/)) # Regex for two timestamps sep. by space
			find_deploys[channel[:host]] = {'To Delete:' => data.match(/([0-9]+)\s([0-9]+)/)[1], 'To Restore:' => data.match(/([0-9]+)\s([0-9]+)/)[2]} # The colon in key name seems important to hash printing order (?)
		else
			find_deploys[channel[:host]] = {'To Delete:' => '[NONE]', 'To Restore:' => '[NONE]'}
		end
	end

	# Pretty Print of timestamped deployment directories (For PHP to parse)
	puts "\nCurrent/Restorable Dates/Times:"
	pp find_deploys
	puts "\n\n"
	

	# Show versions of current and previous deployments
	# This command is complex because cat hangs on blank input (if find was unsuccessful)
	version_command = "cd #{deploy_to} && VERSIONS=$(find . -name version.txt | grep -v undep |sort -r |head -n 2 |xargs cat |xargs echo); if [ \"$VERSIONS\" ]; then echo \"$VERSIONS\"; else echo 'VersionUnknown VersionUnknown'; fi"
	
	puts version_command 
	
	dep_versions = Hash.new
	run version_command do |channel, stream, data|
		puts data
		if (data.match(/([0-9\.\-\+\(\)_a-zA-Z]+)\s([0-9\.\-\+\(\)_a-zA-Z]+)/) and not data.match(/can\'t cd to/)) # Regex for two Git tags sep. by space (and if cd did't fail)
			dep_versions[channel[:host]] = {'To Delete:' => data.match(/([0-9\.\-\+\(\)_a-zA-Z]+)\s([0-9\.\-\+\(\)_a-zA-Z]+)/)[1], 'To Restore:' => data.match(/([0-9\.\-\+\(\)_a-zA-Z]+)\s([0-9\.\-\+\(\)_a-zA-Z]+)/)[2]}
		else
			dep_versions[channel[:host]] = {'To Delete:' => '[NONE]', 'To Restore:' => '[NONE]'}
		end
	end
	


	# Pretty Print of timestamped deployment directories (For PHP to parse)
	puts "\nCurrent/Restorable Versions:"
	pp dep_versions
	puts "\n\n"

	
	# Compare timestamps of deployment sets on all hosts. If there was only one host, it's always considered a match
	match = false
	time = nil
	find_deploys.each do |keys, deptimes|
		if (deptimes)
			if (time.nil?) # First occurance, set time
				time = deptimes
				match = true
			elsif (deptimes == time) # Compare against previous time
				match = true
			else # Second occurance did not match first
				match = false
			end
		end
	end
	
	# Print result status to be parsed by Oregon Trail
	if match
		puts "** SUCCESS ** Deploy times matched.\n"
	else
		puts "** FAILURE ** Deploy times did not match on all hosts.\n"
	end

end

# =============================================================================
# This reverts the application's "current" symlink back to the previous deployment version
# This is done using the most recent timestamp directory, and it is done on all
# hosts specified.
#
# Note on error conditions. This may finish with "***ERROR" if a problem occured, or it may end prematurely before
# Displaying the final error message. So parse for both "***ERROR" and "Failed:"
#
# It is strongly recommended that :verify_rollback_timestamps is run first to verify matching deploy times across hosts
# Also, moved the rolled back deployment to [dir]-rm to prevent it from interferring with subsequent rollbacks
# =============================================================================
task :undo_last_deployment do

########################################
#
# Refactoring wishlist:
#
# - This is way to complicated, it should simply:
#	a) Revert the symlink to next oldest version
#	b) Move lastest release out of the way
#	c) Notify with simple list of new version (or error) on each host
#
#
#
#
########################################

	set_hosts
	set_deploy_variables
	
	
	deletable_find = "ls -1 #{deploy_to}/releases/ |grep -v undep |sort -r |head -n 1"
	restorable_find = "ls -1 #{deploy_to}/releases/ |grep -v undep |sort -r |head -n 2 | tail -n 1"
	
	# Undo Command - Remove current Symlink, then recreate symlink with link to the next oldest deployment
	undo_command = "cd #{deploy_to}	&& ABSPATH=`pwd` \
	&& CURRDEP=`ls -1 releases/ |grep -v undep |sort -r |head -n 1` \
	&& PREVDEP=`ls -1 releases/ |grep -v undep |sort -r |head -n 2|tail -n 1` \
	&& rm current \
	&& ln -nsf $ABSPATH/releases/$PREVDEP $ABSPATH/current \
	&& mv releases/$CURRDEP releases/$CURRDEP-undep"
		
	# Conduct as transaction
	transaction do
	
		# Get the name of the deletable release (Currently deployed root)
		deletable_dir = Hash.new
		run deletable_find do |channel, stream, data|
			deletable_dir[channel[:host]] = data.gsub(/\r\n|\n|\r/, '') # Trim line endings from data
		end
		
		# Get the name of restorable release (previous deployment)
		restorable_dir = Hash.new
		run restorable_find do |channel, stream, data|
			restorable_dir[channel[:host]] = data.gsub(/\r\n|\n|\r/, '') # Trim line endings from data
		end
		
		# Pretty Print the deletable directories
		puts "\n"
		puts "Undoing the following deployments:"
		pp deletable_dir
		puts "\n"
		
		puts "Restoring the following deployments:"
		pp restorable_dir
		puts "\n"
		
		# Revert the symlink to undo the deployment and restore the previous
		undo_result = Hash.new
		failure = false
		run undo_command do |channel, stream, data|
			undo_result[channel[:host]] = data.gsub(/\r\n|\n|\r/, '') # Trim line endings from data
			if stream == :err
				failure = true
			end
		end
		
		# The command executes silently if successful, so only output stderr data
		puts "\n"
		if failure
			puts "***ERROR:"
			pp undo_result
			puts "\n"
		else
			puts "Rollback successful"
		end
	
	end

end

# =============================================================================
# Clear remote Git cache (present under app/shared/ on the target host
# The cache gives much faster incremental deploys, but for large changes in an app
# or significant downgrades/upgrades, git will choke on unusable cache data
# and throw an error: "fatal: Could not parse object '[sha-hash]'."
# =============================================================================
desc "Clear the remote cache"
task :clear_remote_cache, :roles=>[:app] do
	
	set_hosts
	set_deploy_variables
	
	puts "\n  Clearing deployment cache in #{shared_path}/cached-copy"
	run "rm -rf #{shared_path}/cached-copy"
	puts "\n\n"
end




# =============================================================================
# TESTING: General Test Function
# =============================================================================
desc "Test Function 1"
task :test_function do
	puts "TEST FUNCTION"

	# TESTING
	#pp get_application(application, 'environment')
	
	#pp get_environment(environment, 'label')
	
	#####
	
	
end


# =============================================================================
# Internal tool: Simple shell command escaping
# =============================================================================
def shell_escape(str)
	String(str).gsub(/(?=[^a-zA-Z0-9_.\/\-\x7F-\xFF\n])/n, '\\').
	gsub(/\n/, "'\n'").
	sub(/^$/, "''")
end

# =============================================================================
# Internal tool: Check for file existence
# =============================================================================
def remote_file_exists?(full_path)
  'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
end

