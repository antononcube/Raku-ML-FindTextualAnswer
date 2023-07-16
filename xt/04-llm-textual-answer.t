use v6.d;

use lib '.';
use lib './lib';

use ML::FindTextualAnswer;
use Test;

my $llm = 'palm',
my $method = 'tiny';
my $model = 'text-bison-001';
my $max-tokens = 120;
my $echo = False;


plan *;

## 1
ok llm-textual-answer("racoon with perls in the style of Hannah Wilke",
        ['What style?', 'What about?'],
        :$llm, :$max-tokens, :$model, :$method);

## 2
my $text2 = 'make a classifier with the method RandomForest over the dataset dfTitanic; show accuracy and recall';
my @questions = ['which method?', 'which dataset?', 'what metrics to display?'];
ok llm-textual-answer($text2, @questions, :$llm, :$max-tokens, :$model, :$method, :$echo);

## 3
ok llm-textual-answer($text2, @questions, request => 'answer the questions', :$llm, :$max-tokens, :$model, :$method, :$echo);

## 4
ok llm-textual-answer($text2, 'Which dataset?', model => 'chat-bison-001', :$llm, :$max-tokens, :$method, :$echo);

## 5
isa-ok llm-textual-answer($text2, @questions,
        model => 'chat-bison-001',
        :pairs,
        :$llm,
        :$max-tokens,
        :$method,
        :$echo).all ~~ Pair,
        True;

done-testing;