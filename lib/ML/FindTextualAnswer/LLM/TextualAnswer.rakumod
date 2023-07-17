use v6.d;

use WWW::OpenAI;
use WWW::OpenAI::Models;
use WWW::OpenAI::TextCompletions;
use WWW::OpenAI::ChatCompletions;

use WWW::PaLM;
use WWW::PaLM::Models;
use WWW::PaLM::GenerateText;
use WWW::PaLM::GenerateMessage;

unit module ML::FindTextualAnswer::LLM::TextualAnswer;

#===========================================================
# Registered LLMs data structures
#===========================================================

our %llmModules =
        openai => 'WWW::OpenAI',
        palm => 'WWW::PaLM';

our %llmDefaultModels =
        openai => 'text-curie-001',
        palm => 'text-bison-001';

our %llmModelToEndPointFunc =
        openai => &openai-model-to-end-points,
        palm => &palm-model-to-end-points;

our %llmQueryFunc =
        openai => -> $model { openai-is-chat-completion-model($model) ?? &OpenAIChatCompletion !! &OpenAITextCompletion; },
        palm => -> $model { palm-is-chat-completion-model($model) ?? &PaLMGenerateMessage !! &PaLMGenerateText; };

# ChatGPT is a synonym of OpenAI
%llmModules<chatgpt> = %llmModules<openai>;
%llmDefaultModels<chatgpt> = %llmDefaultModels<openai>;
%llmModelToEndPointFunc<chatgpt> = %llmModelToEndPointFunc<openai>;
%llmQueryFunc<chatgpt> = %llmQueryFunc<openai>;

#===========================================================
# Register LLM
#===========================================================

our sub register-llm(Str :$llm!,
                     Str :$module!,
                     Str :$default-model!,
                     :&model-to-end-point-func!,
                     :&query-func!) is export {
    %llmModules{$llm} = $module;
    %llmDefaultModels{$llm} = $default-model;
    %llmModelToEndPointFunc{$llm} = &model-to-end-point-func;
    %llmQueryFunc{$llm} = &query-func
}

#===========================================================
# FindTextualAnswer by LLM
#===========================================================

#| LLM utilization for finding textual answers.
our proto Fetch(Str $text,
                $questions,
                :$llm is copy = Whatever,
                :$sep = Whatever,
                :model(:$llm-model) = Whatever,
                :$strip-with = Empty,
                :$prelude is copy = Whatever,
                :$request is copy = Whatever,
                Bool :p(:$pairs) = False,
                |) is export {*}

multi sub Fetch(Str $text,
                Str $question,
                :$llm is copy = Whatever,
                :$sep = Whatever,
                :model(:$llm-model) = Whatever,
                :$strip-with = Empty,
                :$prelude is copy = Whatever,
                :$request is copy = Whatever,
                Bool :p(:$pairs) = False,
                *%args) {
    my $res = Fetch($text, [$question,], :$llm, :$sep, :$llm-model, :$strip-with, :$prelude, :$request, :$pairs, |%args);
    return $res ~~ Positional ?? $res[0] !! $res;
}

