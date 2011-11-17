<?php
/**
 * A Capistrano interface for CakePHP
 * Copyright (C) 2009 Kaskadia Software Studios, LLC
 * Written by Arthur Ketcham <dev@ArthurK.com>
 * 
 */

/**
 * Interface to Capistrano shell script
 */
 
 
 
 /////////////////////////////////////
 /*
 
 This will run capistrano shell commands, using the capistrano config file in 
 ../../../capfiles/
 
 It will return the following data:
	- deployment log
	- rollback log
	- deployment outcome
	- status code
 
 It will provide the following methods:
	- constructor($application, $environment, $dry_run)
	- check_deps()
	- run_deployment()
	- disable_maintenance_page()
	- revert_symlink($release)
	- get_formatted_log($log_type)
	- format_log_data($data)
	
 Example Command line:
 cap -vvv -f app/config/capfiles/oregontrail.capfile.rb -S environment=[environment] -S application=[application] -S app_version=[version] -S app_branch=[branch] deploy:run_deployment
 
 */
 /////////////////////////////////////
 
 
class Capistrano extends Object
{
	/**#@+
	 * Deployment result status
	 * These status codes should also be used
	 * in the capfile script
	 * TODO: USE THESE
	 */
	const OK                  = 1;
	const FAILURE             = 2;
	const APP_NOT_FOUND       = 3;
	const ENV_NOT_FOUND       = 4;
	const DEPS_NOT_MET        = 5;
	const GIT_ERROR           = 6;
	const REMOTE_ACCESS_ERROR = 7;
	const DEPLOYMENT_ERROR    = 8;
	const TESTING_ERROR       = 9;
	const TESTING_FAILURE     = 10;
	/**#@-*/

	/** @var string Object description */
	public $description = 'Interface to a Capistrano deployment script';

	private $ot_host;
	private $application;
	private $hosts;
	private $app_version;
	private $app_branch;
	private $environment;
	private $dry_run;
	
	// Keep in sync with bootstrap.php
	private static $ALLOWED_SITES = array(
		'rtw_www',
		'apb_beta',
		'apb_www',
		'apb_cms',
		'rtw_login',
		'keymaster',
		'ak_cap_test',
		'oregontrail'
	);
	
	// Keep in sync with bootstrap.php
	private static $ALLOWED_ENVS = array(
		'capistrano',
		'development',
		'development1',
		'development2',
		'qa1_eu',
		'qa1_na',
		'qa2_eu',
		'qa2_na',
		'qa3_eu',
		'qa3_na',
		'production',
		'production_eu',
		'production_na',
		'production_eu_linux_mgr',
		'production_na_linux_mgr'
	);
	
	const PIPING_RULES = '2>&1';
	
	/****** TESTING ******/
	//private const CAPISTRANO_CMD = 'echo "TEST"';
	//const CAPISTRANO_CMD = './publish-dummy.sh';
	/*********************/
	/***** PRODUCTION ****/
	const CAPISTRANO_CMD = 'cap';
	/*********************/
	
	const CAPISTRANO_CAPFILE = '../app/vendors/capistrano/capfiles/oregontrail.capfile.rb';
	const CAPISTRANO_VERBOSITY = 'vvv'; // -vvv = highest verbosity

	/**#@+
	 * Deployment shell command output and result
	 */
	
	private $cmd_output = '';
	private $cmd_rollback = '';
	private $deployment_dates = '';
	private $deployment_versions = '';
	private $cmd_status = 0;
	private $deployment_log = '';
	private $rollback_log = '';
	
	
	

