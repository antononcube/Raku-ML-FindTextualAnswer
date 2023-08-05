use v6.d;

use LLM::Functions;
use Text::SubParsers;

unit module ML::FindTextualAnswer::LLM::TextualAnswer;


#===========================================================
# Prompt engineering
#===========================================================

# This prompt was made for OpenAI / ChatGPT.
# With ChatGPT openai-chat-completion has to be used.
# With PaLM palm-generate-text has to be used.

my $prompt = q:to/END/;
You examine texts and can answers questions about them.
Answer the questions appropriate for computer programming processings.
Answer the questions concisely.
DO NOT use the word "and" as a list separator. Separate list elements with commas.
DO NOT number the list or the items of the list.
Your responses should in the form of question and answer pairs.
Put the question-answer pairs in JSON object format.
END

sub default-prompt() is export {
    return $prompt.subst('question-answer pairs', 'list of answers');
}

#===========================================================
# Pre-prepared LLM-functions
#===========================================================

my $confOpenAI = llm-configuration('OpenAI');
my $confPaLM = llm-configuration('PaLM');

my &ftaOpenAI =
        llm-function(
        { "Given the text: $^a \nAnswer the following questions:\n$^b." },
                llm-evaluator => llm-configuration($confOpenAI, prompts => default-prompt),
                form => sub-parser('Str'));

my &ftaPaLM =
        llm-function(
        { "Given the text: $^a \nAnswer the following questions:\n$^b." },
                llm-evaluator => llm-configuration($confPaLM, prompts => default-prompt),
                form => sub-parser('Str'));


#===========================================================
# Make LLM-function for finding textual answers
#===========================================================

#| Make LLM-function for finding textual answers.
our sub Function(:$prelude is copy = Whatever,
                 :$request is copy = Whatever,
                 :form(:$formatron) is copy = Whatever,
                 :e(:$llm-evaluator) is copy = Whatever,
                 Bool :$pairs = False,
                 Bool :$echo = False
                 ) is export {

    #------------------------------------------------------
    # Process prelude
    #------------------------------------------------------

    if $prelude.isa(Whatever) { $prelude = 'Given the text:'; }
    die "The argument \$prelude is expected to be a string or Whatever."
    unless $prelude ~~ Str;

    #------------------------------------------------------
    # Process request
    #------------------------------------------------------

    my &req =
            do given $request {
                when Whatever {
                    -> $x {
                        my @questions = $x ~~ Iterable ?? |$x !! [$x,];
                        my $s = @questions.elems == 1 ?? '' !! 's';
                        "{ @questions.elems == 1 ?? 'give' !! 'list' } the shortest answer$s of the question$s:\n" ~ @questions.join("\n");
                    }
                }

                when Str:D {
                    -> $x { $_ ~ ' ' ~ ($x ~~ Iterable ?? $x !! [$x,]) }
                }

                when Callable {
                    # Do nothing
                }

                default {
                    die "The argument \$request is expected to be a string, a Callable, or Whatever."
                }
            }

    #------------------------------------------------------
    # LLM evaluator
    #------------------------------------------------------

    if $pairs {
        $formatron = sub-parser('JSON');
        $llm-evaluator = llm-evaluator($llm-evaluator);
        $llm-evaluator = llm-evaluator($llm-evaluator,
                        conf => llm-configuration($llm-evaluator.conf, prompts => default-prompt, temperature => 0.01),
                        :$formatron);
    }

    #------------------------------------------------------
    # LLM function
    #------------------------------------------------------

    if $echo {
        return llm-function(
                {
                    my $query = $prelude ~ "\n$^a\n" ~ &req($^b);
                    note "Query:", $query.raku;
                    $query
                },
                :$llm-evaluator,
                :$formatron);
    } else {
        return llm-function(
                { $prelude ~ "\n$^a\n" ~ &req($^b) },
                :$llm-evaluator,
                :$formatron);
    }
}


#===========================================================
# FindTextualAnswer by LLM
#===========================================================

#| LLM utilization for finding textual answers.
our proto Fetch(Str $text,
                $questions,
                :$prelude is copy = Whatever,
                :$request is copy = Whatever,
                :$sep = Whatever,
                :form(:$formatron) = 'Str',
                :e(:$llm-evaluator) is copy = Whatever,
                Bool :p(:$pairs) = False,
                |) is export {*}

multi sub Fetch(Str $text,
                Str $question,
                :$prelude is copy = Whatever,
                :$request is copy = Whatever,
                :$sep = Whatever,
                :form(:$formatron) = 'Str',
                :e(:$llm-evaluator) is copy = Whatever,
                Bool :p(:$pairs) = False,
                *%args) {
    my $res = Fetch($text, [$question,], :$prelude, :$request, :$sep, :$formatron, :$llm-evaluator);
    return $res ~~ Positional ?? $res[0] !! $res;
}

#| LLM utilization for finding textual answers.
multi sub Fetch(Str $text is copy,
                @questions,
                :$prelude is copy = Whatever,
                :$request is copy = Whatever,
                :$sep = Whatever,
                :form(:$formatron) = 'St',
                :e(:$llm-evaluator) is copy = Whatever,
                Bool :p(:$pairs) = False,
                *%args) {

    #------------------------------------------------------
    # Process echo
    #------------------------------------------------------
    my $echo = so %args<echo> // False;

    #------------------------------------------------------
    # Make LLM function
    #------------------------------------------------------

    my &func = Function(:$llm-evaluator, :$formatron, :$echo);

    #------------------------------------------------------
    # Delegate
    #------------------------------------------------------

    my $res = &func($text, @questions);

    #------------------------------------------------------
    # Process answers
    #------------------------------------------------------

    return $res;
}