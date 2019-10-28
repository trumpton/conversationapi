#
# Handler: simple-simon
#
#

package Handler;

# Necessary for Handler.pm standalone compilation
use File::Basename;
use Cwd qw(abs_path);
use lib dirname ( abs_path(__FILE__) ) . "/../.." ;

use Data::Dumper;
use Lib::Conversation;

my @PLACELIST = (
	"Vienna", "Brussels", "Ottawa", "Beijing", "Havana",
	"Copenhagen", "Cairo", "London", "Helsinki",
	"Paris", "Athens", "Budapest", 
	"Tehran", "Baghdad", "Rome", "Tokyo",
	"Nairobi", "Riga", "Beirut", "Tripoli",
	"Amsterdam", "Wellington", "Belfast",
	"Oslo", "Islamabad", "Lima", "Warsaw", "Lisbon", 
	"Bucharest", "Moscow", "Edinburgh", "Dakar", "Belgrade",
	"Freetown", "Bratislava",
	"Madrid", "Stockholm", "Damascus",
	"Cardiff" ) ;

##############################
#
#  Intent Processing / Dispatch
#

sub process {
	my ($conv ) = @_ ;
	
	## Check the API Access Key
	$conv->checkAccessKey("834df924-155d-4e71-8226-f43442746ec1") ;
	
	my $intent = $conv->intentName() ;
	if ( "$intent" eq "google-assistant-welcome" ) {
		intent_googleassistantwelcome($conv) ;
	} elsif ( "$intent" eq "lets-play") {
		intent_letsplay($conv) ;
	} elsif ( "$intent" eq "place-response4") {
		intent_placeresponse($conv) ;
	} elsif ( "$intent" eq "place-response8") {
		intent_placeresponse($conv) ;
	} elsif ( "$intent" eq "whats-my-score") {
		intent_whatsmyscore($conv) ;
	} elsif ( "$intent" eq "reset-score") {
		intent_resetscore($conv) ;
	} else {
		$conv->askSimple("Internal Error, unknown intent: $intent") ; 
	}
	return 1 ;
}


##############################
#
#  Google Assistant Welcome
#
sub intent_googleassistantwelcome {
	my ($conv) = @_ ;
}


##############################
#
#  Let's Play
#
sub intent_letsplay {
	
	my ($conv) = @_ ;
	
	my $params = $conv->getRequestContextParams("game") ;
	my $level = $params->{level} ;
	if ( $level ) {
		$conv->askSimple("You are already playing.  I'll have to press you for an answer.") ;
	} else {
		$conv->askSimple("OK, just do as I say") ;
		pose_question($conv) ;
	}
}


##############################
#
#  Fetch Score
#
sub intent_whatsmyscore {
	my ($conv) = @_ ;
	
	my $level = $conv->getRequestContextParams("game")->{level} ;
	
	if ($level) {
		$conv->askSimple("You are currently in a game, on level $level") ;
	} else {
		my $hilevel = int($conv->getUserStorage("hiscore")) ;
		if ( $hilevel ) {
			$conv->askSimple("Your highest level is $hilevel") ;
		} else {
			$conv->askSimple("You are not currently playing a game") ;
		}
	}
	$conv->askSimple("What Next?") ;
}

##############################
#
#  Reset Score
#
sub intent_resetscore {
	
	my ($conv) = @_ ;

	$conv->setUserStorage("hiscore", 0) ;
	$conv->askSimple("OK, you are back to square one") ;
}


##############################
#
#  Pose a Question
#
sub pose_question {

	my ($conv) = @_ ;

	my $params = $conv->getRequestContextParams("game") ;
	my $level = $params->{level} ;
	my $answers = [] ;
	my $numplaces = scalar(@PLACELIST) ;
	my $speechlist = "" ;
	my $textlist = "" ;

	if ( !$level ) { $level = 0 ; }
	else { $level = $level + 1 ; }

	my $size ;
	my $t ;
	if ($level<6) {
		$size = 4 ;
		$t = (4-$level) * 150 ;
	} else {
		$size = 8 ;
		$t = (12-$level) * 100 ;
	}
	if ($t<=0) { $t=1 ; }
	my $break = "<break time='" . $t . "ms' />" ;
	
	for (my $i=0; $i<$size; $i++) {
		my $x = int(rand() * ($numplaces-1)) ;
		push @answers, $x ;
		if ( $i == 0 ) {
			$speechlist = "<break time='500ms' />" . $PLACELIST[$x] ;
			$textlist = $PLACELIST[$x] ;
		} else {
			$speechlist = "$speechlist $break $PLACELIST[$x]" ;
			$textlist = "$textlist, $PLACELIST[$x]" ;
		}
	}

	$conv->askSimple( {
		"sequential" => "posequestion",
		"en" => [
			"<speak>Remember the following cities, and repeat: $speechlist</speak>",
			"<speak>Remember and say: $speechlist</speak>",
			"<speak>And now: $speechlist</speak>",
			"<speak>Say this: $speechlist</speak>",
			"<speak>Try this: $speechlist</speak>" ] }, {
		"en" => [
			"Remember the following cities, and repeat: $textlist",
			"Remeber and say: $textlist",
			"And now: $textlist",
			"Say this: $textlist",
			"Try this: $textlist" ] 
		} ) ;
		
	$conv->setResponseContext("game", 9999, { "level" => $level, "answers" => [@answers], "size" => $size } ) ;

}