	/**
	 * Constructor
	 *
	 * @param string $ot_host - Name of the Oregon Trail Host Installation currently being used
	 * @param string $application - Application/Site to deploy, must be in predefined set
	 * @param str-array $hosts - Optional set of hosts to run tasks against (as array)
	 * @param string $app_version - Application version or tag. This is used only to create version.txt file
	 * @param string $environment - Deployment environment - dev, qa, production
	 * @param string $dry_run - Indicates whether to execute capistrano shell script with dry-run argument
	 */
	public function __construct($ot_host, $application, $hosts, $app_version, $app_branch, $environment, $dry_run = false) {
		parent::__construct();
		
		// Validate parameters
		if (!$ot_host || !$application || !$environment) {
		
			$validate = false;
			
		} else {
		
			$validate = (in_array($application, self::$ALLOWED_SITES));
			$validate = (in_array($environment, self::$ALLOWED_ENVS));
		
		}

		// If no branch specified, use HEAD
		if (!$app_branch) {
			$app_branch = 'HEAD';
		}

		if ($validate !== true) {
			// TODO: Put some better form of exception throwing here
			debug("$application, $environment");
			exit('Invalid parameters passed to vendor-Capistrano. Could not init.');
			return false;
		}
		
		// Format $hosts array into semi-YAML data for ruby tasks
		// This turns the array in to the following format: "[host1,host2,host3]"
		// Which is YAML with spaces removed (for easier cmd line passing)
		if ($hosts && !empty($hosts)) {
			$host_list = '[';
			foreach ($hosts as $i => $host) {
				$host_list .= $host . ',';
			}
			$host_list = substr($host_list, 0, -1); // Chop off the last comma
			$host_list .= ']';
			$hosts = $host_list;
		}
		
		
		// Assign to class member varibles
		$this->ot_host     = $ot_host;
		$this->application = $application;
		$this->hosts       = $hosts;
		$this->app_version = $app_version;
		$this->app_branch  = $app_branch;
		$this->environment = $environment;
		$this->dry_run     = $dry_run;
	}
	
	/**
	 * Dependency Checking
	 *
	 * @param string $application Site to deploy, must be in predefined set
	 * @param string $environment Deployment environment - dev, qa, production
	 * @param string $dry_run Indicates whether to execute capistrano shell script with dry-run argument
	 */
	public function check_deps() {
	
		// 
		// Stuff to do here:
		// 
		// 
		// Deployment task exists for this site and env.
		// Check Apache version 
		// Check PHP version
		// Check MySQL version 5.1.37
		// Pear Mail Installed
		// Pear Memcached Installed
		// Check for tmp directory, if not present create it
		//
		//
		// Maintenance page task exists, and page exists
		// 
		// 
		// 
		// 
		// 
		// 
		// 
	
		/* Temporary */
		return true;
	}
	
	/**
	 * Run Environment setup on target servers.
	 * This basically creates various app directories and runs chown/chmod
	 */
	public function run_setup() {
		
		// Execute filesystem directory creation command
		// Returns true if exectued (even if the outcome failed)
 		$task = 'deploy:setup';
		
		$exec_result = $this->execute($task);

		$output = $this->cmd_output;
		$rollback = $this->cmd_rollback;

		// Populate log data with formatted command output
		$this->deployment_log .= $this->formatCommandOutput($output);
		$this->rollback_log .= $this->formatCommandOutput($rollback);

		return true;
	}	

	/**
	 * Clear remote cache on target servers.
	 * This is necessary for large changes in an app, or large version number changes
	 */
	public function clear_deploy_cache() {

		// Execute filesystem directory creation command
		// Returns true if exectued (even if the outcome failed)
 		$task = 'clear_remote_cache';

		$exec_result = $this->execute($task);

		$output = $this->cmd_output;
		$rollback = $this->cmd_rollback;

		// Populate log data with formatted command output
		$this->deployment_log .= $this->formatCommandOutput($output);
		$this->rollback_log .= $this->formatCommandOutput($rollback);

		return true;
	}

	/**
	 * Run Capistrano deployment processes via command shell, and capture result output
	 *
	 * @param string $application Site to deploy, must be in predefined set
	 * @param string $environment Deployment environment - dev, qa, production
	 * @param string $dry_run Indicates whether to execute capistrano shell script with dry-run argument
	 */
	public function run_deployment() {
		
		// Execute deployment command
		// Returns true if exectued (even if the outcome failed)
 		
		$task = "deploy:run_deployment";
		
		$exec_result = $this->execute($task);


		$output = $this->cmd_output;
		$rollback = $this->cmd_rollback;

		// Populate log data with formatted command output
		$this->deployment_log .= $this->formatCommandOutput($output);
		$this->rollback_log .= $this->formatCommandOutput($rollback);

		return true;
	}
	
