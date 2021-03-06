### begin - web of '<?php echo $domainname; ?>' - do not remove/modify this line


## MR - NOTE:
## add 'header("X-Hiawatha-Cache: 10");' to index.php

<?php

if (($webcache === 'none') || (!$webcache)) {
	$ports[] = '80';
	$ports[] = '443';
} else {
	$ports[] = '8080';
	$ports[] = '8443';
}

$portnames = array("nonssl", "ssl");

foreach ($certnamelist as $ip => $certname) {
	if (file_exists("/home/kloxo/client/{$user}/ssl/{$domainname}.key")) {
		$certnamelist[$ip] = "/home/kloxo/client/{$user}/ssl/{$domainname}";
	} else {
		$certnamelist[$ip] = "/home/kloxo/httpd/ssl/{$certname}";
	}
}

$statsapp = $stats['app'];
$statsprotect = ($stats['protect']) ? true : false;

$serveralias = "www.{$domainname}";

if ($wildcards) {
	$serveralias .= ", *.{$domainname}";
}

if ($serveraliases) {
	foreach ($serveraliases as &$sa) {
		$serveralias .= ", {$sa}";
	}
}

if ($parkdomains) {
	foreach ($parkdomains as $pk) {
		$pa = $pk['parkdomain'];
		$serveralias .= ", {$pa} www.{$pa}";
	}
}

if ($webmailapp) {
	if ($webmailapp === '--Disabled--') {
		$webmaildocroot = "/home/kloxo/httpd/disable";
	} else {
		$webmaildocroot = "/home/kloxo/httpd/webmail/{$webmailapp}";
	}
} else {
	$webmaildocroot = "/home/kloxo/httpd/webmail";
}

$webmailremote = str_replace("http://", "", $webmailremote);
$webmailremote = str_replace("https://", "", $webmailremote);

$cpdocroot = "/home/kloxo/httpd/cp";

if ($indexorder) {
	$indexorder = implode(', ', $indexorder);
}

if ($blockips) {
	$biptemp = array();
	foreach ($blockips as &$bip) {
		if (strpos($bip, ".*.*.*") !== false) {
			$bip = str_replace(".*.*.*", ".0.0/8", $bip);
		}
		if (strpos($bip, ".*.*") !== false) {
			$bip = str_replace(".*.*", ".0.0/16", $bip);
		}
		if (strpos($bip, ".*") !== false) {
			$bip = str_replace(".*", ".0/24", $bip);
		}
		$biptemp[] = 'deny ' . $bip;
	}
	$blockips = $biptemp;

	$blockips = implode(', ', $blockips);
}

$userinfo = posix_getpwnam($user);

if ($userinfo) {
	$fpmport = (50000 + $userinfo['uid']);
} else {
	return false;
}

// MR -- for future purpose, apache user have uid 50000
// $userinfoapache = posix_getpwnam('apache');
// $fpmportapache = (50000 + $userinfoapache['uid']);
$fpmportapache = 50000;

$disabledocroot = "/home/kloxo/httpd/disable";

$domcleaner = str_replace('-', '_', str_replace('.', '_', $domainname));

if (!$reverseproxy) {
	if ($statsapp === 'awstats') {
		if ($statsprotect) {
?>

Directory {
	Path = /home/kloxo/httpd/awstats/wwwroot/cgi-bin
	PasswordFile = basic:/home/httpd/<?php echo $domainname ?>/__dirprotect/__stats
}

<?php
		}
	} elseif ($statsapp === 'webalizer') {
		if ($statsprotect) {
?>

Directory {
	Path = /home/httpd/<?php echo $domainname; ?>/webstats
	PasswordFile = basic:/home/httpd/<?php echo $domainname ?>/__dirprotect/__stats
}

<?php
		}
	}

	if ($dirprotect) {
		foreach ($dirprotect as $k) {
			$protectpath = $k['path'];
			$protectauthname = $k['authname'];
			$protectfile = str_replace('/', '_', $protectpath) . '_';
?>

Directory {
	Path = /<?php echo $protectpath; ?>

	PasswordFile = basic:/home/httpd/<?php echo $domainname; ?>/__dirprotect/<?php echo $protectfile; ?>

}

<?php
		}
	}
}

