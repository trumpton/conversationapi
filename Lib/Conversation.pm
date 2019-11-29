#
# Google Actions Conversation Class
#

package Conversation;
use Scalar::Util qw(reftype);
use Data::Dumper ;
use JSON;

###############################
#
# Constructor
#
sub new {
	
	# Get Passed Parameters	
	my $this = shift;
	my $class = ref($this) || $this;
	my $jsonrequest = shift ;
	
	die "new(jsonrequest)" if !$jsonrequest ;
	
	# Decode JSON Request
	my $json ;
	eval {
		$json = JSON::decode_json($jsonrequest) ;
		1;
	} or do {
		die "There is a problem with the JSON request~#~$@" ;
	} ;
	
	## Setup class variables
	my $self = {
		accesskey => $ENV{"HTTP_ACCESSKEY"},
		request => $json,
		response => {
			'payload' => {
				'google' => {
					'expectUserResponse' => $JSON::true
				}
			}
		},
		userstorage => {},
		userstorageupdated => 0,
		clearuserstorage => 0
	} ;
	bless $self, $class;
	
	# Extract Variables from request
	my $storage=0 ;
	if ($self->{request}->{userStorage}) {
		$storage = $self->{request}->{userStorage} ;
	}
	if ($self->{request}->{originalDetectIntentRequest}->{payload}->{user}->{userStorage}) {
		$storage = $self->{request}->{originalDetectIntentRequest}->{payload}->{user}->{userStorage} ;
	}
	if ($storage) {
		eval {
			$self->{userstorage} = JSON::decode_json($storage) ;
			1;
		} or do {
			die $self->tr("Unrecognised information in userStorage") ;
		}
	}
		
	# Maintain Conversation ID
	if ($self->{request}->{conversation}->{conversationToken}) {
		$self->{response}->{conversationToken} = $self->{request}->{conversation}->{conversationToken} ;
	}

	# Return self
	return $self;
}

###############################
#
# Returns the Intent Name 
#
sub checkAccessKey {
	my ($self, $key) = @_ ;
	die "checkAccessKey(testkey)" if !$key ;
	die "NOKEY~#~" if ($key ne $self->{accesskey}) ;
}

###############################
#
# Returns the Intent Name 
#
sub intentName {
	my ($self) = @_ ;
	my $intent = "" ;
	my $request = $self->{request} ;
	
	if ($request->{queryResult}->{action}) {
		$intent = $request->{queryResult}->{action} ;
	} elsif ($request->{queryResult}->{intent}->{displayName}) {
		$intent = $request->{queryResult}->{intent}->{displayName} ;
	}

	if (!$intent) {
		die "Intent Not Found (queryResult/action or queryResult/intent/displayName missing from request JSON)" ;
	}
	
	return $intent ;
	
}

###############################
#
# Returns true if conversation is new
#
sub isConversationNew {
	my ($self) = @_ ;
	my $conv = $self->{request}->{originalDetectIntentRequest}->{payload}->{conversation} ;
	if ( $conv->{type} eq "NEW" ) {
		return 1 ;
	} else {
		return 0 ;
	}
}
 
 
###############################
#
# Returns true if user verified
#
sub isUserVerified {
	my ($self) = @_ ;
	my $stat = $self->{request}->{originalDetectIntentRequest}->{payload}->{user}->{userVerificationStatus} ;
	if ( $stat eq "VERIFIED" ) {
		return 1 ;
	} else {
		return 0 ;
	}
}

###############################
#
# Translate
#
# The translate function works three different ways.  The first two methods are used
# if only one language is provided.
#
# 1. if a single string is provided,
# 2. if an array of strings is provided, one string is randomly returned.
# 3. if a hash of languages is provided, the current language is chosed
#		The hash can contain a single string,
#		Or an array of strings - if the latter, one is randomly returned.
#
# Examples:
#
#	translate("Only one string supplied") ;
#	translate("Two strings in one language", "randomly selected") ;
#	translate( {
#		"sequence" => "sequence_context",
#		"en" => "Only one string supplied",
#		"fr" => [ "Two strings in one language", "randomly selected" ] } ) ;
#

sub _translate {
	my ($self, $arg) = @_ ;	
	my ($response, $index) = $self->_getTranslateString($arg, -1) ;
	return $response ;
}

