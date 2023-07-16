use v6.d;

use ML::FindTextualAnswer::LLM::TextualAnswer;

unit module ML::FindTextualAnswer;



#===========================================================
#| Finding substrings that appear to be answers of questions.
our proto find-textual-answer(|) is export {*}

multi sub find-textual-answer(**@args, *%args) {

    # Is method given
    my $method = do if %args<method>:exists {
        %args<method>
    } else {
        'llm'
    }

    # Delegate
    return do given $method {
        when $_ ∈ <llm chatgpt openai palm large-language-model large-language-models> {
            ML::FindTextualAnswer::LLM::TextualAnswer::Fetch(|@args, |%args);
        }
        default {
            die "The method $method is not implemented.";
        }
    }
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