if ($webmailremote) {
?>
UrlToolkit {
	ToolkitID = redirect_<?php echo str_replace('.', '_', $webmailremote); ?>

	#RequestURI exists Return
	Match ^/(.*) Redirect http://<?php echo $webmailremote; ?>/$1
}
<?php
}
?>

UrlToolkit {
	ToolkitID = redirect_<?php echo $domcleaner; ?>

	#RequestURI exists Return
<?php
if ($redirectionremote) {
	foreach ($redirectionremote as $rr) {
		if ($rr[2] === 'both') {
?>
	Match /^<?php echo $rr[0]; ?>/(.*) Redirect <?php echo $protocol; ?><?php echo $rr[1]; ?>/$1
<?php
		} else {
			$protocol2 = ($rr[2] === 'https') ? "https://" : "http://";
?>
	Match ^/<?php echo $rr[0]; ?>/(.*) Redirect <?php echo $protocol2; ?><?php echo $rr[1]; ?>/$1
<?php
		}
	}
}
?>
	Match ^/kloxo(/|$) Redirect https://<?php echo $domainname; ?>:<?php echo $kloxoportssl; ?>/$1
	Match ^/kloxononssl(/|$) Redirect http://<?php echo $domainname; ?>:<?php echo $kloxoportnonssl; ?>/$1
	Match ^/webmail(/|$) Redirect http://webmail.<?php echo $domainname; ?>/$1
	Match ^/cp(/|$) Redirect http://cp.<?php echo $domainname; ?>/$1
<?php
if ($enablestats) {
	if ($statsapp === 'awstats') {
?>
	Match ^/stats(/|$) Redirect http://<?php echo $domainname; ?>/awstats/awstats.pl
<?php
	}
}

if ($wwwredirect) {
?>

	Match ^/(.*) Redirect http://www.<?php echo $domainname; ?>/$1
<?php
}
?>
}

<?php
foreach ($certnamelist as $ip => $certname) {
	$count = 0;

	foreach ($ports as &$port) {

	//	if ($count !== 0) { continue; }

		$protocol = ($count === 0) ? "http://" : "https://";

		if ($disabled) {
?>

## cp for '<?php echo $domainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
			if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
				if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
				}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
			}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = cp.<?php echo $domainname; ?>


	WebsiteRoot = <?php echo $disabledocroot; ?>

	EnablePathInfo = yes
<?php
			if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
			} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
			}
?>

	#StartFile = index.php
}


## webmail for '<?php echo $domainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
			if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
				if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
				}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
			}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = webmail.<?php echo $domainname; ?>


	WebsiteRoot = <?php echo $disabledocroot; ?>


	EnablePathInfo = yes
<?php
			if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
			} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
			}
?>

	#StartFile = index.php
}

<?php
		} else {
?>

## cp for '<?php echo $domainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
			if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
				if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
				}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
			}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = cp.<?php echo $domainname; ?>


	WebsiteRoot = <?php echo $cpdocroot; ?>


	EnablePathInfo = yes

	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
			if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
			} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
			}
?>

	#StartFile = index.php
}

<?php
			if ($webmailremote) {
?>

## webmail for '<?php echo $domainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
				if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
					if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
					}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
				}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = webmail.<?php echo $domainname; ?>


	WebsiteRoot = <?php echo $webmaildocroot; ?>


	useToolkit = block_shellshock, redirect_<?php echo str_replace('.', '_', $webmailremote); ?>

				}

<?php
			} else {
?>

## webmail for '<?php echo $domainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
				if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
					if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
					}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
				}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = webmail.<?php echo $domainname; ?>


	WebsiteRoot = <?php echo $webmaildocroot; ?>


	EnablePathInfo = yes

	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
				if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
				} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
				}
?>

	#StartFile = index.php
}

<?php
			}
		}
?>

## web for '<?php echo $domainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
		if ($count !== 0) {
			if ($enablessl) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
				if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
				}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
			}
		}
?>

	set var_user = <?php echo $user; ?>


	UseGZfile = yes

	FollowSymlinks = no
<?php
		if ($ip !== '*') {
?>

	Hostname = <?php echo $domainname; ?>, <?php echo $serveralias; ?>, <?php echo $ip; ?>

<?php
		} else {
?>

	Hostname = <?php echo $domainname; ?>, <?php echo $serveralias; ?>

<?php
		}

		if ($disabled) {
			$rootpath = $disabledocroot;
		}