#
# TranslatePairs
# This works the same way as the Translate function above, except that
# two sets of inputs are provided, and two sets of responses are output
#
sub _translatePairs {
	my ($self, $arg1, $arg2) = @_ ;
	my ($response1, $lang1, $len1, $index1) = $self->_getTranslateString($arg1, -1) ;
	my ($response2, $lang2, $len2, $index2) = $self->_getTranslateString($arg2, $index1) ;
	die "translatePairs - two inputs have different lengths ($lang1)" if $len1 != $len2 ;
	return ($response1, $response2) ;
}

sub _getTranslateString {
	
	my ($self, $arg, $fixedindex) = @_ ;	
	my @strings = [] ;
	my $type = reftype($arg) ;
	my $sequential=0 ;
	my $sequence=0 ;
	my $size=0 ;
	
	if ( $type eq "ARRAY" ) { 
		
		@strings = @{$arg} ; 
		$size = scalar(@strings) ;
		
	} elsif ($type eq "HASH" ) { 

		# Get Language
		my $lang = $self->lang() ;
		my $entry = $arg->{$lang} ;

		my $entrytype = reftype($entry) ;

		# Populate @strings
		if ( $entrytype eq "ARRAY" ) {
			
			@strings = @{$entry} ;
			$size = scalar(@strings) ;
			
		} else {
			
			@strings[0] = $entry ; 
			$size=1 ;
		}
		
		# Use Contexts to process sequential results
		
		if ( $arg->{sequence} ) {	

			$sequential = 1 ;

			$sequence = $self->getRequestContextCount($arg->{sequence}) ;
			
			if ( $sequence < 0 ) {
				$sequence=$size-1 ;
				$self->setResponseContext($arg->{sequence}, $sequence) ;
			}
		}
	
		
	} else {
		
		@strings = ( $arg ) ;
		
	}

	my $index ;
	
	if ($fixedindex >= 0 ) {
		$index = $fixedindex ;
	} elsif ($sequential) {
		$index = $size-$sequence-1 ;
	} else {
		$index=int(rand()*$size) ;
	}
	
	if ($index>=$size) {
		# Shouldn't happen unless script changed part way through a conversation
 		$index=0 ;
	}
	
	return ($strings[$index], $lang, $size, $index) ;
}

###############################
#
# Return JSON response
#
sub response()
{
	my ($self) = @_ ;
	my $json ;
	
	eval {
		if ( $self->{clearuserstorage} ) {
			$self->{response}->{payload}->{google}->{resetUserStorage} = $JSON::true ;
			$self->{response}->{payload}->{google}->{userStorage} = "{}" ;
		} elsif ( $self->{userstorageupdated} ) {
			$userstorage = JSON::encode_json($self->{userstorage}) ;
			$self->{response}->{payload}->{google}->{userStorage} = $userstorage ;
		}
		$json = JSON::encode_json($self->{response}) ;
		1;
	} or do {
		die "There is a problem building the JSON response~#~$@" ;
	} ;
	return $json ;
}


###############################
# Ask Simple Message
#
# askSimple(speech [,text ] )
#
# speech = "Message to Speak"
# text = "Message to Display"
#
sub askSimple {
	my ($self, $speechlst, $textlst) = @_ ;
	die "class->askSimple(speech [,text] )" if !$speechlst ;

	my $google = $self->{response}->{payload}->{google} ;
	my $responsecount = scalar(@{$google->{richResponse}->{items}}) ;
	
	my $speech ;
	my $text ;
	
	if ( $textlst ) {
		($speech, $text)=$self->_translatePairs($speechlst, $textlst) ;
	} else {
		$speech = $self->_translate($speechlst) ;
	}

	if ( $responsecount >= 2 ) {
		
		my $r = "" ;
		for ( my $i=0; $i<$responsecount; $i++) {
			my $rec = $google->{richResponse}->{items}[$i]->{simpleResponse} ;
			if ( $rec->{ssml} ) { $r = $r . $rec->{ssml} . " ~ " ; }
			else { $r = $r . $rec->{textToSpeech} . " ~ " ; }
		}
		die "askSimple - too many simpleResponses: $r$speech" ;
	}

	
	my $record = {
		"simpleResponse" => {
		}
	} ;

	if ( $speech =~ /^<speak>/ ) {
		$record->{simpleResponse}->{ssml} = $speech ;
	} else {
		$record->{simpleResponse}->{textToSpeech} = $speech ;
	}
	
	if ( $textlst ) {
		$record->{simpleResponse}->{displayText} = $text ;
	}
	
	push @{$google->{richResponse}->{items}}, $record ;

	return 1 ;
}

