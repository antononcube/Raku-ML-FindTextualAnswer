use v6.d;

use LLM::Functions;
use ML::FindTextualAnswer::LLM::TextualAnswer;

unit module ML::FindTextualAnswer;


#===========================================================
#| Finding substrings that appear to be answers of questions.
our proto find-textual-answer($text, |) is export {*}

multi sub find-textual-answer($text, $question, UInt $n = 1, *%args) {
    my $res = find-textual-answer($text, [$question,], $n, |%args);
    if $res ~~ Positional && $res.elems == 1 {
        return $res.head;
    }
    return $res;
}

multi sub find-textual-answer($text,
                              @questions,
                              UInt $n = 1,
                              :$finder is copy = Whatever,
                              *%args
                              ) {

    #------------------------------------------------------
    # Process finder
    #------------------------------------------------------
    $finder = do given $finder {
        when $finder ~~ Str:D && $finder.lc eq <llm large-language-model largelanguagemodel> {
            llm-evaluator(Whatever)
        }
        when Whatever { llm-evaluator(Whatever) }
        default { $finder }
    }

    die "The value of \$finder is expected to be 'LLM', an LLM::Functions::Evaluator object, or Whatever."
    unless $finder ~~ LLM::Functions::Evaluator || $finder ~~ Callable;

    # Find Fetch known parameters
    my @paramNames = &ML::FindTextualAnswer::LLM::TextualAnswer::Fetch.signature.params.map({ $_.usage-name });
    @paramNames.append(<p pp>);

    #------------------------------------------------------
    # Delegate
    #------------------------------------------------------
    my $res = do given $finder {

        when $_ ~~ LLM::Functions::Evaluator && $n == 1 {

            # Filter parameters
            @paramNames = @paramNames.grep({ $_ ∉ <llm-evaluator> });

            my %args2 = %args.grep({ $_.key ∈ @paramNames });

            ML::FindTextualAnswer::LLM::TextualAnswer::Fetch($text, @questions, llm-evaluator => $finder, |%args2);
        }

        when $_ ~~ LLM::Functions::Evaluator && $n > 1 {
            my $s = @questions.elems == 1 ?? '' !! 's';
            my $request = "{ @questions.elems == 1 ?? 'give' !! 'list' } the top $n answers for each of the question$s:";

            # Filter parameters
            my %args2 = %args.grep({ $_.key ∈ @paramNames }).grep({ $_ ∈ <request llm-evaluator> });

            ML::FindTextualAnswer::LLM::TextualAnswer::Fetch($text,
                                                             @questions,
                                                             :$request,
                                                             llm-evaluator => $finder,
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
#| Finding substrings that appear to be answers of questions using an LLM.
our proto llm-textual-answer(|) is export {*}

multi sub llm-textual-answer(**@args, *%args) {
    ML::FindTextualAnswer::LLM::TextualAnswer::Fetch(|@args, |%args);
}

#===========================================================
#| Creates an LLM function for finding textual answers.
our proto llm-textual-answer-function(|) is export {*}

multi sub llm-textual-answer-function(**@args, *%args) {
    ML::FindTextualAnswer::LLM::TextualAnswer::Function(|@args, |%args);
}


#===========================================================
#| Classifies given text into given given labels using an LLM
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
    my $question = @classLabels.pairs.map({ "{ $_.key + 1 }) { $_.value }" }).join("\n");

    # Process LLM arguments
    my %llmArgs = { llm => 'palm', request => 'which of these labels characterizes it', strip-with => Empty }, %args;
    %llmArgs = %llmArgs.grep({ $_.key ∉ <p pairs> });

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
                @classLabels[$index - 1]
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