?>

	WebsiteRoot = <?php echo $rootpath; ?>


	EnablePathInfo = yes

	Alias = /__kloxo:/home/<?php echo $user; ?>/kloxoscript
<?php
		if ($enablecgi) {
?>

	WrapCGI = <?=$user;?>_wrapper

	## MR -- don't use ScriptAlias but Alias because ScriptAlias not the same as in Apache
	Alias = /cgi-bin:/home/<?php echo $user; ?>/<?php echo $domainname; ?>/cgi-bin
<?php
		}

		if ($redirectionlocal) {
			foreach ($redirectionlocal as $rl) {
?>

	Alias = <?php echo $rl[0]; ?>:<?php echo $rootpath; ?><?php echo $rl[1]; ?>

<?php
			}
		}

		if (!$reverseproxy) {
			if ($enablestats) {
?>

	AccessLogfile = /home/httpd/<?php echo $domainname ?>/stats/<?php echo $domainname ?>-custom_log
	ErrorLogfile = /home/httpd/<?php echo $domainname ?>/stats/<?php echo $domainname ?>-error_log
<?php
				if ($statsapp === 'awstats') {
?>

	Alias = /awstats:/home/kloxo/httpd/awstats/wwwroot/cgi-bin

	Alias = /awstatscss:/home/kloxo/httpd/awstats/wwwroot/css
	Alias = /awstatsicons:/home/kloxo/httpd/awstats/wwwroot/icon
<?php
				} elseif ($statsapp === 'webalizer') {
?>

	Alias = /stats:/home/httpd/<?php echo $domainname; ?>/webstats
<?php
				}
			}
		}

		if ($blockips) {
?>

	# BanlistMask = <?php echo $blockips; ?>

	AccessList = <?php echo $blockips; ?>

<?php
		}
?>

	UserWebsites = yes

	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
		if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
		} else {
			if ($enablephp) {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, redirect_<?php echo $domcleaner; ?>, findindexfile, permalink
<?php
			}
		}
?>

	#StartFile = index.php
<?php
		if ($dirindex) {
?>

	ShowIndex = yes
<?php
		} else {
?>

	ShowIndex = no
<?php

		}
?>
}

<?php
		if ($domainredirect) {
			foreach ($domainredirect as $domredir) {
				$redirdomainname = $domredir['redirdomain'];
				$redirpath = ($domredir['redirpath']) ? $domredir['redirpath'] : null;
				$webmailmap = ($domredir['mailflag'] === 'on') ? true : false;

				$randnum = rand(0, 32767);

				if ($redirpath) {
					if ($disabled) {
						$$redirfullpath = $disabledocroot;
					} else {
						$redirfullpath = str_replace('//', '/', $rootpath . '/' . $redirpath);
					}
?>

## web for redirect '<?php echo $redirdomainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
					if ($count !== 0) {
						if ($enablessl) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
							if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
							}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
						}
					}
?>

	set var_user = <?php echo $user; ?>


	UseGZfile = yes

	FollowSymlinks = no

	Hostname = <?php echo $domainname; ?>, <?php echo $serveralias; ?>


	WebsiteRoot = <?php echo $redirfullpath; ?>


	EnablePathInfo = yes

	UserWebsites = yes

	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
					if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
					} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
					}
?>

	#StartFile = index.php
}

<?php
				} else {
					if ($disabled) {
						$$redirfullpath = $disabledocroot;
					} else {
						$redirfullpath = $rootpath;
					}
?>

## web for redirect '<?php echo $redirdomainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
					if ($count !== 0) {
						if ($enablessl) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
							if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
							}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
						}
					}
?>

	set var_user = <?php echo $user; ?>


	UseGZfile = yes

	FollowSymlinks = no

	Hostname = <?php echo $redirdomainname; ?>, www.<?php echo $redirdomainname; ?>


	WebsiteRoot = <?php echo $redirfullpath; ?>


	EnablePathInfo = yes

	UserWebsites = yes

	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
					if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
					} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
					}
?>

	#StartFile = index.php
}

