use v6.d;

use ML::FindTextualAnswer::LLM::TextualAnswer;

unit module ML::FindTextualAnswer;


#===========================================================
#| Finding substrings that appear to be answers of questions.
our proto find-textual-answer($text, |) is export {*}

multi sub find-textual-answer($text, $question, UInt $n = 1, *%args) {
    return find-textual-answer($text, [$question,], $n, |%args);
}

multi sub find-textual-answer($text,
                              @questions,
                              UInt $n = 1,
                              :$finder is copy = Whatever,
                              *%args
                              ) {

    # Is method given
    if $finder.isa(Whatever) { $finder = 'llm'; }
    die "The value of \$method is expected to be 'llm' or Whatever."
    unless $finder ~~ Str && $finder ∈ <llm> || $finder ~~ Callable;

    # Delegate
    my $res = do given $finder {

        when $_.Str eq 'llm' && $n == 1 {
            ML::FindTextualAnswer::LLM::TextualAnswer::Fetch($text, @questions, |%args);
        }

        when $_.Str eq 'llm' && $n > 1 {
            my $s = @questions.elems == 1 ?? '' !! 's';
            my $request = "{ @questions.elems == 1 ?? 'give' !! 'list' } the top $n answers for each of the question$s:";

            my %args2 = %args.grep({ $_.key ∉ <prelude request> });

            ML::FindTextualAnswer::LLM::TextualAnswer::Fetch($text,
                                                             @questions,
                                                             :$request,
                                                             |%args2);
        }

        default {
            note "Unknown finder specifiction.";
        }
    }

    # Result
    return $res;
}


#===========================================================
#| Finding substrings that appear to be answers of questions using a LLM.
our proto llm-textual-answer(|) is export {*}

multi sub llm-textual-answer(**@args, *%args) {
    ML::FindTextualAnswer::LLM::TextualAnswer::Fetch(|@args, |%args);
}


#===========================================================
#| Classifies given text into given given labels using a LLM
our proto llm-classify(Str $text, @classLabels, *%args) is export {*}

multi sub llm-classify(Str $text,
                       @classLabels is copy,
                       *%args) {

    # Make string
    @classLabels = @classLabels>>.Str;

    # Is method given
    my $method = do if %args<method>:exists {
        %args<method>
    } else {
        'llm'
    }

    # Single question
    my $question = @classLabels.pairs.map({ "{$_.key + 1}) {$_.value}" }).join("\n");

    # Process LLM arguments
    my %llmArgs = %args , {llm => 'palm', request => 'which of these workflows characterizes it', strip-with => 'NONE'};
    %llmArgs = %llmArgs.grep({ $_.key ∉ <p pairs>});

    # Delegate
    my $res = do given $method {
        when $_ ∈ <llm chatgpt openai palm large-language-model large-language-models> {
            find-textual-answer($text, $question, :!pairs, |%llmArgs);
        }
        default {
            die "The method $method is not implemented.";
        }
    }

    if %args<echo> // False {
        note "LLM result : $res";
    }

    # Process result
    my $resLbl = do given $res {
        when $_ ~~ / ^ (\d+) / {
            my $index = $0.Str.Int;

            if %args<echo> // False {
                note "Index : $index";
            }

            if 1 ≤ $index ≤ @classLabels.elems {
                @classLabels[$index-1]
            } else {
                note "Cannot deterimine the class label.";
                $0.Str
            }
        }

        default {
            my @clRes = @classLabels.grep(-> $lbl { $_.contains($lbl) });
            if @clRes {
                @clRes
            } else {
                note "Cannot deterimine the class label.";
                $_
            }
        }
    }

    return $resLbl;
}