##############################
#
#  Places Response
#

sub intent_placeresponse {
	my ($conv) = @_ ;
	
	my $params = $conv->getRequestContextParams("game") ;

	if ( ! $params->{level} ) {

		$conv->askSimple( {
			"en" => [
				"If you want to play, ask me to start a new game",
				"Just let me know if you want to play a new game",
				"You're not playing a game at the moment",
				"Just say, and we'll play" ] } ) ;

	} else {

		# Test the responses

		my $success=1 ;
		my $fail1 ;
		my $fail2 ;
		
		for ( my $i=0; $i<$params->{size}; $i++) {
			my $w = "w" . ($i+1) ;
			my $response = $conv->getParameter($w) ;
			my $index = $params->{answers}[$i] ;
			my $test = $PLACELIST[$index] ;
			if ($success && $test ne $response) { 
				$fail1 = $response ;
				$fail2 = $test ;
				$success=0 ; }
		}
	
		if ($success) {

			# my $bing = "<audio src=\"https://actions.google.com/sounds/v1/alarms/assorted_computer_sounds.ogg\" clipBegin=33500ms clipEnd=35000ms />" ;
			my $bing = "<audio src=\"https://actions.google.com/sounds/v1/cartoon/pop.ogg\" />" ;
			# my $bing = "<audio src=\"https://actions.google.com/sounds/v1/cartoon/pop.ogg\" />" ;
			
			$conv->askSimple( {
				"en" => [
					"<speak>$bing Well done.</speak>",
					"<speak>$bing Great.</speak>",
					"<speak>$bing That's right.</speak>",
					"<speak>$bing Nice.</speak>" ] }, {
				"en" => [
					"Well done!",
					"Great!",
					"That's right!",
					"Nice!" ]
				} ) ;
			pose_question($conv) ;

		} else {

			my $bong = "<audio src=\"https://actions.google.com/sounds/v1/impacts/crash.ogg\" />" ;
			# my $bong = "<audio src=\"https://actions.google.com/sounds/v1/impacts/glass_windows_crashing.ogg\" />" ;
			
			my $level = $params->{level} ;
			my $bestlevel = int($conv->getUserStorage("hiscore")) ;
			
			if ($conv->isUserVerified() && $level>$bestlevel) {

				$conv->askSimple( {
					"en" => [
						"<speak>$bong Hard luck!  You said $fail1, and I was expecting $fail2. You have reached level $level, and beaten your previous high score of level $bestlevel</speak>",
						"<speak>$bong Oops. You said $fail1, but I was expecting you to say $fail2. You have beaten your previous high score of level $bestlevel</speak>",
						"<speak>$bong Sorry, that's not right. I was expecting $fail2, but you said $fail1. This is, however, your best score and you have reached level $level</speak>" ] }, {
					"en" => [
						"Hard Luck, you said $fail1, and I was expecting $fail2.  You have reached level $level, and beaten your prevuous high score of level $bestlevel",
						"Ooops. You said $fail1, but I was expecting you to say $fail2.  You have beaten your previous high score of level $bestlevel",
						"Sorry, that's not right.  I was expecting $fail2, but you said $fail1.  This is, however, your best high score and you have reached level $level" ] 
					} ) ;
					
				$conv->setUserStorage("hiscore", $level) ;

			} else {
				$conv->askSimple( {
					"en" => [
						"<speak>$bong Hard luck!  You said $fail1, and I was expecting $fail2.</speak>",
						"<speak>$bong Oops. You said $fail1, but I was expecting you to say $fail2.</speak>",
						"<speak>$bong Sorry, that's not right. I was expecting $fail2, but you said $fail1.</speak>" ] }, {
					"en" => [
						"Hard luck! You said $fail1, and I was expecting $fail2",
						"Oops.  You said $fail1, but I was expecting you to say $fail2",
						"Sorry, that's not right. I was expecting $fail2, but you said $fail1" ]
					} ) ;
			}

			$conv->clearResponseContext("game") ;	
			$conv->askSimple("Just let me know if you want to play again?") ;

		}
	}
}

###############################
#
#  Goodbye Intent
#
sub intent_goodbye {
	my ($conv) = @_ ;
	
	$conv->askSimple( [ 
		"OK, call again soon!",
		"See you soon",
		"OK, until next time" ] ) ;

	$conv->close() ;
}

1;
