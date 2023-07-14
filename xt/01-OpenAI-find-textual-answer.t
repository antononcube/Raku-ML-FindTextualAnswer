use v6.d;

use lib '.';
use lib './lib';

use ML::FindTextualAnswer;
use Test;

my $llm = 'chatgpt',
my $method = 'tiny';
#my $model = 'gpt-3.5-turbo';
my $model = 'text-curie-001';
my $max-tokens = 120;


plan *;

## 1
ok find-textual-answer("racoon with perls in the style of Hannah Wilke",
        ['What style?', 'What about?'],
        :$llm, :$max-tokens, :$model, :$method);

## 2
my $text2 = 'make a classifier with the method RandomForest over the dataset dfTitanic; show accuracy and recall';
my @questions = ['which method?', 'which dataset?', 'what metrics to display?'];
ok find-textual-answer($text2, @questions, :$llm, :$max-tokens, :$model, :$method);

## 3
ok find-textual-answer($text2, @questions, request => 'answer the questions', :$llm, :$max-tokens, :$model, :$method);

## 4
ok find-textual-answer($text2, 'Which dataset?', model => 'gpt-3.5-turbo-0301', :$llm, :$max-tokens, :$method);

## 5
isa-ok find-textual-answer($text2, @questions,
        model => 'gpt-3.5-turbo-0301',
        :pairs,
        :$llm,
        :$max-tokens,
        :$method).all ~~ Pair,
        True;

done-testing;
