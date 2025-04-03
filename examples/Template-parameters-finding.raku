#!/usr/bin/env raku
use v6.d;

use ML::FindTextualAnswer;
use LLM::Functions;

my $query = 'Make a classifier with the method RandomForest over the data dfTitanic; show precision and accuracy; plot True Positive Rate vs Positive Predictive Value.';
my $query2 = 'make a classifier with the method RandomForest over the dataset dfTitanic; show accuracy and recall';

my @questions =
        ['What is the dataset?',
         'What is the method?',
         "Which metrics to show?",
         'Are ROC functions specified?',
         'If yes, which ROC functions to plot?'
        ];

my @questions2 =
        ['Which dataset?',
         'Which method?',
         "Which metrics to show?"
        ];


my @answers = |find-textual-answer($query, @questions, request => Whatever, prompt => Whatever, finder => llm-evaluator('PaLM'));

.say for @answers;

#========================================================================================================================

say '=' x 120;

my %answers2 = find-textual-answer($query2, @questions2, request => Whatever, prompt => Whatever,  finder => llm-evaluator('OpenAI')):pairs;

.say for %answers2;


#`[
my $text = "Create a random mandala collage with 34 mandalas and the coloring style Dark Rainbow";

say openai-find-textual-answer($text, "How many mandalas?").raku;
]

#my @noWords = <what is the ? . method dataset show metrics plot to are>;
#my @answers3 = |openai-find-textual-answer($query, @questions, strip-with => @noWords, model => 'gpt-3.5-turbo', max-tokens => 120);
#.say for @answers3;


#`[
say '=' x 120;

my @answers4 = |openai-find-textual-answer($query, @questions, model=> 'text-davinci-003', max-tokens => 120);

.say for @answers4;
]