	public function get_deploy_result() {
		return $this->cmd_status;
	}
	
	/**
	* Verify the date-timestamps of the current and next previous deployment.
	*
	* Returns whether a the set of last two deployment timestamps are in sync across all servers
	*
	* Fetches the name of the directoies containing the current and next previous deployment, and compares the sets.
	* This dir name is a datetime stamp.
	* This task is run ahead of approval of a requested "undo last deploy" operation.
	*
	* If the set of current and next previous timestamps differ between servers, an error is thrown to be handled in OregonTrail
	*
	*/
	public function verify_rollback_timestamps() {
		
		// Capistrano task
 		$task = 'verify_rollback_timestamps';
		
		$exec_result = $this->execute($task);

		$output = $this->cmd_output;
		
		$formatted_output = $this->formatCommandOutput($output);
		$this->deployment_log = $formatted_output; // Save to standard log
		
		$this->deployment_dates = $this->parse_rollback_timestamps($output, 'dates');
		$this->deployment_versions = $this->parse_rollback_timestamps($output, 'versions');
		
		// Returns true if success, false if failure
		return $this->parse_rollback_timestamps($output, 'status');
	}
	
	/**
	 * Returns the timestamp sets produced by verify_rollback_timestamps()
	 *
	 */
	public function get_rollback_timestamps() {
		return $this->deployment_dates;
	}
	
	/**
	 * Returns the version sets produced by verify_rollback_timestamps()
	 *
	 */
	public function get_rollback_versions() {
		return $this->deployment_versions;
	}
	
	/**
	* Conduct a manual rollback of the current deployment (for the specified App and specified servers)
	*
	* Returns the success/failure status of the undo operation
	*
	* This operation unlinks the current deployment directory, and links the "current" directory to 
	* the next previous deployment. This operation renames the rolledback deploy to "[dirname]-undep"
	*/
	public function undo_last_deployment() {
		// Capistrano task
 		$task = 'undo_last_deployment';
		
		$exec_result = $this->execute($task);
		$output = $this->cmd_output;
		
		$formatted_output = $this->formatCommandOutput($output);
		$this->deployment_log = $formatted_output; // Save to standard log
		
		// Return success/failure status
		if (preg_match('/\*\*\*ERROR|Failed:/i', $output)) {
			return false;	
		} else {
			return true;
		}
		
	}
	
	
	/**
	 * Enable display of a "maintenance page" while the site is down for maintenance
	 *
	 */
	public function enable_maintenance_page() {
	
	}
	
	/**
	 * Disable display of a "maintenance page" once maintenance is completed
	 *
	 */
	public function disable_maintenance_page() {
	
	}
	
	/**
	 * 
	 *
	 */
	public function revert_symlink($release) {
	
	}
	
	/**
	 * Interface to get formatted log data for capistrano and rollback logs
	 *
	 * @param string $log_type 'Deployment' or 'Rollback'
	 */
	public function get_formatted_log($log_type) {
		
		if (strtolower($log_type) == 'deployment') {
			return $this->deployment_log;
		} elseif (strtolower($log_type) == 'rollback') {
			return $this->rollback_log;
		} else {
			return false;
		}
		
	}
	
	public function test_function() {
		$result = $this->execute('test_function');
		
		$output = $this->cmd_output;
		
		// Populate log data with formatted command output
		$this->deployment_log .= $this->formatCommandOutput($output);
		
		return $result;
	}
	
	
	////// Private/Protected Functions //////
	
	
	/**
	 * Formats log data, to better display as HTML data in browser.
	 * Adds coloring markup, line breaks, and classes.
	 *
	 * @param string $data Raw text log data, which was read from shell output
	 * @return string Formatted HTML log data 
	 */
	private function format_log_data($data) {
	
	}
	
