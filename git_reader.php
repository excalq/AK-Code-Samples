<?php
// 2010 - Arthur Ketcham
// 
// CakePHP vendor script to allow application to read commit and tag data from git repositories
// as well as retrieve build manifest data from tagged releases.

class GitReader extends Object
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
	const TAGS_NOT_FOUND      = 4;
	const GIT_ERROR           = 6;
	const REMOTE_ACCESS_ERROR = 7;
	const REMOTE_COMMAND_INVALID = 8;
	const REMOTE_OUTPUT_ERROR = 9;

	private $application = '';
	private $head = array();
	private $branches = array();
	private $tags = array();
	private $git_origin_repositories = '';
	private $origin_host = '';
	private $origin_user = '';
	private $origin_path = '';

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

	function __construct($application = null) {

		if (!$application) {
			return true;
		}
		
		// Default server set to Capistrano at RTW Boulder
		$this->git_origin_repositories = 'stork@capistrano:/mnt/gitrepo/_origin';
		
		return $this->set_application($application);

	}
	
	// Pass data needed to do remote git operations
	function set_get_repository($host, $repo_path, $user) {
		
		if (!$host || ! $repo_path || !$user) {
			return false;
		}
		
		$this->origin_host = $host;
		$this->origin_user = $user;
		$this->origin_path = $repo_path;
		$this->git_origin_repositories = "{$user}@{$host}:{$repo_path}";
	}
	
	function set_application($application) {
		
		if (!in_array($application, self::$ALLOWED_SITES)) {
			return false;
		} else {
			$this->application = $application;
		}
	}

	// Look up all branches, tags, and heads in the origin repository
	function lookup_git_branches() {

		$command = "git ls-remote {$this->git_origin_repositories}/{$this->application}";
		
		debug($command);

		$git_output = $this->get_exec($command);

		if (!empty($git_output['output'])) {
			$subject = implode("\n", $git_output['output']);

			$patterns['head']     = '/([a-z0-9]*).*(HEAD)/m';
			$patterns['branches'] = '/([a-z0-9]*).*refs\/heads\/([a-zA-Z0-9_\.\-\+\(\)^master]*)/m'; // Branch regex any head except master
			$patterns['tags']     = '/([a-z0-9]*).*refs\/tags\/([a-zA-Z0-9_\.\-\+\(\)]*)/m'; // Tag regex Alphanumeric + some symbols

			foreach ($patterns as $key => $pattern) {
				$result[$key]     = preg_match_all($pattern, $subject, $matches[$key]);

				$match = $matches[$key];

				//debug($match);

				// Set $this->head, $this->branches, $this->tags
				if (is_array($match) && count($match) == 3) {
					$this->$key = array('branch' => $match[2], 'hash' => $match[1]); // NOTE: $this->{$variable}
				}

			}

			// If no results were found, fail
			if (empty($matches) || (empty($this->head) && empty($this->branches) && empty($this->tags))) {
				return false;

			} elseif (!(empty($this->head) && empty($this->branches) && empty($this->tags))) {
				return true;
			}

		}

		// Command did not execute properly
		return false;
	}
	
	// Verifies that a tag matches a specific commit hash
	// This prevents changes from being sneakily placed into
	// the repository and retagged before a deployment happens.
	function verify_tag_hash($tag, $hash) {
		
		// This is done using the git ls-remote command. It is git specific.
		// This command searches for a name of a tag (or HEAD, or branch), and returns all matching
		// commit hashses their refspecs (tag names)
		
		if (!$this->application) {
			
			debug("Error: verify_tag_hash() must have application set.");
			
			return false;
		}
		
		$refspec = $tag;
		
		$command = "git ls-remote {$this->git_origin_repositories}/{$this->application} {$refspec}";
		
		$git_output = $this->get_exec($command);
		$found_hash = false;
		
		if ($git_output['status'] === 0 && !empty($git_output['output'])) {
			
			// It is possible that branches and tags have the same name [in git]. In this case, pass the test
			// if any result matches the requested tag/branch name and the hash. (Search both branches and tags)
			foreach ($git_output['output'] as $outputline) {
				preg_match("/\S+/", $outputline, $matches);
				
				if (!empty($matches[0]) && ($matches[0] === $hash)) {
					return true;
				}
			}
		}
		
		// No match found
		return false;
		
	}
	
	// Get manifest data from app's docs/release.nfo file
	// Returns file as a large string with unix line endings
	// TODO - When finished, use this to replace publications->ajax_fetch_manifest_data()
	function fetch_build_manifest($branchtag = null) {
		
		$app = $this->application;
		$full_ref = $this->get_full_ref($branchtag);
		
		$remote_cmd = "git --git-dir=/mnt/gitrepo/_origin/{$app} show {$full_ref}:docs/release.nfo";
		
		$output = $this->get_exec_remote($remote_cmd);
		
		//debug($output);
		
		if (isset($output['status']) && $output['status'] === 0) {
			
			$manifest_data = $output['output'];
			
			if (is_array($manifest_data)) {
				$manifest_data = implode("\n", $manifest_data);
			}
			
			return $manifest_data;
		} else {
			// The request did not execute successfully
			return false;
		}
	}
	
	// Get list of files in a remote git repository
	function fetch_git_filelist($branchtag = null) {
		
		$app = $this->application;
		$full_ref = $this->get_full_ref($branchtag);
		
		$remote_cmd = "git --git-dir=/mnt/gitrepo/_origin/{$app} ls-tree -r {$full_ref} | awk '{ print \\$4 }'";
		
		$output = $this->get_exec_remote($remote_cmd);
		
		//debug($output);
		
		if (isset($output['status']) && $output['status'] === 0) {
			return $output['output'];
		} else {
			// The request did not execute successfully
			return false;
		}
	}

	function fetch_git_head() {
		return $this->head;
	}

	function fetch_git_branches() {
		return $this->branches;
	}

	function fetch_git_tags() {
		return $this->tags;
	}
	
	// Translate tag "0.6.5-rc1" into "refs/tags/0.6.5-rc1".
	// This does this by looking up the remote ref, giving precendence to tags, then branches in cases of ambiguity
	private function get_full_ref($branchtag) {
		
		$command = "git ls-remote {$this->git_origin_repositories}/{$this->application} {$branchtag} | awk {'print $2'}";
		$git_output = $this->get_exec($command);
		
		// No results found
		if (empty($git_output['output'])) {
			return false;
		}
		
		// Examine output for 'HEAD' - indicating that this matched the head, this also happens in the case of a blank $branchtag
		if (in_array('HEAD', $git_output['output'])) {
			return 'HEAD';
		
		} else if (in_array("refs/tags/$branchtag", $git_output['output'])) {
			// Find matching tag names
			$array_key = array_search("refs/tags/$branchtag", $git_output['output']); // Returns "refs/tags/FOO"
			return $git_output['output'][$array_key];
			
		} else if (in_array("refs/heads/$branchtag", $git_output)) {
			// Find matching branch name
			$array_key = array_search("refs/heads/$branchtag", $git_output['output']); // Returns "refs/heads/FOO"
			return $git_output['output'][$array_key];
		}
		
		// No refspec was found, return false
		return false;	
	}
	
	// Run git commands, as the user with ssh-key git access
	private function get_exec($command) {
		
		// Run command as user "stork".
		// REQUIREMENT: Add to /etc/sudoers: "www-data ALL=(stork) NOPASSWD: /usr/bin/git"
		// To allow PHP user to run /usr/bin/cap tasks as "stork" user
		$command = "sudo -H -u stork ".$command;
		
		exec($command, $output, $status);
		
		//debug($command);
		
		return array('status' => $status, 'output' => $output);
	}
	
	// This executes git commands locally on the git-repository via SSH, since some git operations cannot be done
	// with local access to the repository. This enables commands like "git ls-tree" to be run against the origin repos.
	// This avoids time and bandwith expensive cloning from being necessary. However, this should be used with caution.
	//
	// NOTE: This requires specific regex entries present in /etc/sudoers of this web server. See Oregon Trail docs.
	//
	private function get_exec_remote($command) {
		
		// Examples of valid commands:
		//
		// git --git-dir=/mnt/gitrepo/_origin/apb_www ls-tree -r HEAD                                     // Get list of all files and thier metadata
		// git --git-dir=/mnt/gitrepo/_origin/apb_www ls-tree -r refs/tags/0.6.5-rc1 | awk '{ print $4 }' // Get list of only filenames for this app
		// git --git-dir=/mnt/gitrepo/_origin/apb_www show refs/tags/0.6.5-rc1:docs/release.nfo           // Print release.nfo
		//
		
		// Only allow specific white-listed commands to be run on repo server. This prevents malicious code from being run.
		// Also, it makes sure no pipes, backgrounding, and multiple commands are being run. (but "| awk" is allowed)
		$allowed_commands = array();
		$allowed_commands[] = '/^git [\sa-zA-Z0-9\-\._\=\/\$\'\"]* ls-tree [\sa-zA-Z0-9\-\._\:\=\/\(\)\$\'\"]*(?:\|\s?awk[a-zA-Z0-9\s\\\$\{\}\'\"]*)?$/'; // Allow "git [..] ls-tree [..]}| awk [..]"
		$allowed_commands[] = '/^git [\sa-zA-Z0-9\-\._\=\/\$\'\"]* show [\sa-zA-Z0-9\-\._\=\:\/\(\)\$\'\"]*$/'; // Allow "git show refs/tags/0.6.5-rc1:docs/release.nfo"
		
		// Check command against list of allowed commands
		foreach ($allowed_commands as $pattern) {
			$match = preg_match($pattern, $command);
			if ($match) {
				// match found - break
				break;
			}
		}
		
		if ($match) {
			
			$this->origin_host;
			
			$ssh_cmd = "ssh {$this->origin_user}@{$this->origin_host} \"{$command}\"";
			
			$output = $this->get_exec($ssh_cmd);
			
			return $output;
			
		} else {
			// Command was not valid
			return REMOTE_COMMAND_INVALID;
		}
		
		
		
	}
	
	

}

?>
