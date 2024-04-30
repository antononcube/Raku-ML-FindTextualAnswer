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
        when $finder ~~ Str:D && $finder.lc ∈ <llm large-language-model largelanguagemodel> {
            llm-evaluator(Whatever)
        }
        when $finder ~~ Str:D && $finder.lc ∈ <openai chatgpt palm chatpalm gemini chatgemini mistralai llama> {
            llm-evaluator($finder)
        }
        when Whatever { llm-evaluator(Whatever) }
        default { $finder }
    }

    die "The value of \$finder is expected to be Whatever, an LLM::Functions::Evaluator object, or one of 'LLM', 'PaLM', 'ChatPaLM', 'Gemini', 'ChatGemini', 'OpenAI', 'ChatGPT', 'MistralAI', or 'LLaMA'."
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
#| Classifies given text into given given labels using an LLM.
our proto llm-classify($text, @classLabels, :$llm-evaluator = Whatever, *%args) is export {*}

multi sub llm-classify(@texts,
                       @classLabels is copy,
                       :$llm-evaluator is copy = Whatever,
                       *%args
                       ) {
    return @texts.map({ llm-classify($_, @classLabels, :$llm-evaluator, |%args)});
}

multi sub llm-classify(Str $text,
                       @classLabels is copy,
                       :e($llm-evaluator) is copy = Whatever,
                       *%args
                       ) {

    # Make string
    @classLabels = @classLabels>>.Str;

    # Single question
    my $question = @classLabels.pairs.map({ "{ $_.key + 1 }) { $_.value }" }).join("\n");

    # Echo arg
    my $echo = %args<echo> // False;

    # Delegate
    my $res = llm-textual-answer($text, $question, :$llm-evaluator, request => 'which of these labels characterizes it:'):!pairs;

    # Echo delegation result
    note "llm-textual-answer result: ", $res.raku if $echo;

    # We do not handle multiple classification labels yet.
    # Mostly, because LLMs currently do not return probabilities of the answers in a meaningful way.
    if $res ~~ Iterable && $res.elems > 0 { $res = $res.head }

    # Process result
    my $resLbl = do given $res {
        when $_ ~~ Str:D && $_.trim ~~ / ^ (\d+) / {
            my $index = $0.Str.Int;

            note "Index : $index" if $echo;

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