	/**
	* Format capistrano shell command output, and add highlighting css styles
	*/
	function formatCommandOutput($output) {
		// Add html coloring
		$patterns[] = '/\*\*\*\* Deployment Successful \*\*\*\*/';
		$patterns[] = '/\*\*\*\* Deployment Failed \*\*\*\*/';
		$patterns[] = '/\*\* transaction: commit/';
		$patterns[] = '/\*\*\* (.*) rolling back/';
		$patterns[] = '/(.*)exception while rolling back(.*)/';
		$patterns[] = '/\*\*\* \[RTW-CAPISTRANO-DEBUG\](.*)/';
		$patterns[] = '/\*\*\*\* DRY RUN ONLY \*\*\*\*/';
		$patterns[] = '/INFO:(.*)/i';
		$patterns[] = '/DEBUG:(.*)/i';
		$patterns[] = '/failed:(.*)/';
		$patterns[] = '/\*\* SUCCESS \*\*(.*)/';
		$patterns[] = '/\*\* FAILURE \*\*(.*)/';
		$patterns[] = '/ERROR:(.*)/i';
		$patterns[] = '/.*Permission denied(.*)/i';
		$patterns[] = '/.*fatal(.*)/i';
		$patterns[] = '/servers:(.*)/i';
		$patterns[] = '/(.*)SyntaxError(.*)/i';
		$patterns[] = '/(.*)syntax error(.*)/i';
		// Formatting improvements
		$patterns[] = '//';
		$patterns[] = '//';
		$patterns[] = '/\\\\\\\\\\\n/'; // Get rid of literal '\\\n' (not sure why 11 slashes are needed to nuke 3)
		$patterns[] = '/&&/';
		$patterns[] = "/     /";
		$patterns[] = '/\* executing "if \[/';
		$patterns[] = '/\* executing /i';
		$patterns[] = '/\*\* transaction:(.*)/i';
		$patterns[] = '/INFO:(.*)/i';
		$patterns[] = '/; then/';
		$patterns[] = '/; else/';
		//$patterns[] = '/\n/';
		$patterns[] = '/\t/';
		$patterns[] = '/  /';

		$replacements[] = '<span class="b green">**** Deployment Successful ****</span>';
		$replacements[] = '<span class="b red">**** Deployment Failed ****</span>';
		$replacements[] = '<span class="b green">** transaction: commit</span>';
		$replacements[] = '<span class="b red">*** \1 rolling back</span>';
		$replacements[] = '<span class="red">\1exception while rolling back\2</span>';
		$replacements[] = '<span class="b i yellow">*** [RTW-CAPISTRANO-DEBUG]\1</span>';
		$replacements[] = '<span class="b red">**** DRY RUN ONLY ****</span>';
		$replacements[] = '<span class="b green">INFO:\1</span>';
		$replacements[] = '<span class="b green">DEBUG:\1</span>';
		$replacements[] = '<span class="b red">Failed:\1</span>';
		$replacements[] = '<span class="b green">** SUCCESS **\1</span>';
		$replacements[] = '<span class="b red">** FAILURE **\1</span>';
		$replacements[] = '<span class="b red">ERROR:\1</span>';
		$replacements[] = '<span class="b red">Permission Denied\1</span>';
		$replacements[] = '<span class="b red">fatal\1</span>';
		$replacements[] = '<span class="b purple">Servers:\1</span>';
		$replacements[] = '<span class="b red">\1SyntaxError\2</span>';
		$replacements[] = '<span class="b red">\1syntax error\2</span>';
		$replacements[] = '';
		$replacements[] = '';
		$replacements[] = "";
		$replacements[] = "\n\t &&";
		$replacements[] = '';
		$replacements[] = "\n<span class=\"blue\">  * Executing: </span>\n     \"if [";
		$replacements[] = "\n<span class=\"blue\">  * Executing: </span>\n\t";
		$replacements[] = '** Transaction:\1';
		$replacements[] = '<span class=\"blue\">INFO:\1</span>';
		$replacements[] = ";\n      then\n\t";
		$replacements[] = ";\n      else\n\t";
		//$replacements[] = "<br />";
		$replacements[] = "&nbsp;&nbsp;&nbsp;&nbsp;";
		$replacements[] = "&nbsp;&nbsp;";
		$output = preg_replace($patterns, $replacements, $output);
		return $output;
	}