###############################
# Get the Request Language
#
# lang()
#
sub lang {
	my ($self) = @_ ;
	my $languageCode = "??" ;
	if ( $self->{request}->{queryResult}{languageCode} ) {
		$languageCode = $self->{request}->{queryResult}->{languageCode} ;
	}
	# Remove the locale
	($languageCode) = split( /-/, $languageCode) ;
	return $languageCode ;	
}

###############################
# Close Conversation
#
# close()
#
sub close {
	my ($self) = @_ ;
	my $google = $self->{response}->{payload}->{google} ;
	$google->{expectUserResponse} = $JSON::false ;
	return 1 ;
}

###############################
# Ask Permission
#
# askPermission(permissions, message)
#
# permissions = "NAME DEVICE_PRECISE_LOCATION DEVICE_COARSE_LOCATION UPDATE"
# message = "permission prompt"
#
sub askPermission {
	my ($self, $permissions, $messagesrc) = @_ ;
	die "class->askPermission(message, permissions...)" if !$messagesrc ;
	my $google = $self->{response}->{payload}->{google} ;
	my $message = $self->_translate($messagesrc) ;
	$google->{systemIntent} = {
		"intent" => "actions.intent.PERMISSION",
		"data" => {
			"\@type" => "type.googleapis.com/google.actions.v2.PermissionValueSpec",
			"optContext" => $message,
			"permissions" => [ $permissions ]
		}
	} ;
	return 1 ;
}


###############################
# Store Permissions in User Storage
sub storePermissionsInUserStorage {
	my ($self) = @_ ;

	my $payload = $self->{request}->{originalDetectIntentRequest}->{payload} ;
	if ( $payload ) {
		if ( $payload->{user}->{profile}->{displayName} ) {
			$self->setUserStorage("displayName", $payload->{user}->{profile}->{displayName}) ;
		}
		if ( $payload->{user}->{profile}->{givenName} ) {
			$self->setUserStorage("givenName", $payload->{user}->{profile}->{givenName}) ;
		}
		if ( $payload->{user}->{profile}->{familyName} ) {
			$self->setUserStorage("familyName", $payload->{user}->{profile}->{familyName}) ;
		}
		if ( $payload->{device}->{location}->{coordinates}->{longitude} ) {
			$self->setUserStorage("longitude", $payload->{device}->{location}->{coordinates}->{longitude}) ;
		}
		if ( $payload->{device}->{location}->{coordinates}->{latitude} ) {
			$self->setUserStorage("latitude", $payload->{device}->{location}->{coordinates}->{latitude}) ;
		}
		if ( $payload->{device}->{location}->{formattedAdress} ) {
			$self->setUserStorage("formattedAddress", $payload->{device}->{location}->{formattedAddress}) ;
		}
		if ( $payload->{device}->{location}->{city} ) {
			$self->setUserStorage("city", $payload->{device}->{location}->{city}) ;
		}
		if ( $payload->{device}->{location}->{zipCode} ) {
			$self->setUserStorage("zipCode", $payload->{device}->{location}->{zipCode}) ;
		}
	}

	return 1 ;
}

###############################
# Set/Get User Storage
#
sub setUserStorage {
	my ($self, $what, $value) = @_ ;
	$self->{userstorage}->{$what} = $value ;
	$self->{userstorageupdated} = $JSON::true ;
	$self->{clearuserstorage} = $JSON::false ;
	return 1 ;
}

sub getUserStorage {
	my ($self, $what) = @_ ;
	if ($self->{userstorage}->{$what}) {
		return $self->{userstorage}->{$what} ;
	} else {
		return "" ;
	}
}

sub clearUserStorage {
	my ($self) = @_ ;
	$self->{clearuserstorage} = $JSON::true ;
	$self->{userstorage} = {} ;
}

###############################
#
# Contexts:
#
# Contexts have a name and a lifespan
# They can also take an optional hash of { "param" => "value", ... }
#
# setResponseContext(context, lifespan [, paramshash ])
# isRequestContext(context) - returns true if context present
# getRequestContextParams(context) - returns the parameters hash
# getRequestContextCount(context) - returns the remaining lifespan
#