<?php
				}
			}
		}

		if ($parkdomains) {
			foreach ($parkdomains as $dompark) {
				$parkdomainname = $dompark['parkdomain'];
				$webmailmap = ($dompark['mailflag'] === 'on') ? true : false;

				if ($disabled) {
?>

## webmail for parked '<?php echo $parkdomainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
					if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
						if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
						}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
					}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = webmail.<?php echo $parkdomainname; ?>


	WebsiteRoot = <?php echo $disabledocroot; ?>


	EnablePathInfo = yes
<?php
					if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
					} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
					}
?>

	#StartFile = index.php
}

<?php
				} else {
					if ($webmailremote) {
?>

## webmail for parked '<?php echo $parkdomainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
						if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
							if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
							}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
						}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = webmail.<?php echo $parkdomainname; ?>


	WebsiteRoot = <?php echo $webmaildocroot; ?>


	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
						if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
						} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
						}
?>

	#StartFile = index.php
}

<?php
					} elseif ($webmailmap) {
?>

## webmail for parked '<?php echo $parkdomainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
						if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
							if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
							}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
						}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = webmail.<?php echo $parkdomainname; ?>


	WebsiteRoot = <?php echo $webmaildocroot; ?>


	EnablePathInfo = yes

	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
						if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
						} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
						}
?>

	#StartFile = index.php
}

<?php
					} else {
?>

## No mail map for parked '<?php echo $parkdomainname; ?>'

<?php
					}
				}
			}
		}

		if ($domainredirect) {
			foreach ($domainredirect as $domredir) {
				$redirdomainname = $domredir['redirdomain'];
				$webmailmap = ($domredir['mailflag'] === 'on') ? true : false;

				if ($disabled) {
?>

## webmail for redirect '<?php echo $redirdomainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
					if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
						if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
						}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
					}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = webmail.<?php echo $redirdomainname; ?>


	WebsiteRoot = <?php echo $disabledocroot; ?>


	EnablePathInfo = yes

	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
					if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
					} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile
<?php
					}
?>

	#StartFile = index.php
}

<?php
				} else {
					if ($webmailremote) {
?>

## webmail for redirect '<?php echo $redirdomainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
						if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
							if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
							}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
						}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = webmail.<?php echo $redirdomainname; ?>


	WebsiteRoot = <?php echo $webmaildocroot; ?>


	EnablePathInfo = yes

	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
						if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
						} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
						}
?>

	#StartFile = index.php
}

<?php
					} elseif ($webmailmap) {
?>

## webmail for redirect '<?php echo $redirdomainname; ?>'
VirtualHost {
	RequiredBinding = port_<?php echo $portnames[$count]; ?>

<?php
						if ($count !== 0) {
?>
	SSLcertFile = <?php echo $certname; ?>.pem
<?php
							if (file_exists("{$certname}.ca")) {
?>
	RequiredCA = <?php echo $certname; ?>.ca
<?php
							}
?>
	SecureURL = no
	#MinSSLversion = TLS1.1
<?php
						}
?>

	set var_user = apache

	UseGZfile = yes

	FollowSymlinks = no

	Hostname = webmail.<?php echo $redirdomainname; ?>


	WebsiteRoot = <?php echo $webmaildocroot; ?>


	EnablePathInfo = yes

	TimeForCGI = 3600

	Alias = /error:/home/kloxo/httpd/error
	ErrorHandler = 401:/error/401.html
	ErrorHandler = 403:/error/403.html
	ErrorHandler = 404:/error/404.html
	ErrorHandler = 501:/error/501.html
	ErrorHandler = 503:/error/503.html

	ExecuteCGI = yes
<?php
						if ($reverseproxy) {
?>

	IgnoreDotHiawatha = yes
	#ReverseProxy ^/.* http://127.0.0.1:30080/ 90 keep-alive
	ReverseProxy !\.(pl|cgi|py|rb|shmtl) http://127.0.0.1:30080/ 90 keep-alive
<?php
						} else {
?>

	UseFastCGI = php_for_var_user
	UseToolkit = block_shellshock, findindexfile, permalink
<?php
						}
?>

	#StartFile = index.php
}

<?php
					} else {
?>

## No mail map for redirect '<?php echo $redirdomainname; ?>'

<?php
					}
				}
			}
		}

		$count++;
	}
}
?>

### end - web of '<?php echo $domainname; ?>' - do not remove/modify this line