	/**
	* Parse the output of running the "get_previous_deploy_timestamp" task
	*/
	private function parse_rollback_timestamps($deptask_output, $action) {
		
		$success_pattern = '/\*\* SUCCESS \*\*.*/';
		$failure_pattern = '/\*\* FAILURE \*\*.*/';
		$dates_pattern = '/Current\/Restorable Dates\/Times:(.*$)\n\n/Umis';
		$versions_pattern = '/Current\/Restorable Versions:(.*$)\n\n/Umis';
		
		switch ($action) {
			case 'dates':
				$dates = '';
				$m = preg_match($dates_pattern, $deptask_output, $matches);
				if ($m) {
					$dates = $matches[1];
				}
				return $dates;
				break;
			case 'versions':
				$versions = '';
				$m = preg_match($versions_pattern, $deptask_output, $matches);
				if ($m) {
					$versions = $matches[1];
				}
				return $versions;
				break;
			case 'status':
				$status = preg_match($success_pattern, $deptask_output);
				return $status;
				break;
		}
	}
	
	/**
	 * Executes capistrano commands with set parameters
	 *
	 * @param string $parameters - Any of the valid capistrano command arguments (see case statement)
	 * 
	 */
	private function execute($task) {
	
		$deploy_task = ' ';
		switch (trim($task)) {
			case 'deploy:update': break; // Not-used
			case 'deploy:cleanup': break; // Not-used
			case 'deploy': break; // blank args - Not-used
			
			case 'deploy:setup':
			case 'deploy:run_deployment':
			case 'clear_remote_cache':
			case 'verify_rollback_timestamps':
			case 'undo_last_deployment':
			case 'test_function':
				$deploy_task = trim($task); break;
		}
		
		// FAIL if a valid case wasn't used
		if (!trim($deploy_task)) {
			$this->cmd_output = "ERROR: Capistrano->execute() given bad parameter";
			return false;
		}
		
		// Build shell command string
		$capistrano_cmd     = self::CAPISTRANO_CMD;
		$capistrano_capfile = ' -f ' . self::CAPISTRANO_CAPFILE;
		$piping_rules       = ' ' . self::PIPING_RULES;
		
		$verbosity_params = '-'.self::CAPISTRANO_VERBOSITY;
		
		$application = " -S application=\"{$this->application}\"";
		
		$environment = " -S environment=\"{$this->environment}\"";

		$app_branch = " -S app_branch=\"{$this->app_branch}\"";
		
		$current_ot_host = " -S current_ot_host=\"{$this->ot_host}\"";

		if ($this->hosts) {
			$hosts = " -S hosts=\"{$this->hosts}\"";
		} else {
			$hosts = '';
		}
		
		if ($this->app_version) {
			$app_version = " -S app_version=\"{$this->app_version}\"";
		} else {
			$app_version = '';
		}
		
		if ($this->dry_run) {
			$dryrun_params = '-n';
		} else {
			$dryrun_params = '';
		}
		
		$deploy_task = ' '.$deploy_task;
		
		$exec_params = ' '. $verbosity_params . ' '. $dryrun_params . ' ';
		
		$publish_command = $capistrano_cmd . $exec_params . $capistrano_capfile . $current_ot_host . $application . $environment . $hosts . $app_version . $app_branch . $deploy_task . $piping_rules;
		
		// Run command as user "stork". 
		// REQUIREMENT: Add to /etc/sudoers: "www-data ALL=(stork) NOPASSWD: /usr/bin/cap"
		// To allow PHP user to run /usr/bin/cap tasks as "stork" user
		$publish_command = "sudo -H -u stork ".$publish_command;
	
		exec($publish_command, $output, $status);
		//debug($publish_command);

		// Turn the line-by-line output array into a large string for parsing.
		$output_str = implode("\n", $output);

		$matches = array();
		$result = preg_match_all('/(?:(?:fatal|permission denied|rollback).*$)/smi', $output_str, $matches);

		if ($result && count($matches)) {
			$this->cmd_rollback = $matches[0][0];
		}

		$this->cmd_output = $output_str;
		$this->cmd_status = !$status; // Since 0 = success, 1 = fail in Unix Shell
				
		return true;
	}
	
	// Mutators/Accessors
	
	public function get_hosts() {
		return $this->hosts;
	}
	
}