sub isRequestContext {
	my ($self, $context) = @_ ;
	die "isRequestContext(context)" if !$context ;
	
	my $session = $self->{request}->{session} ;
	my $sessioncontext = "$session/contexts/$context" ;
	
	foreach ( @{$self->{request}->{queryResult}->{outputContexts}} ) {
		if ( $_->{name} eq $sessioncontext ) { print "OK\n" ; return 1 ; }
	}
	return 0 ;
}

sub getRequestContextParams {
	my ($self, $context) = @_ ;
	die "getRequestContextValue(context)" if !$context ;

	my $session = $self->{request}->{session} ;
	my $sessioncontext = "$session/contexts/$context" ;

	foreach ( @{$self->{request}->{queryResult}->{outputContexts}} ) {
		if ( $_->{name} eq $sessioncontext ) { 
			return $_->{parameters} ;
		}
	}
	
	return {} ;
}

sub getRequestContextCount {
	my ($self, $context) = @_ ;
	die "getRequestContextCount(context)" if !$context ;
	my $session = $self->{request}->{session} ;
	my $sessioncontext = "$session/contexts/$context" ;
	foreach ( @{$self->{request}->{queryResult}->{outputContexts}} ) {
		if ( $_->{name} eq $sessioncontext ) { 
			my $count = int($_->{lifespanCount}) ;
			return $count ;
		}
	}
	
	return int(-1) ;
}
	
sub setResponseContext {
	
	my ($self, $context, $duration, $parameters) = @_ ;
	
	die "setResponseContext(context, duration [, { 'param' => 'value' ... } ])" if !$duration ;
	die "setResponseContext - parameter list not a hash" if $parameters && reftype($parameters) ne "HASH" ;

	if ( $duration<0 ) { $duration=0 ; }
	my $session = $self->{request}->{session} ;
	my $sessioncontext = "$session/contexts/$context" ;

	my $record = { "name" => "$sessioncontext", "lifespanCount" => int($duration) } ;
	if ($parameters) { $record->{parameters} = $parameters ; }

	# Search and replace if context already defined
	foreach ( @{$self->{response}->{outputContexts}} ) {
		if ( $_->{name} eq $sessioncontext ) {
			$_ = $record ;
			return  ;
		}
	}

	# Otherwise, append context to list
	push @{$self->{response}->{outputContexts}}, $record ;
	
}

sub clearResponseContext {
	my ($self, $context) = @_ ;
	$self->setResponseContext($context, -1) ;
}

sub getContextParameter {
	my ($self, $context, $parameter) = @_ ;
	my $params = getRequestContextParams($self, $context) ;
	return $params->{$parameter} ;
}

###############################
# Get Parameter
#
sub getParameter {
	my ($self, $parameter) = @_ ;
	return $self->{request}->{queryResult}->{parameters}->{$parameter} ;
}


###############################
# Get if Permission is granted
#
sub permissionGranted {
	my ($self) = @_ ;

	my $inputs = $self->{request}->{originalDetectIntentRequest}->{payload}->{inputs} ;
	my $input = $self->_findArrayEntry("intent", "actions.intent.PERMISSION", $inputs) ;
	my $argument = $self->_findArrayEntry("name", "PERMISSION", $input->{arguments}) ;
	my $permission = $argument->{boolValue} ;

	if ( $permission == $JSON::true) {
		return 1 ;
	} else {
		return 0 ;
	}
}

###############################
#
# Find Array Entry that has a 
# matching key=>value pair
#
sub _findArrayEntry {
	my ($self, $key, $value, $ref) = @_ ;	
	foreach ( @{$ref} ) {
		if ( $_->{$key} eq $value ) {
			return $_ ;
		}
	}
	return {} ;
}

###############################
#
# Debug Get Response Data
#
sub selfAsText {
	my ($self, $what) = @_ ;
	die "class->selfAsText('self' | 'request' | 'response')" if !$what ;
    $Data::Dumper::Indent = 1;	    # mild pretty print
	my $txt ;
	if ("$what" eq "self") { 
		print "WHAT=$what\n" ;
		$txt = Dumper($self) ; 
		$txt =~ s/\$VAR1 =/'self' =>/g ;
	} else {
		$txt = Dumper($self->{$what}) ; 
		$txt =~ s/\$VAR1 =/'$what' =>/g ;
	}
	return $txt . "\n" ;
}


# End
1;