#| LLM utilization for finding textual answers.
multi sub Fetch(Str $text is copy,
                @questions,
                :$llm is copy = Whatever,
                :$sep is copy = Whatever,
                :model(:$llm-model) is copy = Whatever,
                :$strip-with is copy = Whatever,
                :$prelude is copy = Whatever,
                :$request is copy = Whatever,
                Bool :p(:$pairs) = False,
                *%args) {

    #------------------------------------------------------
    # Process llm
    #------------------------------------------------------
    if $llm.isa(Whatever) { $llm = 'openai'; }
    die "The argument \$model is expected to be Whatever or one of { %llmModules.keys.join(', ') }."
    unless $llm ∈ %llmModules.keys;

    #------------------------------------------------------
    # Process separator
    #------------------------------------------------------

    if $sep.isa(Whatever) { $sep = ')'; }
    die "The argument \$sep is expected to be a string or Whatever" unless $sep ~~ Str;

    #------------------------------------------------------
    # Process llm-model
    #------------------------------------------------------

    if $llm-model.isa(Whatever) { $llm-model = %llmDefaultModels{$llm}; }
    die "The argument \$llm-model is expected to be Whatever or one of { %llmModelToEndPointFunc{$llm}().keys.join(', ') }."
    unless $llm-model ∈ %llmModelToEndPointFunc{$llm}().keys;

    #------------------------------------------------------
    # Process prolog
    #------------------------------------------------------

    if $prelude.isa(Whatever) { $prelude = 'Given the text:'; }
    die "The argument \$prelude is expected to be a string or Whatever."
    unless $prelude ~~ Str;

    #------------------------------------------------------
    # Process request
    #------------------------------------------------------

    if $request.isa(Whatever) {
        my $s = @questions.elems == 1 ?? '' !! 's';
        $request = "{ @questions.elems == 1 ?? 'give' !! 'list' } the shortest answer$s of the question$s:";
    }
    die "The argument \$request is expected to be a string or Whatever."
    unless $request ~~ Str;

    #------------------------------------------------------
    # Process echo
    #------------------------------------------------------
    my $echo = so %args<echo> // False;

    #------------------------------------------------------
    # Make query
    #------------------------------------------------------

    my Str $query = $prelude ~ ' "' ~ $text ~ '" ' ~ $request;

    if @questions == 1 {
        $query ~= "\n{ @questions[0] }";
    } else {
        for (1 .. @questions.elems) -> $i {
            $query ~= "\n$i$sep { @questions[$i - 1] }";
        }
    }

    if $echo { note "Query:", $query.raku; }

    #------------------------------------------------------
    # Delegate
    #------------------------------------------------------

    my &func = %llmQueryFunc{$llm}($llm-model);

    my @knownParamNames = &func.candidates.map({ $_.signature.params.map({ $_.usage-name }) }).flat;
    my $res = &func($query, model => $llm-model, format => 'values', |%args.grep({ $_.key ∉ <format echo> && $_.key ∈ @knownParamNames }).Hash);

    if $echo {
        my @unknownParamNames = %args.keys.grep({ $_ ∉ <format echo> && $_ ∉ @knownParamNames });
        note "Unknown parameter names for the function { &func.name } : ", @unknownParamNames.raku
        if @unknownParamNames;
    }

    if $echo { note "Result:", $res.raku; }

    #------------------------------------------------------
    # Process answers
    #------------------------------------------------------

    # Pick answers the are long enough.
    my @answers = [$res,];
    if @questions.elems > 1 {
        @answers = $res.lines.grep({ $_.chars > @questions.elems.Str.chars + $sep.chars + 1 });

        if @answers.elems != @questions.elems {
            @answers = $res.split(/ \v\v /, :skip-empty)
        }
    }

    if $echo { note "Answers:", @answers.raku; }

    if @answers.elems == @questions.elems {
        if $strip-with.isa(Whatever) || $strip-with.isa(WhateverCode) {

            # Strip enumeration
            if @questions.elems > 1 {
                @answers = @answers.map({ $_.subst(/ ^ \h* \d+ \h* $sep /, '').trim });
            }

            # For each answer remove "parasitic" words.
            for (^@questions.elems) -> $i {
                # @answers[$i] = @answers[$i].split(/ <ws> /, :skip-empty).grep({ $_.lc ∉ $noWords }).join;
                my @noWords = @questions[$i].split(/ <ws> /, :skip-empty)>>.lc.unique.Array;
                @answers[$i] = reduce(-> $x, $w { $x.subst(/:i <wb> $w <wb>/, ''):g }, @answers[$i], |@noWords);
                @answers[$i] =
                        @answers[$i]
                                .subst(/ ^ The /, '')
                                .subst(/ ^ \h+ [are | is] \h+ /, '')
                                .subst(/ '.' $ /, '')
                        .trim;
            }

        } elsif $strip-with ~~ Positional && $strip-with.elems > 0 {

            # Strip enumeration
            if @questions.elems > 1 {
                @answers = @answers.map({ $_.subst(/ ^ \h* \d+ \h* $sep /, '').trim });
            }

            # Derive list of words to be removed
            my @noWords = $strip-with.grep(*~~ Str).Array;

            # Remove words
            for (^@questions.elems) -> $i {
                @answers[$i] = reduce(-> $x, $w { $x.subst(/:i <wb> $w <wb>/, ''):g }, @answers[$i], |@noWords);
            }

        } elsif $strip-with ~~ Callable {
            for (^@questions.elems) -> $i {
                @answers[$i] = $strip-with(@answers[$i]);
            }
        }

        if $pairs {
            return (@questions Z=> @answers).Array;
        }
        return @answers;
    }

    note 'The obtained answer does not have the expected form: a line with an answer for each question.';
    return $res;
}