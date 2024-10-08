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

my $promptQAJSON = q:to/END/;
You examine texts and answer questions about them.
The answers you give are amenable for further computer programming processing.
Answer the questions concisely.
DO NOT use the word "and" as a list separator. Separate list elements only with commas.
DO NOT number the list or the items of the list.
When possible give numerical results.
If a question is not applicable give "N/A" as its answer.
Your responses should be in the form of question-answer pairs.
Put the question-answer pairs in a JSON object format.
In the result JSON object the questions are the keys, the answers are the values.
END

sub default-prompt() is export {
    #return $promptQAJSON.subst('question-answer pairs', 'list of answers');
    return $promptQAJSON;
}


#===========================================================
# Pre-prepared LLM-functions
#===========================================================

my $confOpenAI = llm-configuration('ChatGPT', model => 'gpt-3.5-turbo');
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
                 :$sep is copy = Whatever,
                 :$sep-text-begin is copy = Whatever,
                 :$sep-text-end is copy = Whatever,
                 :form(:$formatron) is copy = Whatever,
                 :e(:$llm-evaluator) is copy = Whatever,
                 Bool :$pairs = False,
                 Bool :$echo = False
                 ) is export {

    #------------------------------------------------------
    # Process separator
    #------------------------------------------------------

    # What is the role/purpose of the separator?
    if $sep.isa(Whatever) { $sep = ''; }
    die "The argument \$sep is expected to be a string or Whatever."
    unless $sep ~~ Str:D;

    if $sep-text-begin.isa(Whatever) { $sep-text-begin = "\n```text\n"; }
    die "The argument \$text-sep-begin is expected to be a string or Whatever."
    unless $sep-text-begin ~~ Str:D;

    if $sep-text-end.isa(Whatever) { $sep-text-end = "\n```\n"; }
    die "The argument \$sep is expected to be a string or Whatever."
    unless $sep-text-end ~~ Str:D;

    #------------------------------------------------------
    # Process prelude
    #------------------------------------------------------

    if $prelude.isa(Whatever) { $prelude = 'Given the text:'; }
    die "The argument \$prelude is expected to be a string or Whatever."
    unless $prelude ~~ Str;

    #------------------------------------------------------
    # Process formatron
    #------------------------------------------------------

    if $formatron.isa(Whatever) && $llm-evaluator ~~ LLM::Functions::Evaluator {
        $formatron = $llm-evaluator.formatron;
    }

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
        my $conf = $llm-evaluator;

        if $llm-evaluator ~~ LLM::Functions::Evaluator {
            $conf = $llm-evaluator.conf
        }

        $formatron = sub-parser('JSON', :drop);
        $llm-evaluator = llm-evaluator($llm-evaluator,
                conf => llm-configuration($conf, prompts => default-prompt(), temperature => 0.01),
                :$formatron);
    }

    note "Evaluator object : { $llm-evaluator.raku }" if $echo;

    #------------------------------------------------------
    # LLM function
    #------------------------------------------------------

    if $echo {
        return llm-function(
                {
                    my $query = $prelude ~ $sep-text-begin ~ $^a ~ $sep-text-end ~ &req($^b);
                    note "Query : ", $query.raku;
                    $query
                },
                :$llm-evaluator,
                :$formatron);
    } else {
        return llm-function(
                { $prelude ~ $sep-text-begin ~ $^a ~ $sep-text-end ~ &req($^b) },
                :$llm-evaluator,
                :$formatron);
    }
}


#===========================================================
# Post processing heuristics
#===========================================================
sub string-distance(Str $w1, Str $w2) {
    +StrDistance.new(before => $w1, after => $w2)
}

our proto sub PostProcess(|) is export {*}

multi sub PostProcess(@questions, @resultPairs) {

    my @pairsToPass = @resultPairs.grep({ $_ ~~ Pair });

    die "The second argument is expected to be a non-empty list with pairs or a Map object."
    unless @pairsToPass.all ~~ Pair:D && @pairsToPass.elems;

    return PostProcess(@questions, @pairsToPass.Hash);
}

multi sub PostProcess(@questions, %result) {

    die "The first argument is expected to be a list of strings."
    unless @questions.all ~~ Str:D;

    die "The Map object given as a second argument is empty."
    unless %result.elems > 0;

    # Find word candidates and distances for each question
    my @dists = @questions.map(-> $q { $q => %result.keys.map(-> $k { $k => string-distance($q, $k) }).sort(*.value) });

    # Pick the smallest distance candidate
    my %qToResKey = @dists.map({ $_.key => $_.value.head.key });

    # Return the original question to corresponding answer map.
    return %qToResKey.map({ $_.key => %result{$_.value} }).Hash;
}

multi sub PostProcess(@questions, $result) {
    if @questions.elems == 1 && $result ~~ Str:D {
        return PostProcess(@questions, %(@questions.head => $result));
    }
    warn "Do not know how to process the second argument: { $result.raku }";
    return $result;
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
                :form(:$formatron) = Whatever,
                :e(:$llm-evaluator) is copy = Whatever,
                Bool :p(:$pairs) = False,
                Bool :pp(:$post-process) = True,
                Bool :$echo = False) is export {*}

multi sub Fetch(Str $text,
                Str $question,
                :$prelude is copy = Whatever,
                :$request is copy = Whatever,
                :$sep = Whatever,
                :form(:$formatron) = Whatever,
                :e(:$llm-evaluator) is copy = Whatever,
                Bool :p(:$pairs) = False,
                Bool :pp(:$post-process) = True,
                Bool :$echo = False) {
    my $res = Fetch($text, [$question,], :$prelude, :$request, :$sep, :$formatron, :$llm-evaluator, :$pairs, :$post-process, :$echo);
    return $res ~~ Positional ?? $res[0] !! $res;
}

#| LLM utilization for finding textual answers.
multi sub Fetch(Str $text is copy,
                @questions,
                :$prelude is copy = Whatever,
                :$request is copy = Whatever,
                :$sep = Whatever,
                :form(:$formatron) = Whatever,
                :e(:$llm-evaluator) is copy = Whatever,
                Bool :p(:$pairs) = False,
                Bool :pp(:$post-process) = True,
                Bool :$echo = False) {

    #------------------------------------------------------
    # Make LLM function
    #------------------------------------------------------

    my &func = Function(:$prelude, :$request, :$sep, :$formatron, :$llm-evaluator, :$pairs, :$echo);

    #------------------------------------------------------
    # LLM function evaluation
    #------------------------------------------------------

    my $res = &func($text, @questions);

    note "LLM response : {$res.raku}" if $echo;

    #------------------------------------------------------
    # Process answers
    #------------------------------------------------------

    if $pairs && $post-process {
        $res = PostProcess(@questions, $res);
    }

    return $res;
}